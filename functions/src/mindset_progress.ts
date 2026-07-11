/**
 * Mindset item lifecycle: belief/fear graduation and excavation readiness.
 * Pure helpers used by callbackDelivery cron.
 */

export interface MindsetProgressConfig {
  minItemAgeDays: number;
  beliefJournalDistinctDays: number;
  fearJournalDistinctDays: number;
  readinessOvercomeShare: number;
  readinessMinOvercome: number;
  excavationCooldownDays: number;
  readinessMinActiveDaysPastWeek: number;
}

export const MINDSET_PROGRESS_DEFAULTS: MindsetProgressConfig = {
  minItemAgeDays: 14,
  beliefJournalDistinctDays: 2,
  fearJournalDistinctDays: 3,
  readinessOvercomeShare: 0.6,
  readinessMinOvercome: 2,
  excavationCooldownDays: 30,
  readinessMinActiveDaysPastWeek: 3,
};

export interface MindsetItemProgressDoc {
  id: string;
  text: string;
  kind: 'belief' | 'fear';
  status: 'active' | 'softening' | 'overcome';
  addedAt: string;
  softeningSince?: string;
  overcameAt?: string;
  journalSignalDays: number;
  lastJournalSignalDate?: string;
  coachCorroborated: boolean;
  generation: number;
}

export interface JournalSummaryDoc {
  date?: string;
  limitingBeliefsShifted?: string[];
  fearsOutwitted?: string[];
}

export interface BeliefPatternDoc {
  belief?: string;
  reframe?: string;
  identifiedAt?: string;
}

export interface CompletionDoc {
  date?: string;
  affirmationsMorning?: boolean;
  affirmationsEvening?: boolean;
  futureSelfCompleted?: boolean;
  journalCompleted?: boolean;
  habitsCompleted?: boolean;
}

export interface MindsetProgressProfile {
  limitingBeliefs?: string[];
  fearsDrift?: string[];
  beliefProgress?: MindsetItemProgressDoc[];
  fearProgress?: MindsetItemProgressDoc[];
  beliefPatternHistory?: BeliefPatternDoc[];
  recentJournalSummaries?: JournalSummaryDoc[];
  dailyCompletions?: CompletionDoc[];
  blueprintCompleted?: boolean;
  blueprintCalibrationStartedAt?: string;
  createdAt?: string;
  lastExcavationAt?: string;
  blueprintEvolutionReady?: boolean;
  timezone?: string;
}

export interface MindsetProgressResult {
  beliefProgress: MindsetItemProgressDoc[];
  fearProgress: MindsetItemProgressDoc[];
  limitingBeliefs: string[];
  fearsDrift: string[];
  blueprintEvolutionReady: boolean;
  newlyReady: boolean;
  graduatedItems: string[];
}

export function looselyMatchesText(a: string, b: string): boolean {
  const na = a.trim().toLowerCase();
  const nb = b.trim().toLowerCase();
  if (!na || !nb) return false;
  return na === nb || na.includes(nb) || nb.includes(na);
}

export function daysSinceIso(iso?: string, nowMs = Date.now()): number {
  if (!iso) return 0;
  const parsed = Date.parse(iso);
  if (isNaN(parsed)) return 0;
  return Math.floor((nowMs - parsed) / 86400000);
}

function defaultAddedAt(profile: MindsetProgressProfile): string {
  return profile.blueprintCalibrationStartedAt
    ?? profile.createdAt
    ?? new Date().toISOString();
}

function findProgressRecord(
  records: MindsetItemProgressDoc[],
  text: string,
  kind: 'belief' | 'fear',
): MindsetItemProgressDoc | undefined {
  return records.find(
    (r) => r.kind === kind && looselyMatchesText(r.text, text),
  );
}

function countJournalSignals(
  text: string,
  summaries: JournalSummaryDoc[],
  field: 'limitingBeliefsShifted' | 'fearsOutwitted',
): { days: number; lastDate?: string } {
  const dates = new Set<string>();
  let lastDate: string | undefined;
  for (const j of summaries) {
    const tags = j[field] ?? [];
    if (!tags.some((t) => looselyMatchesText(t, text))) continue;
    if (j.date) {
      dates.add(j.date);
      if (!lastDate || j.date > lastDate) lastDate = j.date;
    }
  }
  return { days: dates.size, lastDate };
}

