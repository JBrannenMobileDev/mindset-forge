"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import {
  collection,
  doc,
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
import {
  dayKeyDiff,
  formatDayKey,
  pastDayKeys,
  todayDayKey,
} from "@/lib/date-utils";
import { db } from "@/lib/firebase";
import {
  aggregateThemes,
  averageMoodByDay,
  countPlayersWithEntriesInRange,
  countUniquePlayersOnDate,
  filterEntriesInRange,
} from "@/lib/summary-utils";
import type { TeamEntrySummaryDoc, TeamRosterDoc, TeamScheduleDoc } from "@/lib/types";

const SUMMARY_FETCH_LIMIT = 300;
const MOOD_TREND_DAYS = 14;
const THEME_LOOKBACK_DAYS = 7;
const PARTICIPATION_LOOKBACK_DAYS = 7;
const INACTIVE_ENTRY_DAYS = 3;
const RECENT_ENTRY_COUNT = 10;

function StatCard({ label, value, detail }: { label: string; value: string; detail?: string }) {
  return (
    <Card>
      <p className="text-sm text-text-secondary">{label}</p>
      <p className="mt-2 font-display text-2xl font-bold text-text-primary">{value}</p>
      {detail && <p className="mt-1 text-xs text-text-muted">{detail}</p>}
    </Card>
  );
}

