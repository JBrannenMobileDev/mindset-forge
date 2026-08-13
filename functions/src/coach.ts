/**
 * Coach team portal: account setup, roster/invites, and the AI prompt bank.
 *
 * The journal-summary trigger and weekly report live in a separate file
 * (team_insights.ts) — that is the privacy boundary between "reads a coach
 * triggers" and "reads that ever touch raw journal text". Nothing in this
 * file reads `journals` or `team_entry_summaries` content.
 */

import * as admin from 'firebase-admin';
import Anthropic from '@anthropic-ai/sdk';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import {
  ROLES_CONFIG_DOC_PATH,
  TEAMS_COLLECTION,
  TEAM_PROMPTS_SUBCOLLECTION,
  TEAM_SCHEDULE_SUBCOLLECTION,
  TEAM_ROSTER_SUBCOLLECTION,
  TEAM_INVITES_COLLECTION,
  USERS_COLLECTION,
  teamInviteLink,
  type TeamDoc,
  type TeamGuidance,
  type TeamPromptDoc,
  type TeamScheduleDoc,
  type TeamRosterDoc,
  type TeamInviteDoc,
  type CoachRole,
  type CoachContextTeam,
  type GetCoachContextResponse,
  type InitializeCoachAccountRequest,
  type InitializeCoachAccountResponse,
  type CreatePlayerInvitesRequest,
  type CreatedPlayerInvite,
  type GetTeamInviteInfoRequest,
  type GetTeamInviteInfoResponse,
  type AcceptTeamInviteRequest,
  type AcceptTeamInviteResponse,
  type GenerateTeamPromptsRequest,
  type GeneratedTeamPrompt,
  type AddManualPromptRequest,
  type AddManualPromptResponse,
  type DeletePromptRequest,
  type AssignTeamPromptRequest,
  type UnassignTeamPromptRequest,
  type RemovePlayerRequest,
  type UpdateTeamSettingsRequest,
} from './coach_types';

const anthropicKey = defineSecret('ANTHROPIC_API_KEY');

const db = admin.firestore();

/** Keeps coach callables under the us-central1 CPU quota on deploy. */
const COACH_MAX_INSTANCES = 5;

// ─── Small shared helpers ──────────────────────────────────────────────────

/**
 * Strips any Anthropic API key pattern from a string before it reaches logs.
 * Duplicated from index.ts (kept file-local, same as blog.ts) rather than
 * imported, since index.ts's copy is a private, unexported helper.
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

/** Firestore rejects explicit undefined field values. */
function stripUndefined(obj: Record<string, unknown>): Record<string, unknown> {
  const cleaned = { ...obj };
  for (const key of Object.keys(cleaned)) {
    if (cleaned[key] === undefined) {
      delete cleaned[key];
    }
  }
  return cleaned;
}

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

function isValidEmail(value: string): boolean {
  return EMAIL_PATTERN.test(value);
}

function isValidDateString(value: string): boolean {
  if (!DATE_PATTERN.test(value)) return false;
  return !Number.isNaN(Date.parse(value));
}