function hasCoachCorroboration(
  text: string,
  patterns: BeliefPatternDoc[],
): boolean {
  return patterns.some((p) => p.belief && looselyMatchesText(p.belief, text));
}

function hasRecentRegression(
  completions: CompletionDoc[],
  tz?: string,
  nowMs = Date.now(),
): boolean {
  let gapDays = 0;
  for (let i = 1; i <= 4; i++) {
    const key = localDateKeyInTz(new Date(nowMs - i * 86400000), tz);
    const c = completions.find((d) => d.date === key);
    const active = c && (
      c.affirmationsMorning ||
      c.affirmationsEvening ||
      c.futureSelfCompleted ||
      c.journalCompleted ||
      c.habitsCompleted
    );
    if (!active) gapDays++;
    else break;
  }
  return gapDays >= 2;
}

function localDateKeyInTz(d: Date, tz?: string): string {
  try {
    const fmt = new Intl.DateTimeFormat('en-CA', {
      timeZone: tz || 'UTC',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    });
    return fmt.format(d);
  } catch {
    return d.toISOString().slice(0, 10);
  }
}

function countActiveDaysPastWeek(
  completions: CompletionDoc[],
  tz?: string,
  nowMs = Date.now(),
): number {
  let active = 0;
  for (let i = 0; i < 7; i++) {
    const key = localDateKeyInTz(new Date(nowMs - i * 86400000), tz);
    const c = completions.find((d) => d.date === key);
    if (
      c &&
      (c.affirmationsMorning ||
        c.affirmationsEvening ||
        c.futureSelfCompleted ||
        c.journalCompleted ||
        c.habitsCompleted)
    ) {
      active++;
    }
  }
  return active;
}

function backfillProgress(
  activeTexts: string[],
  existing: MindsetItemProgressDoc[],
  kind: 'belief' | 'fear',
  addedAt: string,
): MindsetItemProgressDoc[] {
  const records = [...existing];
  for (const text of activeTexts) {
    if (!findProgressRecord(records, text, kind)) {
      records.push({
        id: `${kind}_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`,
        text,
        kind,
        status: 'active',
        addedAt,
        journalSignalDays: 0,
        coachCorroborated: false,
        generation: 1,
      });
    }
  }
  return records;
}

function promoteItem(
  item: MindsetItemProgressDoc,
  config: MindsetProgressConfig,
  journalDays: number,
  lastJournalDate: string | undefined,
  coachCorroborated: boolean,
  hasRegression: boolean,
  nowIso: string,
  nowMs: number,
): MindsetItemProgressDoc {
  let updated: MindsetItemProgressDoc = {
    ...item,
    journalSignalDays: journalDays,
    lastJournalSignalDate: lastJournalDate,
    coachCorroborated: item.kind === 'belief'
      ? coachCorroborated || item.coachCorroborated
      : item.coachCorroborated,
  };

  const hasJournalSignal = journalDays > 0;
  const hasCoachSignal = updated.coachCorroborated;

  if (updated.status === 'active' && (hasJournalSignal || hasCoachSignal)) {
    updated = {
      ...updated,
      status: 'softening',
      softeningSince: updated.softeningSince ?? nowIso,
    };
  }

  const ageDays = daysSinceIso(updated.addedAt, nowMs);
  if (updated.status !== 'overcome' && ageDays >= config.minItemAgeDays) {
    let canOvercome = false;
    if (updated.kind === 'belief') {
      canOvercome =
        updated.journalSignalDays >= config.beliefJournalDistinctDays &&
        updated.coachCorroborated &&
        !hasRegression;
    } else {
      canOvercome =
        updated.journalSignalDays >= config.fearJournalDistinctDays &&
        !hasRegression;
    }
    if (canOvercome) {
      updated = {
        ...updated,
        status: 'overcome',
        overcameAt: nowIso,
      };
    }
  }

  return updated;
}

