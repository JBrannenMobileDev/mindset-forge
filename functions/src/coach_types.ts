/**
 * Shared document and callable contracts for the coach team portal.
 *
 * This file is the single source of truth for every shape crossing a boundary
 * (Firestore docs, callable payloads, the Flutter app's read of the daily
 * prompt). It intentionally has no imports so both the functions build and any
 * script can pull from it.
 *
 * Conventions, matching the existing app models:
 * - every timestamp is an ISO-8601 string, never a Firestore Timestamp
 * - every calendar date is a 'YYYY-MM-DD' string in the team's local day
 */

// ---------------------------------------------------------------------------
// Collections and constants
// ---------------------------------------------------------------------------

export const TEAMS_COLLECTION = 'teams';
export const TEAM_PROMPTS_SUBCOLLECTION = 'prompts';
export const TEAM_SCHEDULE_SUBCOLLECTION = 'schedule';
export const TEAM_ROSTER_SUBCOLLECTION = 'roster';
export const TEAM_REPORTS_SUBCOLLECTION = 'reports';
export const TEAM_INVITES_COLLECTION = 'team_invites';
export const TEAM_ENTRY_SUMMARIES_COLLECTION = 'team_entry_summaries';
/**
 * Analyst-only concern signals. Coaches can read `team_entry_summaries` but
 * must never be able to read this collection, including via browser DevTools.
 */
export const TEAM_ENTRY_SIGNALS_COLLECTION = 'team_entry_signals';
export const USERS_COLLECTION = 'users';
export const JOURNALS_COLLECTION = 'journals';

/** Holds `analystUids` and `coachSignupCodes`. Server-only, denied in rules. */
export const ROLES_CONFIG_DOC_PATH = 'app_config/roles';

export const COACH_PORTAL_DOMAIN = 'https://coach.mindsetforge.app';

/** Canonical player invite link. */
export function teamInviteLink(inviteId: string): string {
  return `${COACH_PORTAL_DOMAIN}/join/${inviteId}`;
}

// ---------------------------------------------------------------------------
// Enumerations
// ---------------------------------------------------------------------------

export type PromptSource = 'ai' | 'manual';

export type RosterStatus = 'invited' | 'active' | 'removed';

export type InviteStatus = 'pending' | 'accepted' | 'revoked';

export type Sentiment = 'positive' | 'neutral' | 'negative';

/** `flag` is the only level the portal surfaces as an alert. */
export type ConcernLevel = 'none' | 'watch' | 'flag';

/** `analyst` is a super-admin with coach-level read access to every team. */
export type CoachRole = 'coach' | 'analyst';

// ---------------------------------------------------------------------------
// Firestore documents
// ---------------------------------------------------------------------------

/** Steers prompt generation. Every field is coach-authored free text. */
export type TeamGuidance = {
  sport: string;
  season: string;
  focusAreas: string[];
  tone: string;
  notes: string;
};

/** `teams/{teamId}` */
export type TeamDoc = {
  teamId: string;
  name: string;
  sport: string;
  coachUid: string;
  /** Uids of active players. Drives `isTeamMember` in firestore.rules. */
  memberUids: string[];
  /** Players are comped premium until this date, so it must be in the future. */
  seasonEndsAt: string;
  guidance: TeamGuidance;
  createdAt: string;
};

/** `teams/{teamId}/prompts/{promptId}` */
export type TeamPromptDoc = {
  promptId: string;
  text: string;
  theme: string;
  source: PromptSource;
  /** Dates this prompt has been assigned to, so generation can dedupe. */
  usedDates: string[];
  createdAt: string;
};

/**
 * `teams/{teamId}/schedule/{YYYY-MM-DD}`
 *
 * Read by the Flutter app as well as the portal. `promptText` is denormalized
 * so the app never has to read the prompt bank, which coach rules keep private.
 */
export type TeamScheduleDoc = {
  date: string;
  promptId: string;
  promptText: string;
  assignedBy: string;
  assignedAt: string;
};

/** `teams/{teamId}/roster/{playerId}` */
export type TeamRosterDoc = {
  playerId: string;
  name: string;
  email: string;
  inviteId: string;
  status: RosterStatus;
  /** Set once the invite is accepted. */
  uid: string | null;
  joinedAt: string | null;
  /** Last journal entry date, for the participation column. */
  lastEntryAt: string | null;
  createdAt: string;
};

/** `teams/{teamId}/reports/{period}`, where period looks like '2026-W32'. */
export type TeamReportDoc = {
  period: string;
  teamId: string;
  periodStart: string;
  periodEnd: string;
  entryCount: number;
  activePlayerCount: number;
  /** Entries written divided by entries possible, 0..1. */
  participationRate: number;
  averageMoodScore: number;
  summary: string;
  themes: string[];
  wins: string[];
  concerns: string[];
  watchList: TeamReportWatchItem[];
  generatedAt: string;
  generatedByModel: string;
};

export type TeamReportWatchItem = {
  playerUid: string;
  playerName: string;
  concernLevel: ConcernLevel;
  /** Aggregate note only. Never a quote from an entry. */
  note: string;
};

/**
 * `team_invites/{inviteId}` — denied to clients, mirroring `partner_invites`.
 * Fields are denormalized so the public join page needs one document read.
 */
