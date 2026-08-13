/**
 * Coach team portal: the journal-summary trigger and the weekly team report.
 *
 * THIS FILE IS THE PRIVACY BOUNDARY OF THE COACH PORTAL. It is the only place
 * in the codebase where raw journal text and coach-visible data meet.
 *
 * The rules that hold the boundary, all of them enforced below:
 *  1. Raw entry text is read into memory, sent to Anthropic, and discarded. It
 *     is never written to Firestore, never returned from a callable, and never
 *     logged, not even truncated, not even on error.
 *  2. `team_entry_summaries/{entryId}` carries exactly the coach-readable
 *     contract in coach_types.ts. There is no `content`, `snippet`, `excerpt`,
 *     `reason`, or `concernLevel` field. Concern signals live in the separate
 *     analyst-only `team_entry_signals` collection.
 *  3. The summary system prompt is the actual privacy control. The model is
 *     told what it may say, what it may never say, and that a coach reads the
 *     output. Code-side scrubbing (verbatim-overlap detection, quote stripping,
 *     length and shape caps) is defense in depth behind the prompt.
 *  4. The weekly report is aggregate. Player names appear only in `watchList`,
 *     and those notes are built from counts in code, never authored by the AI.
 *
 * NOT A CLINICAL TOOL. `concernLevel` and the watch list exist so a coach
 * knows a human conversation might be worth having. They are not a screening,
 * triage, or risk assessment, they are not a substitute for a school's or
 * club's duty-of-care process, and nothing here should be treated as a mental
 * health judgement about a player.
 */

import * as admin from 'firebase-admin';
import Anthropic from '@anthropic-ai/sdk';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import {
  JOURNALS_COLLECTION,
  ROLES_CONFIG_DOC_PATH,
  TEAMS_COLLECTION,
  TEAM_ENTRY_SIGNALS_COLLECTION,
  TEAM_ENTRY_SUMMARIES_COLLECTION,
  TEAM_REPORTS_SUBCOLLECTION,
  TEAM_ROSTER_SUBCOLLECTION,
  USERS_COLLECTION,
  type ConcernLevel,
  type GenerateTeamReportRequest,
  type GenerateTeamReportResponse,
  type Sentiment,
  type TeamDoc,
  type TeamEntrySignalDoc,
  type TeamEntrySummaryDoc,
  type TeamReportDoc,
  type TeamReportWatchItem,
  type TeamRosterDoc,
} from './coach_types';
import { SCHEDULED_MAX_INSTANCES } from './runtime';

const anthropicKey = defineSecret('ANTHROPIC_API_KEY');

const db = admin.firestore();

/** Matches the model used by every other AI path in this repo. */
const TEAM_INSIGHTS_MODEL = 'claude-sonnet-4-5';

/**
 * Whether `concernLevel` is allowed to reach anything a coach reads.
 *
 * OFF for the pilot, by product decision. The signal is still computed and
 * stored in the analyst-only `team_entry_signals` collection so the data
 * exists to evaluate later, but a coach is shown participation only.
 * Surfacing "this player may need a check-in" to a coach creates a
 * duty-of-care obligation that needs a written escalation policy and
 * player-facing consent copy first, and neither exists yet.
 *
 * Turning this on is not just a UI change: revisit the coach dashboard, the
 * weekly report prompt, and what players were told before flipping it.
 */
const SURFACE_CONCERN_SIGNALS = false;

// ─── Logging ────────────────────────────────────────────────────────────────

/**
 * Strips any Anthropic API key pattern from a string before it reaches logs.
 * File-local copy of the index.ts helper, same as blog.ts and coach.ts, since
 * index.ts's version is private.
 */
function sanitizeForLog(value: unknown): unknown {
  if (typeof value === 'string') {
    return value.replace(/sk-ant-[A-Za-z0-9_\-]+/g, '[REDACTED]');
  }
  if (value instanceof Error) {
    return sanitizeForLog(value.message);
  }
  return value;
}

/**
 * Error description for logging that deliberately DROPS the message.
 *
 * Everything in this file runs with journal text in scope, and an SDK or
 * Firestore error message is the easiest way for that text to end up in Cloud
 * Logging (a validation error that echoes part of a request body, a stack frame
 * carrying an argument). We log the error class and HTTP status, which is what
 * actually matters for triage, and nothing else.
 */
function describeError(err: unknown): string {
  const name = err instanceof Error ? err.constructor.name || err.name : typeof err;
  const status = (err as { status?: unknown })?.status;
  const label = typeof status === 'number' ? `${name} status=${status}` : name;
  return String(sanitizeForLog(label));
}

// ─── Dates ──────────────────────────────────────────────────────────────────

/**
 * Midnight to 4 AM counts as the previous day, matching
 * `AppDateUtils.todayStringWithGracePeriod()` in the app. Every streak,
 * `journalCompleted` flag, and coach-assigned prompt already uses that day
 * boundary, so a summary's `date` has to use it too or the portal's calendar
 * will disagree with the app by one row.
 */
const DAY_GRACE_PERIOD_MS = 4 * 60 * 60 * 1000;

const MS_PER_DAY = 86400000;

function utcDateKey(d: Date): string {
  const m = (d.getUTCMonth() + 1).toString().padStart(2, '0');
  const day = d.getUTCDate().toString().padStart(2, '0');
  return `${d.getUTCFullYear()}-${m}-${day}`;
}

function localDateKeyInTz(d: Date, tz?: string): string {
  if (tz) {
    try {
      // en-CA formats as yyyy-MM-dd.
      return new Intl.DateTimeFormat('en-CA', {
        timeZone: tz,
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
      }).format(d);
    } catch {
      // Unknown tz string, fall through to UTC.
    }
  }
  return utcDateKey(d);
}

