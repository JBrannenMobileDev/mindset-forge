"use client";

import Link from "next/link";
import { Suspense, useEffect, useMemo, useState } from "react";
import { useSearchParams } from "next/navigation";
import {
  collection,
  limit,
  onSnapshot,
  orderBy,
  query,
  where,
} from "firebase/firestore";
import { AuthGate } from "@/components/AuthGate";
import { MoodTrendChart } from "@/components/MoodTrendChart";
import { ThemeChips } from "@/components/ThemeChips";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { EmptyState } from "@/components/ui/EmptyState";
import { Spinner } from "@/components/ui/Spinner";
import { useAuth } from "@/lib/auth-context";
import { formatDayKey, pastDayKeys, todayDayKey } from "@/lib/date-utils";
import { db } from "@/lib/firebase";
import {
  aggregateThemes,
  averageMoodByDay,
  countEntryDaysInRange,
  filterEntriesInRange,
  participationRate,
} from "@/lib/summary-utils";
import type { RosterStatus, TeamEntrySummaryDoc, TeamRosterDoc } from "@/lib/types";

const SUMMARY_FETCH_LIMIT = 200;
const MOOD_CHART_DAYS = 30;
const PARTICIPATION_DAYS = 30;

const STATUS_STYLES: Record<RosterStatus, string> = {
  invited: "border-warning/30 bg-warning/10 text-warning",
  active: "border-success/30 bg-success/10 text-success",
  removed: "border-border bg-surface-highest text-text-muted",
};

function StatusBadge({ status }: { status: RosterStatus }) {
  return (
    <span
      className={`inline-flex items-center rounded-full border px-2.5 py-1 text-xs font-semibold capitalize ${STATUS_STYLES[status]}`}
    >
      {status}
    </span>
  );
}