/**
 * Coach/analyst auth guard, modeled on `assertBlogAdmin` in blog.ts. Every
 * team-scoped callable below calls this first, before touching any team data.
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

async function isAnalystUid(uid: string): Promise<boolean> {
  const rolesSnap = await db.doc(ROLES_CONFIG_DOC_PATH).get();
  const analystUids = (rolesSnap.data()?.analystUids ?? []) as string[];
  return analystUids.includes(uid);
}

// ─── Claude helper (prompt generation only) ────────────────────────────────

function extractJsonPayload(text: string): string {
  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start === -1 || end === -1 || end <= start) return text.trim();
  return text.slice(start, end + 1);
}

async function callCoachAnthropic(
  systemPrompt: string,
  userPrompt: string,
  maxTokens: number,
  apiKey: string,
): Promise<string> {
  const client = new Anthropic({ apiKey });
  const message = await client.messages.create({
    model: 'claude-sonnet-4-5',
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

const TEAM_PROMPT_SYSTEM = `You write journal prompts for a sports team mindset app. Coaches assign one
prompt per day and athletes reflect on it in a private journal.

Rules for every prompt:
- One single, open-ended question. No multi-part questions, no yes/no questions.
- About mindset, preparation, focus, resilience, confidence, or team dynamics, tailored to the sport and guidance given.
- Never ask the athlete to disclose medical, clinical, psychiatric, or diagnostic information (no symptoms, medications, therapy, injuries requiring treatment). If in doubt, keep it about mindset and performance, not health.
- Plain, direct language a teenage or young-adult athlete would actually want to answer. Not corporate, not clinical.
- Do not repeat or closely paraphrase any prompt in the "existing prompts" list.

Return ONLY valid JSON, no prose before or after: { "prompts": [ { "text": string, "theme": string }, ... ] }`;

function buildTeamPromptUserMessage(
  guidance: TeamGuidance,
  fallbackSport: string,
  theme: string,
  count: number,
  recentTexts: string[],
): string {
  const guidanceLines = [
    `Sport: ${guidance.sport || fallbackSport}`,
    guidance.season ? `Season stage: ${guidance.season}` : null,
    guidance.focusAreas.length > 0 ? `Focus areas: ${guidance.focusAreas.join(', ')}` : null,
    guidance.tone ? `Coach's preferred tone: ${guidance.tone}` : null,
    guidance.notes ? `Notes from the coach: ${guidance.notes}` : null,
  ]
    .filter((line): line is string => Boolean(line))
    .join('\n');

  const existingBlock = recentTexts.length > 0
    ? `Existing prompts (do not repeat or closely paraphrase):\n${recentTexts.map((t) => `- ${t}`).join('\n')}`
    : 'No existing prompts yet.';

  const themeLine = theme ? `Requested theme for this batch: ${theme}` : '';

  return [
    `Generate exactly ${count} journal prompts for this team.`,
    guidanceLines,
    themeLine,
    existingBlock,
    `Return exactly ${count} items in the JSON array.`,
  ]
    .filter(Boolean)
    .join('\n\n');
}

function parseGeneratedPrompts(
  text: string,
  count: number,
  fallbackTheme: string,
): { text: string; theme: string }[] {
  try {
    const data = JSON.parse(extractJsonPayload(text)) as Record<string, unknown>;
    const raw = Array.isArray(data.prompts) ? data.prompts : [];
    return raw
      .map((item) => {
        if (!item || typeof item !== 'object') return null;
        const row = item as Record<string, unknown>;
        const promptText = typeof row.text === 'string' ? row.text.trim() : '';
        const theme = typeof row.theme === 'string' && row.theme.trim()
          ? row.theme.trim()
          : fallbackTheme;
        if (!promptText) return null;
        return { text: promptText, theme };
      })
      .filter((item): item is { text: string; theme: string } => item !== null)
      .slice(0, count);
  } catch {
    return [];
  }
}

// ─── getCoachContext ────────────────────────────────────────────────────────

async function computeRosterCounts(
  teamId: string,
): Promise<{ playerCount: number; activeCount: number }> {
  const rosterRef = db
    .collection(TEAMS_COLLECTION)
    .doc(teamId)
    .collection(TEAM_ROSTER_SUBCOLLECTION);
  const [totalSnap, activeSnap] = await Promise.all([
    rosterRef.count().get(),
    rosterRef.where('status', '==', 'active').count().get(),
  ]);
  return {
    playerCount: totalSnap.data().count,
    activeCount: activeSnap.data().count,
  };
}

/** Returns the caller's role and every team they can see (all teams for an analyst). */
export const getCoachContext = onCall(
  { invoker: 'public', maxInstances: COACH_MAX_INSTANCES },
  async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Must be signed in.');
  }

  const analyst = await isAnalystUid(uid);

  let teamDocs: FirebaseFirestore.QueryDocumentSnapshot[];
  let role: CoachRole | null;
  if (analyst) {
    const snap = await db.collection(TEAMS_COLLECTION).get();
    teamDocs = snap.docs;
    role = 'analyst';
  } else {
    const snap = await db
      .collection(TEAMS_COLLECTION)
      .where('coachUid', '==', uid)
      .get();
    teamDocs = snap.docs;
    role = teamDocs.length > 0 ? 'coach' : null;
  }

  const teams: CoachContextTeam[] = await Promise.all(
    teamDocs.map(async (doc) => {
      const data = doc.data() as TeamDoc;
      const counts = await computeRosterCounts(doc.id);
      return {
        teamId: doc.id,
        name: data.name,
        sport: data.sport,
        seasonEndsAt: data.seasonEndsAt,
        playerCount: counts.playerCount,
        activeCount: counts.activeCount,
      };
    }),
  );

  const response: GetCoachContextResponse = { role, teams };
  return response;
});

// ─── initializeCoachAccount ─────────────────────────────────────────────────