function computeReadiness(
  beliefProgress: MindsetItemProgressDoc[],
  fearProgress: MindsetItemProgressDoc[],
  profile: MindsetProgressProfile,
  config: MindsetProgressConfig,
  nowMs: number,
): boolean {
  if (!profile.blueprintCompleted) return false;
  if (
    daysSinceIso(profile.lastExcavationAt, nowMs) <
    config.excavationCooldownDays
  ) {
    return false;
  }
  const activeDays = countActiveDaysPastWeek(
    profile.dailyCompletions ?? [],
    profile.timezone,
    nowMs,
  );
  if (activeDays < config.readinessMinActiveDaysPastWeek) return false;

  const all = [...beliefProgress, ...fearProgress];
  if (all.length === 0) return false;
  const overcome = all.filter((i) => i.status === 'overcome').length;
  if (overcome < config.readinessMinOvercome) return false;
  return overcome / all.length >= config.readinessOvercomeShare;
}

export function evaluateMindsetProgress(
  profile: MindsetProgressProfile,
  config: MindsetProgressConfig,
  nowMs = Date.now(),
): MindsetProgressResult {
  const nowIso = new Date(nowMs).toISOString();
  const addedAtDefault = defaultAddedAt(profile);
  const wasReady = profile.blueprintEvolutionReady === true;

  let beliefProgress = backfillProgress(
    profile.limitingBeliefs ?? [],
    profile.beliefProgress ?? [],
    'belief',
    addedAtDefault,
  );
  let fearProgress = backfillProgress(
    profile.fearsDrift ?? [],
    profile.fearProgress ?? [],
    'fear',
    addedAtDefault,
  );

  const summaries = profile.recentJournalSummaries ?? [];
  const patterns = profile.beliefPatternHistory ?? [];
  const hasRegression = hasRecentRegression(
    profile.dailyCompletions ?? [],
    profile.timezone,
    nowMs,
  );
  const graduatedItems: string[] = [];

  beliefProgress = beliefProgress.map((item) => {
    if (item.status === 'overcome') return item;
    const active = (profile.limitingBeliefs ?? []).some(
      (b) => looselyMatchesText(b, item.text),
    );
    if (!active) return item;

    const signals = countJournalSignals(
      item.text,
      summaries,
      'limitingBeliefsShifted',
    );
    const coachHit = hasCoachCorroboration(item.text, patterns);
    const promoted = promoteItem(
      item,
      config,
      signals.days,
      signals.lastDate,
      coachHit,
      hasRegression,
      nowIso,
      nowMs,
    );
    if (promoted.status === 'overcome') {
      graduatedItems.push(promoted.text);
    }
    return promoted;
  });

  fearProgress = fearProgress.map((item) => {
    if (item.status === 'overcome') return item;
    const active = (profile.fearsDrift ?? []).some(
      (f) => looselyMatchesText(f, item.text),
    );
    if (!active) return item;

    const signals = countJournalSignals(item.text, summaries, 'fearsOutwitted');
    const promoted = promoteItem(
      item,
      config,
      signals.days,
      signals.lastDate,
      false,
      hasRegression,
      nowIso,
      nowMs,
    );
    if (promoted.status === 'overcome') {
      graduatedItems.push(promoted.text);
    }
    return promoted;
  });

  let limitingBeliefs = [...(profile.limitingBeliefs ?? [])];
  let fearsDrift = [...(profile.fearsDrift ?? [])];

  for (const text of graduatedItems) {
    limitingBeliefs = limitingBeliefs.filter(
      (b) => !looselyMatchesText(b, text),
    );
    fearsDrift = fearsDrift.filter((f) => !looselyMatchesText(f, text));
  }

  const ready = computeReadiness(
    beliefProgress,
    fearProgress,
    profile,
    config,
    nowMs,
  );

  return {
    beliefProgress,
    fearProgress,
    limitingBeliefs,
    fearsDrift,
    blueprintEvolutionReady: ready || wasReady,
    newlyReady: ready && !wasReady,
    graduatedItems,
  };
}