function entryDateKey(createdAt: string | undefined, tz: string | undefined): string {
  const parsed = createdAt ? Date.parse(createdAt) : NaN;
  const ms = Number.isNaN(parsed) ? Date.now() : parsed;
  return localDateKeyInTz(new Date(ms - DAY_GRACE_PERIOD_MS), tz);
}

/** ISO-8601 week of a date, Monday-based, Thursday rule. */
function isoWeekPeriod(d: Date): string {
  const date = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
  const weekday = date.getUTCDay() || 7; // Mon=1 … Sun=7
  date.setUTCDate(date.getUTCDate() + 4 - weekday);
  const isoYear = date.getUTCFullYear();
  const yearStart = Date.UTC(isoYear, 0, 1);
  const week = Math.ceil(((date.getTime() - yearStart) / MS_PER_DAY + 1) / 7);
  return `${isoYear}-W${week.toString().padStart(2, '0')}`;
}

const PERIOD_PATTERN = /^(\d{4})-W(\d{2})$/;

/** Monday…Sunday date keys for a '2026-W33' period, or null if malformed. */
function isoWeekRange(period: string): { start: string; end: string } | null {
  const match = PERIOD_PATTERN.exec(period);
  if (!match) return null;
  const year = parseInt(match[1], 10);
  const week = parseInt(match[2], 10);
  if (week < 1 || week > 53) return null;

  // Jan 4 is always in ISO week 1, so its Monday anchors the year.
  const jan4 = Date.UTC(year, 0, 4);
  const jan4Weekday = new Date(jan4).getUTCDay() || 7;
  const week1Monday = jan4 - (jan4Weekday - 1) * MS_PER_DAY;
  const monday = new Date(week1Monday + (week - 1) * 7 * MS_PER_DAY);
  const sunday = new Date(monday.getTime() + 6 * MS_PER_DAY);
  return { start: utcDateKey(monday), end: utcDateKey(sunday) };
}

function previousPeriod(period: string): string | null {
  const range = isoWeekRange(period);
  if (!range) return null;
  const mondayMs = Date.parse(`${range.start}T00:00:00Z`);
  if (Number.isNaN(mondayMs)) return null;
  return isoWeekPeriod(new Date(mondayMs - 7 * MS_PER_DAY));
}

// ─── Access guard ───────────────────────────────────────────────────────────

/**
 * Coach/analyst guard for `generateTeamReport`. Intentionally a local twin of
 * `assertTeamAccess` in coach.ts (which is not exported) rather than a change
 * to that file, so the two phases never touch the same lines. Same semantics:
 * the team's coach, or an allowlisted analyst, and nobody else.
 */
async function assertTeamAccess(uid: string | undefined, teamId: string): Promise<void> {
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Must be signed in.');
  }
  const teamSnap = await db.collection(TEAMS_COLLECTION).doc(teamId).get();
  if (!teamSnap.exists) {
    throw new HttpsError('not-found', 'Team not found.');
  }
  const team = teamSnap.data() as TeamDoc;
  if (team.coachUid === uid) return;

  const rolesSnap = await db.doc(ROLES_CONFIG_DOC_PATH).get();
  const analystUids = (rolesSnap.data()?.analystUids ?? []) as string[];
  if (analystUids.includes(uid)) return;

  throw new HttpsError('permission-denied', 'Not authorized for this team.');
}

// ─── Anthropic helper ───────────────────────────────────────────────────────

/**
 * Calls Anthropic directly, the same way the scheduled jobs in index.ts and
 * blog.ts do, instead of going through the rate-limited `callClaude` callable.
 * Summarizing for the coach is the product's work, not the player's, so it must
 * not consume the player's daily AI quota.
 */
async function callInsightsAnthropic(
  systemPrompt: string,
  userPrompt: string,
  maxTokens: number,
  apiKey: string,
): Promise<string> {
  const client = new Anthropic({ apiKey });
  const message = await client.messages.create({
    model: TEAM_INSIGHTS_MODEL,
    max_tokens: maxTokens,
    system: systemPrompt,
    messages: [{ role: 'user', content: userPrompt }],
  });
  const block = message.content[0];
  if (block.type !== 'text') {
    throw new Error('Unexpected response type from Claude');
  }
  return block.text.replace(/\s*—\s*/g, ', ').replace(/\s*--\s*/g, ', ');
}

function extractJsonPayload(text: string): string {
  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start === -1 || end === -1 || end <= start) return text.trim();
  return text.slice(start, end + 1);
}

// ─── Shared scrubbing ───────────────────────────────────────────────────────

const MAX_SUMMARY_LENGTH = 400;

/**
 * Removes quote characters and collapses whitespace. A paraphrase never needs
 * quotation marks, so their presence is a signal the model was reproducing
 * something. Stripping them also stops a quoted fragment from *looking*
 * authoritative to a coach even if one slips past the verbatim check.
 */