/**
 * Coach signup: validates the access code, then creates the coach's user doc
 * and their team in one batch.
 *
 * Idempotency: if the caller already owns a team, we reject with
 * 'already-exists' rather than silently creating a second team. A coach
 * accidentally double-submitting signup would otherwise end up managing two
 * rosters with no portal UI to switch between them — a clear error pointing
 * them at login is much less confusing.
 *
 * Access codes are intentionally multi-use (a program may run several teams,
 * or a code may be shared across a coaching staff) — we never mark a code
 * consumed. Every redemption is logged for audit, but the code value itself
 * never appears in logs.
 */
export const initializeCoachAccount = onCall(
  { invoker: 'public', maxInstances: COACH_MAX_INSTANCES },
  async (request): Promise<InitializeCoachAccountResponse> => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Must be signed in.');
    }

    const data = (request.data ?? {}) as Partial<InitializeCoachAccountRequest>;
    const accessCode = typeof data.accessCode === 'string' ? data.accessCode.trim() : '';
    const coachName = typeof data.coachName === 'string' ? data.coachName.trim() : '';
    const teamName = typeof data.teamName === 'string' ? data.teamName.trim() : '';
    const sport = typeof data.sport === 'string' ? data.sport.trim() : '';
    const seasonEndsAt = typeof data.seasonEndsAt === 'string' ? data.seasonEndsAt : '';

    if (!accessCode) {
      throw new HttpsError('invalid-argument', 'accessCode is required.');
    }
    if (!coachName || !teamName || !sport) {
      throw new HttpsError(
        'invalid-argument',
        'coachName, teamName, and sport are required.',
      );
    }
    if (!seasonEndsAt || Number.isNaN(Date.parse(seasonEndsAt))) {
      throw new HttpsError('invalid-argument', 'seasonEndsAt must be a valid date.');
    }

    const rolesSnap = await db.doc(ROLES_CONFIG_DOC_PATH).get();
    const validCodes = (rolesSnap.data()?.coachSignupCodes ?? []) as string[];
    if (!validCodes.includes(accessCode)) {
      throw new HttpsError('permission-denied', 'Invalid access code.');
    }

    const existingTeam = await db
      .collection(TEAMS_COLLECTION)
      .where('coachUid', '==', uid)
      .limit(1)
      .get();
    if (!existingTeam.empty) {
      throw new HttpsError(
        'already-exists',
        'This account already has a team. Log in to the coach portal instead.',
      );
    }

    const teamRef = db.collection(TEAMS_COLLECTION).doc();
    const teamId = teamRef.id;
    const now = new Date().toISOString();

    const team: TeamDoc = {
      teamId,
      name: teamName,
      sport,
      coachUid: uid,
      memberUids: [], // Must always exist — firestore.rules' isTeamMember() reads it unconditionally.
      seasonEndsAt,
      guidance: { sport: '', season: '', focusAreas: [], tone: '', notes: '' },
      createdAt: now,
    };

    // Coaches do NOT get comped app access (no premiumUntil) — the access
    // code gates portal signup, and comping the coach too would turn it into
    // a free-app loophole. See the plan's "open item to confirm" note.
    const coachUserDoc = {
      uid,
      email: request.auth?.token.email ?? '',
      displayName: coachName,
      userType: 'coach',
      teamId,
      // Marks onboarding as already complete so coaches land straight in the
      // portal. Must equal the Flutter app's total step count, which
      // UserProfile.hasCompletedOnboarding checks with `>= 8`. Coach docs have
      // no mindsetBlueprintSummary, so a stale lower value would fail the
      // legacy fallbacks and trap them in the onboarding flow.
      onboardingStep: 8,
      subscriptionStatus: 'free',
      createdAt: now,
    };

    const batch = db.batch();
    batch.set(teamRef, team);
    batch.set(db.collection(USERS_COLLECTION).doc(uid), coachUserDoc, { merge: true });
    await batch.commit();

    console.log(`initializeCoachAccount: access code redeemed by uid=${uid}, teamId=${teamId}`);

    return { teamId };
  },
);

// ─── createPlayerInvites ────────────────────────────────────────────────────

const MAX_PLAYER_INVITES_PER_CALL = 60;

/**
 * Rosters a batch of players and creates one invite per player. Response
 * includes a non-frozen `skipped` list (duplicate emails already on the
 * roster) so the portal can tell the coach why fewer invites came back than
 * players submitted — see the report for why this is additive, not a break
 * of the frozen `invites` shape.
 */