function PlayersPageContent() {
  const searchParams = useSearchParams();
  const playerUid = searchParams.get("uid")?.trim() ?? null;

  const { activeTeamId, teams } = useAuth();
  const activeTeam = teams.find((t) => t.teamId === activeTeamId) ?? null;
  const today = todayDayKey();

  const [roster, setRoster] = useState<TeamRosterDoc[]>([]);
  const [rosterLoading, setRosterLoading] = useState(true);
  const [rosterError, setRosterError] = useState<string | null>(null);

  const [summaries, setSummaries] = useState<TeamEntrySummaryDoc[]>([]);
  const [summariesLoading, setSummariesLoading] = useState(true);
  const [summariesError, setSummariesError] = useState<string | null>(null);

  useEffect(() => {
    if (!activeTeamId) {
      setRoster([]);
      setRosterLoading(false);
      return;
    }
    setRosterLoading(true);
    setRosterError(null);
    const rosterQuery = query(collection(db, "teams", activeTeamId, "roster"), orderBy("name"));
    const unsub = onSnapshot(
      rosterQuery,
      (snap) => {
        setRoster(snap.docs.map((d) => d.data() as TeamRosterDoc));
        setRosterLoading(false);
      },
      () => {
        setRosterError("Failed to load the roster. Please refresh the page.");
        setRosterLoading(false);
      },
    );
    return unsub;
  }, [activeTeamId]);

  useEffect(() => {
    if (!activeTeamId || !playerUid) {
      setSummaries([]);
      setSummariesLoading(false);
      return;
    }
    setSummariesLoading(true);
    setSummariesError(null);
    const summariesQuery = query(
      collection(db, "team_entry_summaries"),
      where("teamId", "==", activeTeamId),
      where("playerUid", "==", playerUid),
      orderBy("date", "desc"),
      limit(SUMMARY_FETCH_LIMIT),
    );
    const unsub = onSnapshot(
      summariesQuery,
      (snap) => {
        setSummaries(snap.docs.map((d) => d.data() as TeamEntrySummaryDoc));
        setSummariesLoading(false);
      },
      (err) => {
        console.error("Player summaries query failed:", err);
        setSummariesError("Failed to load this player's entries. Please try again.");
        setSummariesLoading(false);
      },
    );
    return unsub;
  }, [activeTeamId, playerUid]);

  const player = useMemo(
    () => (playerUid ? roster.find((r) => r.uid === playerUid) ?? null : null),
    [roster, playerUid],
  );

  const participationStart = pastDayKeys(PARTICIPATION_DAYS)[0] ?? today;
  const moodDayKeys = useMemo(() => {
    const keys = pastDayKeys(MOOD_CHART_DAYS);
    if (summaries.length === 0) return keys;
    const earliest = summaries[summaries.length - 1]?.date;
    if (!earliest) return keys;
    return keys.filter((key) => key >= earliest);
  }, [summaries]);

  const entriesInParticipationWindow = useMemo(
    () => filterEntriesInRange(summaries, participationStart, today),
    [summaries, participationStart, today],
  );

  const daysWithEntries = useMemo(
    () => countEntryDaysInRange(entriesInParticipationWindow, participationStart, today),
    [entriesInParticipationWindow, participationStart, today],
  );

  const moodPoints = useMemo(
    () => averageMoodByDay(summaries, moodDayKeys),
    [summaries, moodDayKeys],
  );

  const playerThemes = useMemo(() => aggregateThemes(summaries, 12), [summaries]);

  const loading = rosterLoading || (playerUid ? summariesLoading : false);

  if (!activeTeamId) {
    return (
      <EmptyState
        title="No team selected"
        subtitle="Choose or set up a team to view a player timeline."
      />
    );
  }

  if (!playerUid) {
    return (
      <EmptyState
        title="No player selected"
        subtitle="Open a player from the roster or dashboard to see their timeline."
        action={
          <Button href="/roster" variant="secondary">
            Go to roster
          </Button>
        }
      />
    );
  }

  if (!loading && !player) {
    return (
      <EmptyState
        title="Player not found"
        subtitle="This player isn't on your roster, or the link may be outdated."
        action={
          <Button href="/roster" variant="secondary">
            Back to roster
          </Button>
        }
      />
    );
  }

  const displayName = player?.name ?? summaries[0]?.playerName ?? "Player";

  return (
    <div>
      <div>
        <p className="text-xs font-semibold uppercase tracking-[0.2em] text-primary">Player</p>
        <h1 className="mt-2 font-display text-3xl font-bold text-text-primary">{displayName}</h1>
        <p className="mt-2 text-sm text-text-secondary">
          {activeTeam?.name ?? "Your team"} · entry summaries only
        </p>
      </div>

      {(rosterError || summariesError) && (
        <div className="mt-6 space-y-2">
          {rosterError && (
            <div className="rounded-xl border border-error/30 bg-error/10 px-4 py-3 text-sm text-error">
              {rosterError}
            </div>
          )}
          {summariesError && (
            <div className="rounded-xl border border-error/30 bg-error/10 px-4 py-3 text-sm text-error">
              {summariesError}
            </div>
          )}
        </div>
      )}

      {loading ? (
        <div className="flex justify-center py-16">
          <Spinner size={32} className="text-primary" />
        </div>
      ) : (
        <>
          <Card className="mt-8">
            <div className="flex flex-wrap items-start justify-between gap-4">
              <div>
                {player && (
                  <>
                    <p className="text-sm text-text-muted">{player.email}</p>
                    <div className="mt-2">
                      <StatusBadge status={player.status} />
                    </div>
                  </>
                )}
              </div>
              <div className="grid gap-4 text-right sm:grid-cols-3 sm:gap-8">
                <div>
                  <p className="text-xs text-text-muted">Last entry</p>
                  <p className="mt-1 text-sm font-semibold text-text-primary">
                    {formatDayKey(player?.lastEntryAt ?? summaries[0]?.date ?? null, "None yet")}
                  </p>
                </div>
                <div>
                  <p className="text-xs text-text-muted">Total entries</p>
                  <p className="mt-1 text-sm font-semibold text-text-primary">{summaries.length}</p>
                </div>
                <div>
                  <p className="text-xs text-text-muted">{PARTICIPATION_DAYS}-day participation</p>
                  <p className="mt-1 text-sm font-semibold text-text-primary">
                    {participationRate(daysWithEntries, PARTICIPATION_DAYS)}%
                  </p>
                  <p className="text-xs text-text-muted">
                    {daysWithEntries} of {PARTICIPATION_DAYS} days
                  </p>
                </div>
              </div>
            </div>
          </Card>

          <Card className="mt-6 border-border-subtle bg-surface-elevated">
            <p className="text-sm text-text-secondary">
              You are viewing AI-generated summaries and themes only. The player&apos;s actual
              journal text is private and is never shown in the coach portal.
            </p>
          </Card>

          <Card className="mt-6">
            <h2 className="font-display text-lg font-semibold text-text-primary">Mood over time</h2>
            <div className="mt-4">
              <MoodTrendChart points={moodPoints} />
            </div>
          </Card>

          <Card className="mt-6">
            <h2 className="font-display text-lg font-semibold text-text-primary">Themes</h2>
            <p className="mt-1 text-sm text-text-secondary">
              Topics that appear most often in this player&apos;s summaries.
            </p>
            <ThemeChips themes={playerThemes} className="mt-4" />
          </Card>

          <Card className="mt-6">
            <h2 className="font-display text-lg font-semibold text-text-primary">Entry timeline</h2>
            {summaries.length === 0 ? (
              <EmptyState
                className="mt-4"
                title="No entries yet"
                subtitle="When this player writes in the app, summaries will appear here."
              />
            ) : (
              <ul className="mt-4 space-y-3">
                {summaries.map((entry) => (
                  <li
                    key={entry.entryId}
                    className="rounded-xl border border-border-subtle px-4 py-4"
                  >
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <span className="text-sm font-semibold text-text-primary">
                        {formatDayKey(entry.date)}
                      </span>
                      <div className="flex flex-wrap gap-2 text-xs">
                        <span className="rounded-full border border-border bg-surface-elevated px-2.5 py-1 capitalize text-text-secondary">
                          {entry.mood}
                        </span>
                        <span className="rounded-full border border-border bg-surface-elevated px-2.5 py-1 text-text-muted">
                          {entry.mode}
                        </span>
                        {entry.isTeamPrompt ? (
                          <span className="rounded-full border border-primary/30 bg-primary-container px-2.5 py-1 text-primary">
                            Team prompt
                          </span>
                        ) : (
                          <span className="rounded-full border border-border bg-surface-elevated px-2.5 py-1 text-text-muted">
                            Off prompt
                          </span>
                        )}
                        <span className="rounded-full border border-border bg-surface-elevated px-2.5 py-1 text-text-muted">
                          {entry.wordCount} words
                        </span>
                      </div>
                    </div>
                    <p className="mt-3 text-sm text-text-primary">{entry.summary}</p>
                  </li>
                ))}
              </ul>
            )}
          </Card>

          <div className="mt-6">
            <Link href="/roster" className="text-sm font-semibold text-primary hover:underline">
              Back to roster
            </Link>
          </div>
        </>
      )}
    </div>
  );
}

function PlayersPageInner() {
  return (
    <AuthGate>
      <PlayersPageContent />
    </AuthGate>
  );
}

export default function PlayersPage() {
  return (
    <Suspense
      fallback={
        <main className="flex min-h-screen items-center justify-center bg-background text-text-secondary">
          Loading…
        </main>
      }
    >
      <PlayersPageInner />
    </Suspense>
  );
}