function scrubText(value: string, maxLength: number): string {
  return value
    // Double quotes only. Apostrophes stay, or every possessive and
    // contraction in a legitimate summary gets mangled.
    .replace(/["“”„‟«»]/g, '')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, maxLength);
}

const VALID_SENTIMENTS: Sentiment[] = ['positive', 'neutral', 'negative'];
const VALID_CONCERN_LEVELS: ConcernLevel[] = ['none', 'watch', 'flag'];

function coerceSentiment(value: unknown): Sentiment {
  return VALID_SENTIMENTS.includes(value as Sentiment) ? (value as Sentiment) : 'neutral';
}

function coerceConcernLevel(value: unknown): ConcernLevel {
  return VALID_CONCERN_LEVELS.includes(value as ConcernLevel)
    ? (value as ConcernLevel)
    : 'none';
}

// ─── Part A: onJournalEntryCreated ──────────────────────────────────────────

type JournalEntryDoc = {
  uid?: string;
  mode?: string;
  mood?: string;
  prompt?: string;
  content?: string;
  teamPromptId?: string | null;
  createdAt?: string;
};

/** Mirrors the private `moodScore` in index.ts so charts share one scale. */
function moodScoreFor(mood: string | undefined): number {
  switch (mood) {
    case 'amazing': return 10;
    case 'good': return 8;
    case 'okay': return 6;
    case 'struggling': return 3;
    case 'low': return 1;
    default: return 5;
  }
}

/**
 * THE PRIVACY CONTROL.
 *
 * Everything downstream of this prompt is defense in depth. If this prompt is
 * ever loosened, the coach portal stops honoring what players were told. Read
 * the whole thing before changing a word of it.
 */
const ENTRY_SUMMARY_SYSTEM = `You write privacy-safe summaries of an athlete's private journal entry so their coach can support them.

WHO READS THIS
- The athlete wrote this entry in a private, mental-health-adjacent journal, for themselves. They did not write it for their coach.
- The athlete has been told that only themes, mood, and a short summary are shared with their coach. They have NOT agreed to their coach reading what they actually wrote.
- Your summary is the only thing the coach sees. Treat every word of the entry as confidential source material that must not survive into your output.

HARD RULES (breaking one is a privacy breach, not a style problem)
- Write 1 to 2 sentences, third person, about themes and mental state only.
- NEVER quote the entry. Never closely paraphrase it. Never reuse its distinctive wording, phrasing, or imagery. Do not use quotation marks at all.
- Never name or refer to another person, in any form: no names, no initials, no "his girlfriend", no "her stepdad", no teammates, no coaches, no family members.
- Never repeat a specific private detail of any kind. That includes relationships and breakups, family or home situations, medical or mental-health history, therapy, medication, sex, sexuality, gender identity, legal trouble, money, grades, and substance use.
- Never retell events. Stay at the level of mindset. Write "is showing frustration about playing time and is refocusing on preparation", not a retelling of what happened.
- Never use diagnostic or clinical language, and never assess anyone. Words like depressed, anxiety disorder, trauma, symptoms, at risk, and suicidal are banned. You are not a clinician and this is not an assessment.
- Never invent anything the entry does not support.
- If the entry is mostly private content that cannot be summarized under these rules, set summary to exactly: Wrote a personal entry. No team-relevant themes to share.

FIELDS
- summary: 1 to 2 sentences as described above. Plain, calm, non-judgmental. No quotation marks.
- themes: 1 to 4 generic labels, 1 to 3 words each, lowercase. Categories only, never specifics and never names. Examples: playing time, confidence, preparation, team dynamics, pressure, recovery, motivation, focus, gratitude, sleep, workload.
- sentiment: positive, neutral, or negative. The overall emotional tone of the entry.
- concernLevel: none, watch, or flag. This is coach awareness only, NOT a clinical or risk assessment. Use none for a normal entry. Use watch for sustained frustration, sinking confidence, or pulling away from the team that a coach should keep an eye on. Use flag only when the entry suggests this athlete would benefit from a human check-in soon. Never explain the reason: the reason stays private, and the coach's action is simply to check in.

Return ONLY valid JSON, no prose before or after:
{ "summary": string, "themes": string[], "sentiment": "positive" | "neutral" | "negative", "concernLevel": "none" | "watch" | "flag" }`;

/**
 * Upper bound on the entry text sent to Anthropic. Long entries are truncated
 * rather than skipped: the tail of an entry rarely changes its themes, and a
 * silently missing summary row is worse for the coach's timeline.
 */
const MAX_ENTRY_CHARS_TO_MODEL = 6000;

const MAX_THEMES = 4;
const MAX_THEME_WORDS = 4;
const MAX_THEME_LENGTH = 40;

/** Coach-facing placeholder used whenever we will not trust the AI output. */
const SUMMARY_UNAVAILABLE =
  'Summary unavailable for this entry. Mood and participation are still recorded.';

function buildEntrySummaryUserMessage(entry: JournalEntryDoc): string {
  const content = (entry.content ?? '').slice(0, MAX_ENTRY_CHARS_TO_MODEL);
  const lines = [
    `Journal mode: ${entry.mode ?? 'reflect'}`,
    `Mood the athlete selected: ${entry.mood ?? 'unspecified'}`,
  ];
  if (entry.prompt) {
    lines.push(`Prompt they were answering: ${entry.prompt}`);
  }
  lines.push(
    'Confidential entry follows. Summarize it under the rules. Do not reproduce any part of it.',
    '"""',
    content,
    '"""',
  );
  return lines.join('\n');
}

const VERBATIM_RUN_WORDS = 8;

function normalizedWords(text: string): string[] {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .split(/\s+/)
    .filter(Boolean);
}

/**
 * Detects an 8-word run shared between the summary and the entry.
 *
 * A genuine paraphrase almost never repeats eight consecutive words, so this is
 * a cheap, high-signal tripwire for the one failure mode the prompt cannot
 * fully prevent: the model quoting or near-copying the entry. On a hit we throw
 * the summary away rather than shipping it to the coach.
 */
function sharesVerbatimRun(summary: string, entryText: string): boolean {
  const summaryWords = normalizedWords(summary);
  const entryWords = normalizedWords(entryText);
  if (summaryWords.length < VERBATIM_RUN_WORDS || entryWords.length < VERBATIM_RUN_WORDS) {
    return false;
  }
  const runs = new Set<string>();
  for (let i = 0; i + VERBATIM_RUN_WORDS <= entryWords.length; i++) {
    runs.add(entryWords.slice(i, i + VERBATIM_RUN_WORDS).join(' '));
  }
  for (let i = 0; i + VERBATIM_RUN_WORDS <= summaryWords.length; i++) {
    if (runs.has(summaryWords.slice(i, i + VERBATIM_RUN_WORDS).join(' '))) return true;
  }
  return false;
}

type ParsedEntrySummary = {
  summary: string;
  themes: string[];
  sentiment: Sentiment;
  concernLevel: ConcernLevel;
};

/**
 * Defensive parse. Any malformed field degrades to the neutral placeholder
 * instead of throwing, so a bad generation costs the coach a summary, never the
 * whole row. Themes are shape-checked (short, few, no long free text) because a
 * "theme" long enough to be a sentence is a theme long enough to leak.
 */
function parseEntrySummary(text: string): ParsedEntrySummary | null {
  try {
    const data = JSON.parse(extractJsonPayload(text)) as Record<string, unknown>;
    const rawSummary = typeof data.summary === 'string' ? data.summary : '';
    const summary = scrubText(rawSummary, MAX_SUMMARY_LENGTH);
    if (!summary) return null;

    const themes = (Array.isArray(data.themes) ? data.themes : [])
      .filter((t): t is string => typeof t === 'string')
      .map((t) => scrubText(t, MAX_THEME_LENGTH).toLowerCase())
      .filter((t) => t.length > 0 && t.split(' ').length <= MAX_THEME_WORDS)
      .slice(0, MAX_THEMES);

    return {
      summary,
      themes,
      sentiment: coerceSentiment(data.sentiment),
      concernLevel: coerceConcernLevel(data.concernLevel),
    };
  } catch {
    return null;
  }
}

function countWords(content: string): number {
  return content.trim().length === 0 ? 0 : content.trim().split(/\s+/).length;
}

/**
 * Fires for EVERY journal entry written by EVERY user of the app.
 *
 * ⚠️ HOT PATH. The overwhelming majority of users are not on a team, and for
 * them this function must cost as close to nothing as possible: one projected
 * read of `users/{uid}` (three fields, not the whole profile document, which in
 * this app is large) and an immediate return. No Claude call, no writes, no
 * team lookup, no roster query, no logging.
 *
 * Do not add work above the `if (!teamId) return;` line. If you need something
 * for the team path, fetch it after that line.
 */
export const onJournalEntryCreated = onDocumentCreated(
  {
    document: `${JOURNALS_COLLECTION}/{entryId}`,
    secrets: [anthropicKey],
    timeoutSeconds: 120,
  },
  async (event) => {
    // Never let this trigger throw: an unhandled rejection here would retry
    // against a player's journal write path, which is the last thing that
    // should be fragile.
    try {
      const entry = event.data?.data() as JournalEntryDoc | undefined;
      const uid = entry?.uid;
      if (!entry || !uid) return;

      // ── The whole non-team cost: one read, then out. ──────────────────────
      const userSnap = await db
        .collection(USERS_COLLECTION)
        .where(admin.firestore.FieldPath.documentId(), '==', uid)
        .select('teamId', 'displayName', 'timezone')
        .limit(1)
        .get();
      const author = userSnap.docs[0]?.data() as
        | { teamId?: string; displayName?: string; timezone?: string }
        | undefined;
      const teamId = author?.teamId;
      if (!teamId) return;
      // ── Everything below here runs only for team members. ────────────────

      const entryId = event.params.entryId;
      const content = entry.content ?? '';
      const date = entryDateKey(entry.createdAt, author?.timezone);

      // Roster lookup does double duty: the coach-entered player name for the
      // portal, and the doc to stamp `lastEntryAt` on.
      const rosterQuery = await db
        .collection(TEAMS_COLLECTION)
        .doc(teamId)
        .collection(TEAM_ROSTER_SUBCOLLECTION)
        .where('uid', '==', uid)
        .limit(1)
        .get();
      const rosterDoc = rosterQuery.docs[0];
      const roster = rosterDoc?.data() as TeamRosterDoc | undefined;
      const playerName = roster?.name || author?.displayName || 'Player';

      let parsed: ParsedEntrySummary | null = null;
      if (content.trim().length > 0) {
        try {
          const response = await callInsightsAnthropic(
            ENTRY_SUMMARY_SYSTEM,
            buildEntrySummaryUserMessage(entry),
            400,
            anthropicKey.value().trim(),
          );
          parsed = parseEntrySummary(response);
          if (parsed && sharesVerbatimRun(parsed.summary, content)) {
            // The model reproduced the entry. Keep the structured signal, drop
            // the prose. Counts only in the log line, never the overlap itself.
            console.warn(
              `onJournalEntryCreated: verbatim overlap detected, summary withheld (team=${teamId})`,
            );
            parsed = { ...parsed, summary: SUMMARY_UNAVAILABLE };
          }
        } catch (err) {
          console.error(
            `onJournalEntryCreated: summary generation failed (team=${teamId}): ${describeError(err)}`,
          );
        }
      }

      // Fallback keeps the coach's timeline complete: mood, participation, and
      // the entry's existence are still recorded when the AI output is unusable.
      // concernLevel is deliberately NOT on this doc: coaches can read
      // team_entry_summaries, and a DevTools peek must not reveal flags.
      const generatedAt = new Date().toISOString();
      const summaryDoc: TeamEntrySummaryDoc = {
        entryId,
        teamId,
        playerUid: uid,
        playerName,
        date,
        mood: entry.mood ?? '',
        moodScore: moodScoreFor(entry.mood),
        mode: entry.mode ?? '',
        promptId: entry.teamPromptId ?? null,
        isTeamPrompt: Boolean(entry.teamPromptId),
        wordCount: countWords(content),
        summary: parsed?.summary ?? SUMMARY_UNAVAILABLE,
        themes: parsed?.themes ?? [],
        sentiment: parsed?.sentiment ?? 'neutral',
        generatedAt,
      };
      const signalDoc: TeamEntrySignalDoc = {
        entryId,
        teamId,
        playerUid: uid,
        date,
        concernLevel: parsed?.concernLevel ?? 'none',
        generatedAt,
      };

      // entryId as the doc id makes a retry overwrite rather than duplicate.
      const batch = db.batch();
      batch.set(
        db.collection(TEAM_ENTRY_SUMMARIES_COLLECTION).doc(entryId),
        summaryDoc,
        { merge: false },
      );
      batch.set(
        db.collection(TEAM_ENTRY_SIGNALS_COLLECTION).doc(entryId),
        signalDoc,
        { merge: false },
      );

      if (rosterDoc) {
        // Day precision, not a timestamp: the roster column is participation
        // ("last wrote on the 8th"), and the exact minute a player journals is
        // behavioral detail the coach has no need for. Same grace-period day
        // key as the summary row, so the two never disagree.
        //
        // Only ever moves forward. Triggers can arrive out of order after a
        // retry, and a backwards jump would show a stale participation date.
        // 'YYYY-MM-DD' compares correctly as a plain string.
        const previous = roster?.lastEntryAt ?? '';
        if (date > previous) {
          batch.set(rosterDoc.ref, { lastEntryAt: date }, { merge: true });
        }
      }

      await batch.commit();
    } catch (err) {
      console.error(`onJournalEntryCreated failed: ${describeError(err)}`);
    }
  },
);

// ─── Part B: weeklyTeamReport ───────────────────────────────────────────────

/**
 * Coach-facing roll-up prompt. The model only ever sees aggregate counts and
 * already-sanitized summaries with no names attached, so it cannot leak what it
 * has never been given. The rules below stop it from re-personalizing.
 */
const TEAM_REPORT_SYSTEM = `You write a weekly roll-up for a sports coach based on aggregate statistics from their team's private journaling.

WHAT YOU ARE LOOKING AT
- The athletes wrote private journal entries. You never see them. You see counts, averages, and short third-person summaries that were already stripped of private detail and stripped of names.
- The coach reads what you write. Anything that reads like a specific personal detail is a privacy failure even if you inferred it.

HARD RULES
- Aggregate only. Never name an athlete, never say "one player" followed by anything that would identify them. Individual names and check-in recommendations are added by the system, not by you.
- Never quote or closely paraphrase any summary you were given, and never use quotation marks.
- Never mention or imply relationships, family or home life, medical or mental-health history, therapy, medication, sex, sexuality, gender identity, legal trouble, money, grades, or substance use, even if a summary hints at it.
- No diagnostic or clinical language and no assessment of anyone's mental health. This is coaching awareness, not screening.
- Plain, practical, specific to what the numbers show. Talk about participation, mood and its direction, recurring themes, and what the coach could do this week.

FIELDS
- summary: 3 to 5 sentences covering participation, mood and its trend, and the dominant themes of the week.
- wins: 2 to 4 short strings, the genuinely positive signals.
- concerns: 0 to 4 short strings, aggregate patterns worth attention, each with what the coach could do about it. Stay at the level of "check in with the group about workload", never a diagnosis.

Return ONLY valid JSON, no prose before or after:
{ "summary": string, "wins": string[], "concerns": string[] }`;

const MAX_REPORT_SUMMARY_LENGTH = 1200;
const MAX_REPORT_BULLET_LENGTH = 200;
const MAX_REPORT_BULLETS = 4;
const MAX_REPORT_THEMES = 6;
const MAX_WATCH_LIST = 8;
/** Sample of unattributed summaries handed to the model for texture. */
const MAX_SUMMARIES_TO_MODEL = 60;
const DAYS_IN_PERIOD = 7;
/** A player who wrote this many fewer days than last week is worth a look. */
const PARTICIPATION_DROP_DAYS = 2;

const REPORT_EMPTY_SUMMARY = 'No entries were written this week.';

type SummaryRow = {
  playerUid: string;
  playerName: string;
  date: string;
  moodScore: number;
  themes: string[];
  sentiment: Sentiment;
  concernLevel: ConcernLevel;
  summary: string;
};

/**
 * Local twin of the private `forEachDocPaged` in index.ts: walks an ordered
 * query in stable batches so the job covers every team rather than the first N.
 */
async function forEachDocPaged(
  orderedQuery: admin.firestore.Query,
  batchSize: number,
  handler: (doc: admin.firestore.QueryDocumentSnapshot) => Promise<void>,
): Promise<void> {
  let cursor: admin.firestore.QueryDocumentSnapshot | undefined;
  for (;;) {
    let page = orderedQuery.limit(batchSize);
    if (cursor) page = page.startAfter(cursor);
    const snap = await page.get();
    if (snap.empty) break;
    for (const doc of snap.docs) {
      await handler(doc);
    }
    if (snap.size < batchSize) break;
    cursor = snap.docs[snap.docs.length - 1];
  }
}

async function fetchSummaryRows(
  teamId: string,
  start: string,
  end: string,
): Promise<SummaryRow[]> {
  // orderBy date desc matches the (teamId ASC, date DESC) composite index.
  const snap = await db
    .collection(TEAM_ENTRY_SUMMARIES_COLLECTION)
    .where('teamId', '==', teamId)
    .where('date', '>=', start)
    .where('date', '<=', end)
    .orderBy('date', 'desc')
    .get();

  // Concern lives in the analyst-only signals collection. While the pilot keeps
  // SURFACE_CONCERN_SIGNALS false we skip the read and treat every row as none,
  // so the weekly report cannot reintroduce flags through the back door.
  const concernByEntryId = new Map<string, ConcernLevel>();
  if (SURFACE_CONCERN_SIGNALS && !snap.empty) {
    const signalSnap = await db
      .collection(TEAM_ENTRY_SIGNALS_COLLECTION)
      .where('teamId', '==', teamId)
      .where('date', '>=', start)
      .where('date', '<=', end)
      .orderBy('date', 'desc')
      .get();
    for (const doc of signalSnap.docs) {
      const data = doc.data() as Partial<TeamEntrySignalDoc>;
      concernByEntryId.set(doc.id, coerceConcernLevel(data.concernLevel));
    }
  }

  return snap.docs.map((doc) => {
    const data = doc.data() as Partial<TeamEntrySummaryDoc>;
    return {
      playerUid: typeof data.playerUid === 'string' ? data.playerUid : '',
      playerName: typeof data.playerName === 'string' ? data.playerName : 'Player',
      date: typeof data.date === 'string' ? data.date : '',
      moodScore: typeof data.moodScore === 'number' ? data.moodScore : 5,
      themes: Array.isArray(data.themes)
        ? data.themes.filter((t): t is string => typeof t === 'string')
        : [],
      sentiment: coerceSentiment(data.sentiment),
      concernLevel: concernByEntryId.get(doc.id) ?? 'none',
      summary: typeof data.summary === 'string' ? data.summary : '',
    };
  });
}

/** Distinct days each player wrote on, which is the participation unit. */
function daysWrittenByPlayer(rows: SummaryRow[]): Map<string, Set<string>> {
  const byPlayer = new Map<string, Set<string>>();
  for (const row of rows) {
    if (!row.playerUid || !row.date) continue;
    const set = byPlayer.get(row.playerUid) ?? new Set<string>();
    set.add(row.date);
    byPlayer.set(row.playerUid, set);
  }
  return byPlayer;
}

function topThemes(rows: SummaryRow[], limit: number): { theme: string; count: number }[] {
  const counts = new Map<string, number>();
  for (const row of rows) {
    for (const theme of row.themes) {
      const key = theme.trim().toLowerCase();
      if (!key) continue;
      counts.set(key, (counts.get(key) ?? 0) + 1);
    }
  }
  return [...counts.entries()]
    .map(([theme, count]) => ({ theme, count }))
    .sort((a, b) => b.count - a.count || a.theme.localeCompare(b.theme))
    .slice(0, limit);
}

function averageMood(rows: SummaryRow[]): number {
  if (rows.length === 0) return 0;
  const total = rows.reduce((sum, row) => sum + row.moodScore, 0);
  return Math.round((total / rows.length) * 10) / 10;
}

function moodTrendLabel(current: number, previous: number | null): string {
  if (previous === null || previous === 0) return 'no comparable week to compare against';
  const delta = Math.round((current - previous) * 10) / 10;
  if (delta >= 0.5) return `up ${delta.toFixed(1)} points from last week`;
  if (delta <= -0.5) return `down ${Math.abs(delta).toFixed(1)} points from last week`;
  return 'roughly flat versus last week';
}

/**
 * Watch list, built entirely from counts in code.
 *
 * Deliberately NOT AI-authored: this is the only part of the report that names
 * an individual, so every note here is a template about participation. There is
 * no field for "why", because the why is exactly the private detail the coach is
 * not entitled to. While [SURFACE_CONCERN_SIGNALS] is false this list is purely
 * about who has stopped writing.
 */
function buildWatchList(
  rows: SummaryRow[],
  previousRows: SummaryRow[],
): TeamReportWatchItem[] {
  const nameByUid = new Map<string, string>();
  const levelByUid = new Map<string, ConcernLevel>();
  for (const row of rows) {
    if (!row.playerUid) continue;
    nameByUid.set(row.playerUid, row.playerName);
    if (!SURFACE_CONCERN_SIGNALS) continue;
    const current = levelByUid.get(row.playerUid);
    if (row.concernLevel === 'flag' || (row.concernLevel === 'watch' && current !== 'flag')) {
      levelByUid.set(row.playerUid, row.concernLevel);
    }
  }

  const thisWeek = daysWrittenByPlayer(rows);
  const lastWeek = daysWrittenByPlayer(previousRows);
  for (const row of previousRows) {
    if (row.playerUid && !nameByUid.has(row.playerUid)) {
      nameByUid.set(row.playerUid, row.playerName);
    }
  }

  const items: TeamReportWatchItem[] = [];

  for (const [playerUid, level] of levelByUid.entries()) {
    const days = thisWeek.get(playerUid)?.size ?? 0;
    const note = level === 'flag'
      ? `One or more entries this week suggest a check-in would help. Recommend a conversation. Wrote on ${days} of ${DAYS_IN_PERIOD} days.`
      : `Tone worth keeping an eye on this week. Wrote on ${days} of ${DAYS_IN_PERIOD} days.`;
    items.push({
      playerUid,
      playerName: nameByUid.get(playerUid) ?? 'Player',
      concernLevel: level,
      note,
    });
  }

  for (const [playerUid, previousDays] of lastWeek.entries()) {
    if (levelByUid.has(playerUid)) continue;
    const days = thisWeek.get(playerUid)?.size ?? 0;
    if (previousDays.size - days < PARTICIPATION_DROP_DAYS) continue;
    items.push({
      playerUid,
      playerName: nameByUid.get(playerUid) ?? 'Player',
      concernLevel: 'none',
      note: `Participation dropped: wrote on ${days} of ${DAYS_IN_PERIOD} days, down from ${previousDays.size} last week.`,
    });
  }

  const rank: Record<ConcernLevel, number> = { flag: 0, watch: 1, none: 2 };
  return items
    .sort((a, b) => rank[a.concernLevel] - rank[b.concernLevel]
      || a.playerName.localeCompare(b.playerName))
    .slice(0, MAX_WATCH_LIST);
}

async function countActivePlayers(teamId: string): Promise<number> {
  const snap = await db
    .collection(TEAMS_COLLECTION)
    .doc(teamId)
    .collection(TEAM_ROSTER_SUBCOLLECTION)
    .where('status', '==', 'active')
    .count()
    .get();
  return snap.data().count;
}

async function previousWeekAverageMood(
  teamId: string,
  period: string,
): Promise<number | null> {
  const prior = previousPeriod(period);
  if (!prior) return null;
  const snap = await db
    .collection(TEAMS_COLLECTION)
    .doc(teamId)
    .collection(TEAM_REPORTS_SUBCOLLECTION)
    .doc(prior)
    .get();
  if (!snap.exists) return null;
  const value = (snap.data() as Partial<TeamReportDoc>).averageMoodScore;
  return typeof value === 'number' ? value : null;
}

function buildTeamReportUserMessage(args: {
  team: TeamDoc;
  periodStart: string;
  periodEnd: string;
  rows: SummaryRow[];
  activePlayerCount: number;
  participationRate: number;
  averageMoodScore: number;
  moodTrend: string;
  themes: { theme: string; count: number }[];
}): string {
  const {
    team,
    periodStart,
    periodEnd,
    rows,
    activePlayerCount,
    participationRate,
    averageMoodScore,
    moodTrend,
    themes,
  } = args;

  const sentimentCounts = { positive: 0, neutral: 0, negative: 0 };
  let watchCount = 0;
  let flagCount = 0;
  for (const row of rows) {
    sentimentCounts[row.sentiment] += 1;
    if (row.concernLevel === 'watch') watchCount += 1;
    if (row.concernLevel === 'flag') flagCount += 1;
  }

  const byPlayer = daysWrittenByPlayer(rows);
  const dayCounts = [...byPlayer.values()].map((set) => set.size);
  const consistent = dayCounts.filter((d) => d >= 5).length;
  const occasional = dayCounts.filter((d) => d >= 1 && d <= 2).length;
  const silent = Math.max(0, activePlayerCount - byPlayer.size);

  const themeLines = themes.length > 0
    ? themes.map((t) => `- ${t.theme}: ${t.count} entries`).join('\n')
    : '- none recorded';

  // Unattributed sample. These strings are already coach-visible and already
  // sanitized; no uid, name, or date is attached to any of them.
  const sample = rows
    .map((row) => row.summary)
    .filter((s) => s.length > 0 && s !== SUMMARY_UNAVAILABLE)
    .slice(0, MAX_SUMMARIES_TO_MODEL)
    .map((s) => `- ${s}`)
    .join('\n');

  return [
    `Team sport: ${team.sport || 'unspecified'}`,
    team.guidance?.focusAreas?.length
      ? `Coach's focus areas this season: ${team.guidance.focusAreas.join(', ')}`
      : '',
    `Week covered: ${periodStart} to ${periodEnd}`,
    `Active players on the roster: ${activePlayerCount}`,
    `Entries written: ${rows.length}`,
    `Participation rate: ${Math.round(participationRate * 100)}% of possible player-days`,
    `Players writing 5 or more days: ${consistent}. Writing 1 to 2 days: ${occasional}. Wrote nothing: ${silent}.`,
    `Average mood score (1 to 10): ${averageMoodScore}, ${moodTrend}`,
    `Entry tone split: ${sentimentCounts.positive} positive, ${sentimentCounts.neutral} neutral, ${sentimentCounts.negative} negative`,
    // Withheld from the report while concern signals are not surfaced to
    // coaches, so the roll-up cannot reintroduce them as prose.
    SURFACE_CONCERN_SIGNALS
      ? `Entries marked for awareness: ${watchCount} watch, ${flagCount} flag`
      : '',
    `Most common themes:\n${themeLines}`,
    sample ? `Sanitized, unattributed entry summaries:\n${sample}` : '',
    'Write the roll-up as JSON per your instructions.',
  ]
    .filter(Boolean)
    .join('\n\n');
}

function parseTeamReportPayload(
  text: string,
): { summary: string; wins: string[]; concerns: string[] } | null {
  try {
    const data = JSON.parse(extractJsonPayload(text)) as Record<string, unknown>;
    const summary = scrubText(
      typeof data.summary === 'string' ? data.summary : '',
      MAX_REPORT_SUMMARY_LENGTH,
    );
    if (!summary) return null;
    const toBullets = (value: unknown): string[] => (Array.isArray(value) ? value : [])
      .filter((item): item is string => typeof item === 'string')
      .map((item) => scrubText(item, MAX_REPORT_BULLET_LENGTH))
      .filter((item) => item.length > 0)
      .slice(0, MAX_REPORT_BULLETS);
    return {
      summary,
      wins: toBullets(data.wins),
      concerns: toBullets(data.concerns),
    };
  } catch {
    return null;
  }
}

/**
 * Builds and writes one team's report for one period. Shared by the scheduled
 * job and the on-demand callable so a regenerated report is identical in shape
 * to a scheduled one. Writing to `reports/{period}` makes both idempotent.
 */
async function generateTeamReportInternal(
  teamId: string,
  team: TeamDoc,
  period: string,
  apiKey: string,
): Promise<void> {
  const range = isoWeekRange(period);
  if (!range) {
    throw new Error('Invalid period');
  }
  const priorPeriod = previousPeriod(period);
  const priorRange = priorPeriod ? isoWeekRange(priorPeriod) : null;

  const [rows, previousRows, activePlayerCount, priorAverage] = await Promise.all([
    fetchSummaryRows(teamId, range.start, range.end),
    priorRange
      ? fetchSummaryRows(teamId, priorRange.start, priorRange.end)
      : Promise.resolve([] as SummaryRow[]),
    countActivePlayers(teamId),
    previousWeekAverageMood(teamId, period),
  ]);

  const possibleDays = Math.max(1, activePlayerCount * DAYS_IN_PERIOD);
  const writtenDays = [...daysWrittenByPlayer(rows).values()]
    .reduce((sum, set) => sum + set.size, 0);
  const participationRate = Math.min(1, Math.round((writtenDays / possibleDays) * 100) / 100);
  const averageMoodScore = averageMood(rows);
  const themes = topThemes(rows, MAX_REPORT_THEMES);

  let summary = REPORT_EMPTY_SUMMARY;
  let wins: string[] = [];
  let concerns: string[] = [];

  if (rows.length > 0) {
    // One Claude call per team per period.
    const response = await callInsightsAnthropic(
      TEAM_REPORT_SYSTEM,
      buildTeamReportUserMessage({
        team,
        periodStart: range.start,
        periodEnd: range.end,
        rows,
        activePlayerCount,
        participationRate,
        averageMoodScore,
        moodTrend: moodTrendLabel(averageMoodScore, priorAverage),
        themes,
      }),
      1200,
      apiKey,
    );
    const parsed = parseTeamReportPayload(response);
    if (parsed) {
      summary = parsed.summary;
      wins = parsed.wins;
      concerns = parsed.concerns;
    } else {
      summary = `${rows.length} entries this week from ${daysWrittenByPlayer(rows).size} players. `
        + 'The written roll-up could not be generated, the numbers below are still accurate.';
    }
  }

  const report: TeamReportDoc = {
    period,
    teamId,
    periodStart: range.start,
    periodEnd: range.end,
    entryCount: rows.length,
    activePlayerCount,
    participationRate,
    averageMoodScore,
    summary,
    themes: themes.map((t) => t.theme),
    wins,
    concerns,
    watchList: buildWatchList(rows, previousRows),
    generatedAt: new Date().toISOString(),
    generatedByModel: TEAM_INSIGHTS_MODEL,
  };

  await db
    .collection(TEAMS_COLLECTION)
    .doc(teamId)
    .collection(TEAM_REPORTS_SUBCOLLECTION)
    .doc(period)
    .set(report, { merge: false });
}

function isTeamActive(team: TeamDoc, nowMs: number): boolean {
  const endsMs = team.seasonEndsAt ? Date.parse(team.seasonEndsAt) : NaN;
  // An unparseable or missing season end is treated as active: better a
  // report nobody reads than a silently skipped team.
  return Number.isNaN(endsMs) || endsMs >= nowMs;
}

/**
 * weeklyTeamReport — Sunday 18:00 UTC, after the week's last entries have
 * landed. One roll-up per active team into `teams/{teamId}/reports/{period}`.
 * Errors are isolated per team so one bad team cannot cost every other team its
 * report, matching `weeklyInsightDelivery` and `weeklyPartnerDigest`.
 */
export const weeklyTeamReport = onSchedule(
  {
    schedule: '0 18 * * 0',
    secrets: [anthropicKey],
    timeoutSeconds: 540,
    maxInstances: SCHEDULED_MAX_INSTANCES,
  },
  async () => {
    const now = new Date();
    const nowMs = now.getTime();
    const period = isoWeekPeriod(now);
    const apiKey = anthropicKey.value().trim();

    // Season filtering happens in memory: a where() on seasonEndsAt alongside
    // the createdAt cursor would need a composite index this phase cannot add.
    const teamsQuery = db.collection(TEAMS_COLLECTION).orderBy('createdAt');

    let generated = 0;
    let skipped = 0;
    let failed = 0;

    await forEachDocPaged(teamsQuery, 50, async (teamDoc) => {
      const team = teamDoc.data() as TeamDoc;
      if (!isTeamActive(team, nowMs)) {
        skipped += 1;
        return;
      }
      try {
        await generateTeamReportInternal(teamDoc.id, team, period, apiKey);
        generated += 1;
      } catch (err) {
        failed += 1;
        console.error(
          `weeklyTeamReport failed for team=${teamDoc.id} period=${period}: ${describeError(err)}`,
        );
      }
    });

    console.log(
      `weeklyTeamReport: period=${period} generated=${generated} skipped=${skipped} failed=${failed}`,
    );
  },
);

/** On-demand regeneration from the portal's insights page. */
export const generateTeamReport = onCall(
  {
    secrets: [anthropicKey],
    invoker: 'public',
    timeoutSeconds: 300,
    memory: '512MiB',
  },
  async (request): Promise<GenerateTeamReportResponse> => {
    const data = (request.data ?? {}) as Partial<GenerateTeamReportRequest>;
    const teamId = data.teamId;
    if (!teamId || typeof teamId !== 'string') {
      throw new HttpsError('invalid-argument', 'teamId is required.');
    }
    await assertTeamAccess(request.auth?.uid, teamId);

    const period = data.period;
    if (!period || typeof period !== 'string' || !isoWeekRange(period)) {
      throw new HttpsError('invalid-argument', "period must look like '2026-W33'.");
    }

    const teamSnap = await db.collection(TEAMS_COLLECTION).doc(teamId).get();
    const team = teamSnap.data() as TeamDoc;

    try {
      await generateTeamReportInternal(teamId, team, period, anthropicKey.value().trim());
    } catch (err) {
      console.error(
        `generateTeamReport failed for team=${teamId} period=${period}: ${describeError(err)}`,
      );
      throw new HttpsError('internal', 'Failed to generate the team report.');
    }

    return { period };
  },
);