export const createPlayerInvites = onCall(
  { invoker: 'public', maxInstances: COACH_MAX_INSTANCES },
  async (request) => {
  const data = (request.data ?? {}) as Partial<CreatePlayerInvitesRequest>;
  const teamId = data.teamId;
  if (!teamId || typeof teamId !== 'string') {
    throw new HttpsError('invalid-argument', 'teamId is required.');
  }
  await assertTeamAccess(request.auth?.uid, teamId);

  const players = data.players;
  if (!Array.isArray(players) || players.length === 0) {
    throw new HttpsError('invalid-argument', 'players must be a non-empty array.');
  }
  if (players.length > MAX_PLAYER_INVITES_PER_CALL) {
    throw new HttpsError(
      'invalid-argument',
      `Cannot invite more than ${MAX_PLAYER_INVITES_PER_CALL} players in one call.`,
    );
  }

  const cleaned = players.map((p) => ({
    name: typeof p?.name === 'string' ? p.name.trim() : '',
    email: typeof p?.email === 'string' ? p.email.trim().toLowerCase() : '',
  }));
  const invalid = cleaned.find((p) => !p.name || !isValidEmail(p.email));
  if (invalid) {
    throw new HttpsError('invalid-argument', 'Every player needs a name and a valid email.');
  }

  const teamSnap = await db.collection(TEAMS_COLLECTION).doc(teamId).get();
  const team = teamSnap.data() as TeamDoc;
  const coachSnap = await db.collection(USERS_COLLECTION).doc(team.coachUid).get();
  const coachName = (coachSnap.data()?.displayName as string | undefined) ?? 'Your coach';

  const rosterCollection = db
    .collection(TEAMS_COLLECTION)
    .doc(teamId)
    .collection(TEAM_ROSTER_SUBCOLLECTION);
  const existingRosterSnap = await rosterCollection.get();
  const existingEmails = new Set(
    existingRosterSnap.docs
      .map((doc) => (doc.data().email as string | undefined)?.toLowerCase())
      .filter((e): e is string => Boolean(e)),
  );

  const now = new Date().toISOString();
  const batch = db.batch();
  const invites: CreatedPlayerInvite[] = [];
  const skipped: { name: string; email: string }[] = [];

  for (const player of cleaned) {
    if (existingEmails.has(player.email)) {
      skipped.push(player);
      continue;
    }
    existingEmails.add(player.email); // guard against dupes within this same request

    const rosterRef = rosterCollection.doc();
    const playerId = rosterRef.id;
    const inviteRef = db.collection(TEAM_INVITES_COLLECTION).doc();
    const inviteId = inviteRef.id;

    const rosterDoc: TeamRosterDoc = {
      playerId,
      name: player.name,
      email: player.email,
      inviteId,
      status: 'invited',
      uid: null,
      joinedAt: null,
      lastEntryAt: null,
      createdAt: now,
    };
    const inviteDoc: TeamInviteDoc = {
      inviteId,
      teamId,
      teamName: team.name,
      coachUid: team.coachUid,
      coachName,
      playerId,
      playerName: player.name,
      playerEmail: player.email,
      status: 'pending',
      createdAt: now,
      acceptedAt: null,
      acceptedUid: null,
    };

    batch.set(rosterRef, rosterDoc);
    batch.set(inviteRef, inviteDoc);
    invites.push({
      playerId,
      name: player.name,
      email: player.email,
      inviteId,
      inviteLink: teamInviteLink(inviteId),
    });
  }

  if (invites.length > 0) {
    await batch.commit();
  }

  // Counts only — never log names/emails/invite links together.
  console.log(
    `createPlayerInvites: team=${teamId} created=${invites.length} skipped=${skipped.length}`,
  );

  return { invites, skipped };
});

// ─── getTeamInviteInfo / acceptTeamInvite ───────────────────────────────────

/** Public: called before the player has an account, so it returns the bare minimum. */
export const getTeamInviteInfo = onCall(
  { invoker: 'public', maxInstances: COACH_MAX_INSTANCES },
  async (request) => {
  const data = (request.data ?? {}) as Partial<GetTeamInviteInfoRequest>;
  const inviteId = data.inviteId;
  if (!inviteId || typeof inviteId !== 'string') {
    throw new HttpsError('invalid-argument', 'inviteId is required.');
  }

  const snap = await db.collection(TEAM_INVITES_COLLECTION).doc(inviteId).get();
  if (!snap.exists) {
    throw new HttpsError('not-found', 'Invite not found.');
  }
  const invite = snap.data() as TeamInviteDoc;

  const response: GetTeamInviteInfoResponse = {
    teamName: invite.teamName,
    coachName: invite.coachName,
    playerName: invite.playerName,
    playerEmail: invite.playerEmail,
    status: invite.status,
  };
  return response;
});