function DashboardContent() {
  const { activeTeamId, teams } = useAuth();
  const activeTeam = teams.find((t) => t.teamId === activeTeamId) ?? null;
  const today = todayDayKey();

  const [todaySchedule, setTodaySchedule] = useState<TeamScheduleDoc | null>(null);
  const [scheduleLoading, setScheduleLoading] = useState(true);
  const [scheduleError, setScheduleError] = useState<string | null>(null);

  const [roster, setRoster] = useState<TeamRosterDoc[]>([]);
  const [rosterLoading, setRosterLoading] = useState(true);
  const [rosterError, setRosterError] = useState<string | null>(null);

  const [summaries, setSummaries] = useState<TeamEntrySummaryDoc[]>([]);
  const [summariesLoading, setSummariesLoading] = useState(true);
  const [summariesError, setSummariesError] = useState<string | null>(null);

  useEffect(() => {
    if (!activeTeamId) {
      setTodaySchedule(null);
      setScheduleLoading(false);
      return;
    }
    setScheduleLoading(true);
    setScheduleError(null);
    const scheduleRef = doc(db, "teams", activeTeamId, "schedule", today);
    const unsub = onSnapshot(
      scheduleRef,
      (snap) => {
        setTodaySchedule(snap.exists() ? (snap.data() as TeamScheduleDoc) : null);
        setScheduleLoading(false);
      },
      () => {
        setScheduleError("Failed to load today's prompt. Please refresh the page.");
        setScheduleLoading(false);
      },
    );
    return unsub;
  }, [activeTeamId, today]);

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
    if (!activeTeamId) {
      setSummaries([]);
      setSummariesLoading(false);
      return;
    }
    setSummariesLoading(true);
    setSummariesError(null);
    const summariesQuery = query(
      collection(db, "team_entry_summaries"),
      where("teamId", "==", activeTeamId),
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
        console.error("Dashboard summaries query failed:", err);
        setSummariesError(
          "Failed to load entry summaries. If this keeps happening, check that you're viewing the right team.",
        );
        setSummariesLoading(false);
      },
    );
    return unsub;
  }, [activeTeamId]);

  const activePlayers = useMemo(
    () => roster.filter((player) => player.status === "active"),
    [roster],
  );
  const activeCount = activePlayers.length;

  const moodDayKeys = useMemo(() => pastDayKeys(MOOD_TREND_DAYS), []);
  const themeRangeStart = moodDayKeys[0] ?? today;
  const participationRangeStart =
    pastDayKeys(PARTICIPATION_LOOKBACK_DAYS)[0] ?? today;

  const entriesLast7ForThemes = useMemo(
    () => filterEntriesInRange(summaries, themeRangeStart, today),
    [summaries, themeRangeStart, today],
  );

  const moodPoints = useMemo(
    () => averageMoodByDay(summaries, moodDayKeys),
    [summaries, moodDayKeys],
  );

  const topThemes = useMemo(
    () => aggregateThemes(entriesLast7ForThemes, 8),
    [entriesLast7ForThemes],
  );

  const wroteTodayCount = useMemo(
    () => countUniquePlayersOnDate(summaries, today),
    [summaries, today],
  );

  const wroteLast7Count = useMemo(
    () =>
      countPlayersWithEntriesInRange(summaries, participationRangeStart, today),
    [summaries, participationRangeStart, today],
  );

  const inactivePlayers = useMemo(() => {
    return activePlayers
      .filter((player) => {
        if (!player.uid) return false;
        if (!player.lastEntryAt) return true;
        return dayKeyDiff(player.lastEntryAt, today) >= INACTIVE_ENTRY_DAYS;
      })
      .sort((a, b) => {
        if (!a.lastEntryAt && !b.lastEntryAt) return a.name.localeCompare(b.name);
        if (!a.lastEntryAt) return -1;
        if (!b.lastEntryAt) return 1;
        return a.lastEntryAt.localeCompare(b.lastEntryAt);
      });
  }, [activePlayers, today]);

  const recentEntries = useMemo(() => summaries.slice(0, RECENT_ENTRY_COUNT), [summaries]);

  const loading = scheduleLoading || rosterLoading || summariesLoading;

  if (!activeTeamId) {
    return (
      <EmptyState
        title="No team selected"
        subtitle="Choose or set up a team to view its dashboard."
      />
    );
  }

  return (
    <div>
      <div>
        <p className="text-xs font-semibold uppercase tracking-[0.2em] text-primary">Dashboard</p>
        <h1 className="mt-2 font-display text-3xl font-bold text-text-primary">
          {activeTeam?.name ?? "Your team"}
        </h1>
        <p className="mt-2 text-sm text-text-secondary">
          Today&apos;s prompt, participation, and what your team has been writing about.
        </p>
      </div>

      {(scheduleError || rosterError || summariesError) && (
        <div className="mt-6 space-y-2">
          {scheduleError && (
            <div className="rounded-xl border border-error/30 bg-error/10 px-4 py-3 text-sm text-error">
              {scheduleError}
            </div>
          )}
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

      <Card className="mt-8 border-primary/30 shadow-[0_0_36px_rgba(155,64,255,0.12)]">
        <p className="text-xs font-semibold uppercase tracking-[0.15em] text-primary">
          Today&apos;s prompt
        </p>
        {scheduleLoading ? (
          <div className="flex justify-center py-8">
            <Spinner size={28} className="text-primary" />
          </div>
        ) : todaySchedule ? (
          <>
            <p className="mt-3 font-display text-xl font-semibold text-text-primary">
              {todaySchedule.promptText}
            </p>
            <p className="mt-2 text-sm text-text-secondary">
              Assigned for {formatDayKey(todaySchedule.date)}. Players see this in the app
              starting at 4 AM local time.
            </p>
          </>
        ) : (
          <div className="mt-4">
            <p className="font-display text-lg font-semibold text-text-primary">
              No prompt assigned for today
            </p>
            <p className="mt-2 text-sm text-text-secondary">
              Assign a prompt on the schedule so your team has something to respond to.
            </p>
            <Button href="/schedule" variant="secondary" className="mt-4">
              Go to schedule
            </Button>
          </div>
        )}
      </Card>

      {loading ? (
        <div className="flex justify-center py-16">
          <Spinner size={32} className="text-primary" />
        </div>
      ) : (
        <>
          <div className="mt-6 grid gap-4 sm:grid-cols-2">
            <StatCard
              label="Wrote today"
              value={`${wroteTodayCount} / ${activeCount}`}
              detail="Active players with an entry today"
            />
            <StatCard
              label={`Wrote in the last ${PARTICIPATION_LOOKBACK_DAYS} days`}
              value={`${wroteLast7Count} / ${activeCount}`}
              detail="Active players with at least one entry"
            />
          </div>

          <Card className="mt-6">
            <h2 className="font-display text-lg font-semibold text-text-primary">
              Team mood ({MOOD_TREND_DAYS} days)
            </h2>
            <p className="mt-1 text-sm text-text-secondary">
              Average mood score across all entries each day.
            </p>
            <div className="mt-4">
              <MoodTrendChart points={moodPoints} />
            </div>
          </Card>

          <Card className="mt-6">
            <h2 className="font-display text-lg font-semibold text-text-primary">
              Common themes ({THEME_LOOKBACK_DAYS} days)
            </h2>
            <p className="mt-1 text-sm text-text-secondary">
              Topics showing up most often in entry summaries.
            </p>
            <ThemeChips themes={topThemes} className="mt-4" />
          </Card>

          <Card className="mt-6">
            <h2 className="font-display text-lg font-semibold text-text-primary">
              Quiet lately
            </h2>
            <p className="mt-1 text-sm text-text-secondary">
              Active players who haven&apos;t written in {INACTIVE_ENTRY_DAYS} or more days.
            </p>
            {inactivePlayers.length === 0 ? (
              <p className="mt-4 text-sm text-success">
                Everyone active on the roster has written recently.
              </p>
            ) : (
              <ul className="mt-4 space-y-2">
                {inactivePlayers.map((player) => (
                  <li key={player.playerId}>
                    <Link
                      href={`/players?uid=${encodeURIComponent(player.uid!)}`}
                      className="flex items-center justify-between rounded-xl border border-border-subtle px-4 py-3 text-sm transition-colors hover:border-primary/40 hover:bg-surface-elevated"
                    >
                      <span className="font-semibold text-text-primary">{player.name}</span>
                      <span className="text-text-muted">
                        {player.lastEntryAt
                          ? `Last entry ${formatDayKey(player.lastEntryAt)}`
                          : "No entries yet"}
                      </span>
                    </Link>
                  </li>
                ))}
              </ul>
            )}
          </Card>

          <Card className="mt-6">
            <h2 className="font-display text-lg font-semibold text-text-primary">
              Recent entries
            </h2>
            {recentEntries.length === 0 ? (
              <EmptyState
                className="mt-4"
                title="No entries yet"
                subtitle="When players write in the app, summaries will show up here."
              />
            ) : (
              <ul className="mt-4 space-y-3">
                {recentEntries.map((entry) => (
                  <li
                    key={entry.entryId}
                    className="rounded-xl border border-border-subtle px-4 py-4"
                  >
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <Link
                        href={`/players?uid=${encodeURIComponent(entry.playerUid)}`}
                        className="font-semibold text-primary hover:underline"
                      >
                        {entry.playerName}
                      </Link>
                      <span className="text-xs text-text-muted">{formatDayKey(entry.date)}</span>
                    </div>
                    <p className="mt-1 text-xs font-semibold capitalize text-text-secondary">
                      Mood: {entry.mood}
                    </p>
                    <p className="mt-2 text-sm text-text-primary">{entry.summary}</p>
                  </li>
                ))}
              </ul>
            )}
          </Card>
        </>
      )}
    </div>
  );
}

export default function DashboardPage() {
  return (
    <AuthGate>
      <DashboardContent />
    </AuthGate>
  );
}