export type TeamInviteDoc = {
  inviteId: string;
  teamId: string;
  teamName: string;
  coachUid: string;
  coachName: string;
  playerId: string;
  playerName: string;
  playerEmail: string;
  status: InviteStatus;
  createdAt: string;
  acceptedAt: string | null;
  acceptedUid: string | null;
};

/**
 * `team_entry_summaries/{entryId}` — written by the journal trigger, read by
 * the portal.
 *
 * PRIVACY BOUNDARY: this document must never carry raw journal text. No
 * `content` field, no verbatim quotes inside `summary` or `themes`. It is the
 * only view a coach has of an entry, and `journals` itself stays owner-only.
 */
export type TeamEntrySummaryDoc = {
  entryId: string;
  teamId: string;
  playerUid: string;
  playerName: string;
  date: string;
  /** Mood label from the entry, e.g. 'Motivated'. */
  mood: string;
  /** Numeric mapping of `mood`, for charting. */
  moodScore: number;
  /** Journal mode the player wrote in, e.g. 'gratitude'. */
  mode: string;
  /** The team prompt used, or null when the player wrote off-prompt. */
  promptId: string | null;
  isTeamPrompt: boolean;
  wordCount: number;
  /** AI paraphrase. Coach-safe by construction, never verbatim. */
  summary: string;
  themes: string[];
  sentiment: Sentiment;
  generatedAt: string;
};

/**
 * `team_entry_signals/{entryId}` — analyst only.
 *
 * Holds `concernLevel` separately from the coach-readable summary so a coach
 * cannot discover the flag via a direct Firestore read. Written by the same
 * journal trigger that writes the summary.
 */
export type TeamEntrySignalDoc = {
  entryId: string;
  teamId: string;
  playerUid: string;
  date: string;
  concernLevel: ConcernLevel;
  generatedAt: string;
};

// ---------------------------------------------------------------------------
// Callable contracts
//
// Frozen: the portal and the functions are built in parallel against these.
// ---------------------------------------------------------------------------

/** Shared success shape for mutations with nothing to return. */
export type OkResponse = { ok: true };

export type InitializeCoachAccountRequest = {
  /** Validated against `app_config/roles.coachSignupCodes`. */
  accessCode: string;
  coachName: string;
  teamName: string;
  sport: string;
  seasonEndsAt: string;
};

export type InitializeCoachAccountResponse = {
  teamId: string;
};

export type GetCoachContextRequest = Record<string, never>;

export type CoachContextTeam = {
  teamId: string;
  name: string;
  sport: string;
  seasonEndsAt: string;
  playerCount: number;
  activeCount: number;
};

export type GetCoachContextResponse = {
  /** null when the signed-in user is neither a coach nor an analyst. */
  role: CoachRole | null;
  teams: CoachContextTeam[];
};

export type CreatePlayerInvitesRequest = {
  teamId: string;
  players: { name: string; email: string }[];
};

export type CreatedPlayerInvite = {
  playerId: string;
  name: string;
  email: string;
  inviteId: string;
  inviteLink: string;
};

export type CreatePlayerInvitesResponse = {
  invites: CreatedPlayerInvite[];
  /** Duplicate roster emails, including previously removed players. */
  skipped: { name: string; email: string }[];
};

export type GetTeamInviteInfoRequest = {
  inviteId: string;
};

/** Public: called before the player has an account, so keep it minimal. */
export type GetTeamInviteInfoResponse = {
  teamName: string;
  coachName: string;
  playerName: string;
  playerEmail: string;
  status: InviteStatus;
};

export type AcceptTeamInviteRequest = {
  inviteId: string;
};

export type AcceptTeamInviteResponse = {
  teamId: string;
  teamName: string;
};

export type GenerateTeamPromptsRequest = {
  teamId: string;
  count: number;
  theme?: string;
};

export type GeneratedTeamPrompt = {
  promptId: string;
  text: string;
  theme: string;
};

export type GenerateTeamPromptsResponse = {
  prompts: GeneratedTeamPrompt[];
};

export type AddManualPromptRequest = {
  teamId: string;
  text: string;
  theme?: string;
};

export type AddManualPromptResponse = {
  promptId: string;
};

export type DeletePromptRequest = {
  teamId: string;
  promptId: string;
};

export type DeletePromptResponse = OkResponse;

export type AssignTeamPromptRequest = {
  teamId: string;
  date: string;
  promptId: string;
};

export type AssignTeamPromptResponse = OkResponse;

export type UnassignTeamPromptRequest = {
  teamId: string;
  date: string;
};

export type UnassignTeamPromptResponse = OkResponse;

export type RemovePlayerRequest = {
  teamId: string;
  playerId: string;
};

export type RemovePlayerResponse = OkResponse;

export type UpdateTeamSettingsRequest = {
  teamId: string;
  name?: string;
  sport?: string;
  seasonEndsAt?: string;
  guidance?: TeamGuidance;
};

export type UpdateTeamSettingsResponse = OkResponse;

export type GenerateTeamReportRequest = {
  teamId: string;
  period: string;
};

export type GenerateTeamReportResponse = {
  period: string;
};