/**
 * Called from the join page right after it creates the player's Firebase Auth
 * account. Uses a transaction because the roster/team/invite writes and the
 * user-doc create-or-merge must all succeed or fail together — a partial
 * failure here would leave a player with `teamId` set but no roster/schedule
 * access, or vice versa.
 */
export const acceptTeamInvite = onCall(
  { invoker: 'public', maxInstances: COACH_MAX_INSTANCES },
  async (request): Promise<AcceptTeamInviteResponse> => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Must be signed in.');
    }

    const data = (request.data ?? {}) as Partial<AcceptTeamInviteRequest>;
    const inviteId = data.inviteId;
    if (!inviteId || typeof inviteId !== 'string') {
      throw new HttpsError('invalid-argument', 'inviteId is required.');
    }

    const inviteRef = db.collection(TEAM_INVITES_COLLECTION).doc(inviteId);
    const now = new Date().toISOString();
    const authEmail = request.auth?.token.email;

    return db.runTransaction(async (tx) => {
      const inviteSnap = await tx.get(inviteRef);
      if (!inviteSnap.exists) {
        throw new HttpsError('not-found', 'Invite not found.');
      }
      const invite = inviteSnap.data() as TeamInviteDoc;
      if (invite.status !== 'pending') {
        throw new HttpsError('failed-precondition', 'This invite is no longer available.');
      }

      const teamRef = db.collection(TEAMS_COLLECTION).doc(invite.teamId);
      const teamSnap = await tx.get(teamRef);
      if (!teamSnap.exists) {
        throw new HttpsError('not-found', 'Team not found.');
      }
      const team = teamSnap.data() as TeamDoc;

      const userRef = db.collection(USERS_COLLECTION).doc(uid);
      const userSnap = await tx.get(userRef);

      const rosterRef = teamRef.collection(TEAM_ROSTER_SUBCOLLECTION).doc(invite.playerId);
      const rosterSnap = await tx.get(rosterRef);

      if (!userSnap.exists) {
        tx.set(userRef, {
          uid,
          email: authEmail ?? invite.playerEmail,
          displayName: invite.playerName,
          userType: 'user',
          subscriptionStatus: 'free',
          onboardingStep: 0,
          createdAt: now,
          teamId: invite.teamId,
          premiumUntil: team.seasonEndsAt,
        });
      } else {
        // Existing account (e.g. an already-paying user joining a team):
        // attach the team and extend comped access, but never clobber their
        // name, onboarding progress, subscription status, or a premiumUntil
        // that already extends further out than the season end.
        const existing = userSnap.data() ?? {};
        const existingPremiumUntil = existing.premiumUntil as string | undefined;
        const existingMs = existingPremiumUntil ? Date.parse(existingPremiumUntil) : NaN;
        const seasonMs = Date.parse(team.seasonEndsAt);
        const nextPremiumUntil = !Number.isNaN(existingMs) && existingMs > seasonMs
          ? existingPremiumUntil
          : team.seasonEndsAt;

        tx.set(
          userRef,
          { teamId: invite.teamId, premiumUntil: nextPremiumUntil },
          { merge: true },
        );
      }

      // memberUids is what firestore.rules actually checks for team/schedule
      // access — everything else here is bookkeeping for the portal.
      tx.set(teamRef, { memberUids: admin.firestore.FieldValue.arrayUnion(uid) }, { merge: true });

      if (rosterSnap.exists) {
        tx.set(rosterRef, { status: 'active', uid, joinedAt: now }, { merge: true });
      }

      tx.set(inviteRef, { status: 'accepted', acceptedAt: now, acceptedUid: uid }, { merge: true });

      return { teamId: invite.teamId, teamName: team.name };
    });
  },
);

// ─── Prompt bank ────────────────────────────────────────────────────────────

const MIN_TEAM_PROMPTS = 1;
const MAX_TEAM_PROMPTS = 25;
const DEFAULT_TEAM_PROMPTS = 5;
const RECENT_PROMPT_LOOKBACK = 40;

function clampPromptCount(value: unknown): number {
  const num = typeof value === 'number' ? value : NaN;
  if (!Number.isFinite(num)) return DEFAULT_TEAM_PROMPTS;
  return Math.min(MAX_TEAM_PROMPTS, Math.max(MIN_TEAM_PROMPTS, Math.round(num)));
}

/**
 * One Claude call per invocation, guided by the team's `guidance` plus the
 * text of recently created prompts (so the model avoids repeats). JSON
 * parsing failures throw a clean HttpsError instead of crashing — mirrors
 * how blog.ts handles AI JSON.
 */
export const generateTeamPrompts = onCall(
  {
    invoker: 'public',
    secrets: [anthropicKey],
    timeoutSeconds: 120,
    maxInstances: COACH_MAX_INSTANCES,
  },
  async (request) => {
    const data = (request.data ?? {}) as Partial<GenerateTeamPromptsRequest>;
    const teamId = data.teamId;
    if (!teamId || typeof teamId !== 'string') {
      throw new HttpsError('invalid-argument', 'teamId is required.');
    }
    await assertTeamAccess(request.auth?.uid, teamId);

    const count = clampPromptCount(data.count);
    const theme = typeof data.theme === 'string' ? data.theme.trim() : '';

    const teamSnap = await db.collection(TEAMS_COLLECTION).doc(teamId).get();
    const team = teamSnap.data() as TeamDoc;

    const promptsRef = db
      .collection(TEAMS_COLLECTION)
      .doc(teamId)
      .collection(TEAM_PROMPTS_SUBCOLLECTION);
    const recentSnap = await promptsRef
      .orderBy('createdAt', 'desc')
      .limit(RECENT_PROMPT_LOOKBACK)
      .get();
    const recentTexts = recentSnap.docs
      .map((doc) => (doc.data() as TeamPromptDoc).text)
      .filter((t): t is string => typeof t === 'string');

    const userPrompt = buildTeamPromptUserMessage(
      team.guidance,
      team.sport,
      theme,
      count,
      recentTexts,
    );

    let generated: { text: string; theme: string }[];
    try {
      const apiKey = anthropicKey.value().trim();
      const response = await callCoachAnthropic(TEAM_PROMPT_SYSTEM, userPrompt, 1500, apiKey);
      generated = parseGeneratedPrompts(response, count, theme || 'mindset');
    } catch (err) {
      console.error('generateTeamPrompts failed:', sanitizeForLog(err));
      throw new HttpsError('internal', 'Failed to generate prompts. Please try again.');
    }

    if (generated.length === 0) {
      throw new HttpsError('internal', 'Failed to generate prompts. Please try again.');
    }

    const now = new Date().toISOString();
    const batch = db.batch();
    const prompts: GeneratedTeamPrompt[] = generated.map((item) => {
      const ref = promptsRef.doc();
      const doc: TeamPromptDoc = {
        promptId: ref.id,
        text: item.text,
        theme: item.theme,
        source: 'ai',
        usedDates: [],
        createdAt: now,
      };
      batch.set(ref, doc);
      return { promptId: ref.id, text: item.text, theme: item.theme };
    });
    await batch.commit();

    return { prompts };
  },
);

const MAX_MANUAL_PROMPT_LENGTH = 500;

export const addManualPrompt = onCall(
  { invoker: 'public', maxInstances: COACH_MAX_INSTANCES },
  async (request) => {
  const data = (request.data ?? {}) as Partial<AddManualPromptRequest>;
  const teamId = data.teamId;
  if (!teamId || typeof teamId !== 'string') {
    throw new HttpsError('invalid-argument', 'teamId is required.');
  }
  await assertTeamAccess(request.auth?.uid, teamId);

  const text = typeof data.text === 'string' ? data.text.trim() : '';
  if (!text || text.length > MAX_MANUAL_PROMPT_LENGTH) {
    throw new HttpsError(
      'invalid-argument',
      `text is required and must be under ${MAX_MANUAL_PROMPT_LENGTH} characters.`,
    );
  }
  const theme = typeof data.theme === 'string' ? data.theme.trim() : '';

  const now = new Date().toISOString();
  const ref = db
    .collection(TEAMS_COLLECTION)
    .doc(teamId)
    .collection(TEAM_PROMPTS_SUBCOLLECTION)
    .doc();
  const doc: TeamPromptDoc = {
    promptId: ref.id,
    text,
    theme,
    source: 'manual',
    usedDates: [],
    createdAt: now,
  };
  await ref.set(doc);

  const response: AddManualPromptResponse = { promptId: ref.id };
  return response;
});

export const deletePrompt = onCall(
  { invoker: 'public', maxInstances: COACH_MAX_INSTANCES },
  async (request) => {
  const data = (request.data ?? {}) as Partial<DeletePromptRequest>;
  const teamId = data.teamId;
  if (!teamId || typeof teamId !== 'string') {
    throw new HttpsError('invalid-argument', 'teamId is required.');
  }
  await assertTeamAccess(request.auth?.uid, teamId);

  const promptId = data.promptId;
  if (!promptId || typeof promptId !== 'string') {
    throw new HttpsError('invalid-argument', 'promptId is required.');
  }

  await db
    .collection(TEAMS_COLLECTION)
    .doc(teamId)
    .collection(TEAM_PROMPTS_SUBCOLLECTION)
    .doc(promptId)
    .delete();

  return { ok: true };
});

// ─── Schedule ───────────────────────────────────────────────────────────────

/**
 * Writes `teams/{teamId}/schedule/{date}` with exactly the frozen field
 * contract. `promptText` is denormalized here (not read at request time by
 * the app) so the Flutter app needs only one document read per day.
 */
export const assignTeamPrompt = onCall(
  { invoker: 'public', maxInstances: COACH_MAX_INSTANCES },
  async (request) => {
  const data = (request.data ?? {}) as Partial<AssignTeamPromptRequest>;
  const teamId = data.teamId;
  if (!teamId || typeof teamId !== 'string') {
    throw new HttpsError('invalid-argument', 'teamId is required.');
  }
  const uid = request.auth?.uid;
  await assertTeamAccess(uid, teamId);
  // assertTeamAccess already threw 'unauthenticated' above if uid was missing.
  const assignedBy = uid as string;

  const date = data.date;
  if (!date || typeof date !== 'string' || !isValidDateString(date)) {
    throw new HttpsError('invalid-argument', "date must be a valid 'YYYY-MM-DD' string.");
  }
  const promptId = data.promptId;
  if (!promptId || typeof promptId !== 'string') {
    throw new HttpsError('invalid-argument', 'promptId is required.');
  }

  const promptRef = db
    .collection(TEAMS_COLLECTION)
    .doc(teamId)
    .collection(TEAM_PROMPTS_SUBCOLLECTION)
    .doc(promptId);
  const promptSnap = await promptRef.get();
  if (!promptSnap.exists) {
    throw new HttpsError('not-found', 'Prompt not found in the bank.');
  }
  const prompt = promptSnap.data() as TeamPromptDoc;

  const scheduleDoc: TeamScheduleDoc = {
    date,
    promptId,
    promptText: prompt.text,
    assignedBy,
    assignedAt: new Date().toISOString(),
  };

  const batch = db.batch();
  batch.set(
    db.collection(TEAMS_COLLECTION).doc(teamId).collection(TEAM_SCHEDULE_SUBCOLLECTION).doc(date),
    scheduleDoc,
  );
  batch.set(promptRef, { usedDates: admin.firestore.FieldValue.arrayUnion(date) }, { merge: true });
  await batch.commit();

  return { ok: true };
});

export const unassignTeamPrompt = onCall(
  { invoker: 'public', maxInstances: COACH_MAX_INSTANCES },
  async (request) => {
  const data = (request.data ?? {}) as Partial<UnassignTeamPromptRequest>;
  const teamId = data.teamId;
  if (!teamId || typeof teamId !== 'string') {
    throw new HttpsError('invalid-argument', 'teamId is required.');
  }
  await assertTeamAccess(request.auth?.uid, teamId);

  const date = data.date;
  if (!date || typeof date !== 'string' || !isValidDateString(date)) {
    throw new HttpsError('invalid-argument', "date must be a valid 'YYYY-MM-DD' string.");
  }

  const scheduleRef = db
    .collection(TEAMS_COLLECTION)
    .doc(teamId)
    .collection(TEAM_SCHEDULE_SUBCOLLECTION)
    .doc(date);
  const scheduleSnap = await scheduleRef.get();
  if (scheduleSnap.exists) {
    const schedule = scheduleSnap.data() as TeamScheduleDoc;
    const batch = db.batch();
    batch.delete(scheduleRef);
    batch.set(
      db
        .collection(TEAMS_COLLECTION)
        .doc(teamId)
        .collection(TEAM_PROMPTS_SUBCOLLECTION)
        .doc(schedule.promptId),
      { usedDates: admin.firestore.FieldValue.arrayRemove(date) },
      { merge: true },
    );
    await batch.commit();
  }

  return { ok: true };
});

// ─── Roster management ──────────────────────────────────────────────────────

/**
 * Removes a player's access without touching their journals or account.
 * Pulling their uid from `memberUids` is the critical part — that's the
 * field firestore.rules checks for team/schedule reads, so leaving it in
 * place would keep granting the removed player access.
 */
export const removePlayer = onCall(
  { invoker: 'public', maxInstances: COACH_MAX_INSTANCES },
  async (request) => {
  const data = (request.data ?? {}) as Partial<RemovePlayerRequest>;
  const teamId = data.teamId;
  if (!teamId || typeof teamId !== 'string') {
    throw new HttpsError('invalid-argument', 'teamId is required.');
  }
  await assertTeamAccess(request.auth?.uid, teamId);

  const playerId = data.playerId;
  if (!playerId || typeof playerId !== 'string') {
    throw new HttpsError('invalid-argument', 'playerId is required.');
  }

  const rosterRef = db
    .collection(TEAMS_COLLECTION)
    .doc(teamId)
    .collection(TEAM_ROSTER_SUBCOLLECTION)
    .doc(playerId);
  const rosterSnap = await rosterRef.get();
  if (!rosterSnap.exists) {
    throw new HttpsError('not-found', 'Player not found on this roster.');
  }
  const roster = rosterSnap.data() as TeamRosterDoc;

  const batch = db.batch();
  batch.set(rosterRef, { status: 'removed' }, { merge: true });
  if (roster.uid) {
    batch.set(
      db.collection(TEAMS_COLLECTION).doc(teamId),
      { memberUids: admin.firestore.FieldValue.arrayRemove(roster.uid) },
      { merge: true },
    );
    // Clear the player's teamId too, not just their membership. Leaving it set
    // would keep their app subscribed to a schedule doc the rules now deny, and
    // the client cannot clear it itself: UserProfile.toJson omits teamId when
    // null so that a stale client can never wipe a server-set team.
    // premiumUntil is deliberately left alone — a player who is cut keeps the
    // access the team already paid for until the season ends.
    batch.set(
      db.collection(USERS_COLLECTION).doc(roster.uid),
      { teamId: admin.firestore.FieldValue.delete() },
      { merge: true },
    );
  }
  await batch.commit();

  return { ok: true };
});

// ─── Team settings ──────────────────────────────────────────────────────────

export const updateTeamSettings = onCall(
  { invoker: 'public', maxInstances: COACH_MAX_INSTANCES },
  async (request) => {
  const data = (request.data ?? {}) as Partial<UpdateTeamSettingsRequest>;
  const teamId = data.teamId;
  if (!teamId || typeof teamId !== 'string') {
    throw new HttpsError('invalid-argument', 'teamId is required.');
  }
  await assertTeamAccess(request.auth?.uid, teamId);

  const update: Record<string, unknown> = {};

  if (data.name !== undefined) {
    if (typeof data.name !== 'string' || !data.name.trim()) {
      throw new HttpsError('invalid-argument', 'name must be a non-empty string.');
    }
    update.name = data.name.trim();
  }
  if (data.sport !== undefined) {
    if (typeof data.sport !== 'string' || !data.sport.trim()) {
      throw new HttpsError('invalid-argument', 'sport must be a non-empty string.');
    }
    update.sport = data.sport.trim();
  }
  if (data.seasonEndsAt !== undefined) {
    if (typeof data.seasonEndsAt !== 'string' || Number.isNaN(Date.parse(data.seasonEndsAt))) {
      throw new HttpsError('invalid-argument', 'seasonEndsAt must be a valid date.');
    }
    update.seasonEndsAt = data.seasonEndsAt;
  }
  if (data.guidance !== undefined) {
    const g = data.guidance;
    if (
      !g
      || typeof g.sport !== 'string'
      || typeof g.season !== 'string'
      || !Array.isArray(g.focusAreas)
      || typeof g.tone !== 'string'
      || typeof g.notes !== 'string'
    ) {
      throw new HttpsError('invalid-argument', 'guidance is malformed.');
    }
    const guidance: TeamGuidance = {
      sport: g.sport,
      season: g.season,
      focusAreas: g.focusAreas.filter((f): f is string => typeof f === 'string'),
      tone: g.tone,
      notes: g.notes,
    };
    update.guidance = guidance;
  }

  if (Object.keys(update).length === 0) {
    throw new HttpsError('invalid-argument', 'No fields to update.');
  }

  await db
    .collection(TEAMS_COLLECTION)
    .doc(teamId)
    .set(stripUndefined(update), { merge: true });

  return { ok: true };
});
