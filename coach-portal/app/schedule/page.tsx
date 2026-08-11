"use client";

import Link from "next/link";
import { Suspense, useEffect, useMemo, useState } from "react";
import { collection, onSnapshot } from "firebase/firestore";
import { AuthGate } from "@/components/AuthGate";
import { ConfirmDialog } from "@/components/ui/ConfirmDialog";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { EmptyState } from "@/components/ui/EmptyState";
import { Input } from "@/components/ui/Input";
import { Spinner } from "@/components/ui/Spinner";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeaderCell,
  TableRow,
} from "@/components/ui/Table";
import { useAuth } from "@/lib/auth-context";
import { assignTeamPromptCallable, db, unassignTeamPromptCallable } from "@/lib/firebase";
import { formatCallableError } from "@/lib/errors";
import { formatDayKey, formatWeekday, todayDayKey, upcomingDayKeys } from "@/lib/date-utils";
import type { TeamPromptDoc, TeamScheduleDoc } from "@/lib/types";

const SCHEDULE_DAYS = 28;

const selectClasses =
  "w-full rounded-xl border border-border bg-background px-4 py-3 text-sm text-text-primary outline-none transition-colors focus:border-primary disabled:cursor-not-allowed disabled:opacity-50";

function SchedulePageContent() {
  const { activeTeamId, teams } = useAuth();
  const activeTeam = teams.find((t) => t.teamId === activeTeamId) ?? null;

  const today = todayDayKey();
  const dayKeys = useMemo(() => upcomingDayKeys(SCHEDULE_DAYS), []);

  const [scheduleByDate, setScheduleByDate] = useState<Record<string, TeamScheduleDoc>>({});
  const [scheduleLoading, setScheduleLoading] = useState(true);
  const [scheduleError, setScheduleError] = useState<string | null>(null);

  const [prompts, setPrompts] = useState<TeamPromptDoc[]>([]);
  const [promptsLoading, setPromptsLoading] = useState(true);
  const [promptsError, setPromptsError] = useState<string | null>(null);

  const [promptSearch, setPromptSearch] = useState("");
  const [selectedPromptByDate, setSelectedPromptByDate] = useState<Record<string, string>>({});
  const [assigningDate, setAssigningDate] = useState<string | null>(null);
  const [assignError, setAssignError] = useState<string | null>(null);

  const [unassignDate, setUnassignDate] = useState<string | null>(null);
  const [unassigning, setUnassigning] = useState(false);
  const [unassignError, setUnassignError] = useState<string | null>(null);

  useEffect(() => {
    if (!activeTeamId) {
      setScheduleByDate({});
      setScheduleLoading(false);
      return;
    }
    setScheduleLoading(true);
    setScheduleError(null);
    const unsub = onSnapshot(
      collection(db, "teams", activeTeamId, "schedule"),
      (snap) => {
        const next: Record<string, TeamScheduleDoc> = {};
        for (const doc of snap.docs) {
          const data = doc.data() as TeamScheduleDoc;
          next[data.date] = data;
        }
        setScheduleByDate(next);
        setScheduleLoading(false);
      },
      () => {
        setScheduleError("Failed to load the schedule. Please refresh the page.");
        setScheduleLoading(false);
      },
    );
    return unsub;
  }, [activeTeamId]);

  useEffect(() => {
    if (!activeTeamId) {
      setPrompts([]);
      setPromptsLoading(false);
      return;
    }
    setPromptsLoading(true);
    setPromptsError(null);
    const unsub = onSnapshot(
      collection(db, "teams", activeTeamId, "prompts"),
      (snap) => {
        setPrompts(snap.docs.map((d) => d.data() as TeamPromptDoc));
        setPromptsLoading(false);
      },
      () => {
        setPromptsError("Failed to load the prompt bank. Please refresh the page.");
        setPromptsLoading(false);
      },
    );
    return unsub;
  }, [activeTeamId]);

  const filteredPrompts = useMemo(() => {
    const q = promptSearch.trim().toLowerCase();
    if (!q) return prompts;
    return prompts.filter(
      (p) =>
        p.text.toLowerCase().includes(q) ||
        p.theme.toLowerCase().includes(q),
    );
  }, [prompts, promptSearch]);

  const unassignedCount = useMemo(
    () => dayKeys.filter((date) => !scheduleByDate[date]).length,
    [dayKeys, scheduleByDate],
  );

  const loading = scheduleLoading || promptsLoading;

  function promptSelectValue(date: string): string {
    if (selectedPromptByDate[date] !== undefined) return selectedPromptByDate[date];
    return scheduleByDate[date]?.promptId ?? "";
  }

  async function handleAssign(date: string) {
    if (!activeTeamId) return;
    const promptId = promptSelectValue(date);
    if (!promptId) {
      setAssignError("Choose a prompt to assign.");
      return;
    }
    setAssigningDate(date);
    setAssignError(null);
    try {
      await assignTeamPromptCallable({ teamId: activeTeamId, date, promptId });
      setSelectedPromptByDate((prev) => {
        const next = { ...prev };
        delete next[date];
        return next;
      });
    } catch (err) {
      setAssignError(formatCallableError(err));
    } finally {
      setAssigningDate(null);
    }
  }

  async function confirmUnassign() {
    if (!unassignDate || !activeTeamId) return;
    setUnassigning(true);
    setUnassignError(null);
    try {
      await unassignTeamPromptCallable({ teamId: activeTeamId, date: unassignDate });
      setUnassignDate(null);
    } catch (err) {
      setUnassignError(formatCallableError(err));
    } finally {
      setUnassigning(false);
    }
  }

  if (!activeTeamId) {
    return (
      <EmptyState
        title="No team selected"
        subtitle="Choose or set up a team to manage its daily prompt schedule."
      />
    );
  }

  return (
    <div>
      <div>
        <p className="text-xs font-semibold uppercase tracking-[0.2em] text-primary">Schedule</p>
        <h1 className="mt-2 font-display text-3xl font-bold text-text-primary">
          {activeTeam?.name ?? "Your team"}
        </h1>
        <p className="mt-2 text-sm text-text-secondary">
          Assign one prompt per day for the next {SCHEDULE_DAYS} days.
        </p>
        <p className="mt-3 rounded-xl border border-border-subtle bg-surface-elevated px-4 py-3 text-sm text-text-secondary">
          Prompts go live at 4 AM local time on the date you assign. If you assign tomorrow&apos;s
          prompt at 11 PM tonight, players won&apos;t see it until 4 AM tomorrow. That matches how
          the app tracks daily streaks.
        </p>
      </div>

      {!loading && prompts.length === 0 ? (
        <EmptyState
          className="mt-8"
          title="No prompts in your bank yet"
          subtitle="Generate or add prompts first, then come back here to schedule them."
          action={
            <Button href="/prompts" variant="secondary">
              Go to prompts
            </Button>
          }
        />
      ) : (
        <Card className="mt-8">
          <div className="flex flex-wrap items-end justify-between gap-4">
            <div>
              <h2 className="font-display text-lg font-semibold text-text-primary">
                Next {SCHEDULE_DAYS} days
              </h2>
              {!loading && unassignedCount > 0 && (
                <p className="mt-1 text-sm font-semibold text-warning">
                  {unassignedCount} day{unassignedCount === 1 ? "" : "s"} still need a prompt
                </p>
              )}
              {!loading && unassignedCount === 0 && prompts.length > 0 && (
                <p className="mt-1 text-sm text-success">Every day in this window has a prompt.</p>
              )}
            </div>
            {prompts.length > 0 && (
              <Input
                label="Search prompts"
                value={promptSearch}
                onChange={(e) => setPromptSearch(e.target.value)}
                placeholder="Filter by text or theme"
                className="min-w-[220px]"
              />
            )}
          </div>

          {(scheduleError || promptsError) && (
            <div className="mt-4 space-y-2">
              {scheduleError && (
                <div className="rounded-xl border border-error/30 bg-error/10 px-4 py-3 text-sm text-error">
                  {scheduleError}
                </div>
              )}
              {promptsError && (
                <div className="rounded-xl border border-error/30 bg-error/10 px-4 py-3 text-sm text-error">
                  {promptsError}
                </div>
              )}
            </div>
          )}

          {assignError && (
            <div className="mt-4 rounded-xl border border-error/30 bg-error/10 px-4 py-3 text-sm text-error">
              {assignError}
            </div>
          )}

          {loading ? (
            <div className="flex justify-center py-10">
              <Spinner size={28} className="text-primary" />
            </div>
          ) : (
            <Table className="mt-4">
              <TableHead>
                <TableRow>
                  <TableHeaderCell>Date</TableHeaderCell>
                  <TableHeaderCell>Assigned prompt</TableHeaderCell>
                  <TableHeaderCell>Assign</TableHeaderCell>
                  <TableHeaderCell>{null}</TableHeaderCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {dayKeys.map((date) => {
                  const assigned = scheduleByDate[date];
                  const isToday = date === today;
                  const isUnassigned = !assigned;
                  const assigning = assigningDate === date;

                  return (
                    <TableRow
                      key={date}
                      className={
                        isUnassigned
                          ? "bg-warning/5"
                          : isToday
                            ? "bg-primary-container/40"
                            : undefined
                      }
                    >
                      <TableCell className="whitespace-nowrap">
                        <div className="flex items-center gap-2">
                          <span className="font-semibold">{formatDayKey(date)}</span>
                          <span className="text-text-muted">{formatWeekday(date)}</span>
                          {isToday && (
                            <span className="rounded-full border border-primary/30 bg-primary-container px-2 py-0.5 text-xs font-semibold text-primary">
                              Today
                            </span>
                          )}
                        </div>
                      </TableCell>
                      <TableCell>
                        {assigned ? (
                          <p className="text-sm text-text-primary">{assigned.promptText}</p>
                        ) : (
                          <p className="text-sm font-semibold text-warning">No prompt assigned</p>
                        )}
                      </TableCell>
                      <TableCell className="min-w-[240px]">
                        <select
                          value={promptSelectValue(date)}
                          onChange={(e) =>
                            setSelectedPromptByDate((prev) => ({
                              ...prev,
                              [date]: e.target.value,
                            }))
                          }
                          disabled={assigning || prompts.length === 0}
                          className={selectClasses}
                          aria-label={`Choose prompt for ${formatDayKey(date)}`}
                        >
                          <option value="">Choose a prompt…</option>
                          {filteredPrompts.map((prompt) => (
                            <option key={prompt.promptId} value={prompt.promptId}>
                              {prompt.theme.trim() ? `[${prompt.theme}] ` : ""}
                              {prompt.text.length > 80
                                ? `${prompt.text.slice(0, 80)}…`
                                : prompt.text}
                            </option>
                          ))}
                        </select>
                      </TableCell>
                      <TableCell className="whitespace-nowrap">
                        <div className="flex flex-wrap gap-2">
                          <Button
                            size="sm"
                            onClick={() => handleAssign(date)}
                            isLoading={assigning}
                            disabled={assigning || !promptSelectValue(date)}
                          >
                            {assigned ? "Replace" : "Assign"}
                          </Button>
                          {assigned && (
                            <Button
                              variant="danger"
                              size="sm"
                              onClick={() => setUnassignDate(date)}
                              disabled={assigning}
                            >
                              Unassign
                            </Button>
                          )}
                        </div>
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          )}
        </Card>
      )}

      <ConfirmDialog
        open={unassignDate !== null}
        title={
          unassignDate
            ? `Unassign the prompt for ${formatDayKey(unassignDate)}?`
            : "Unassign this prompt?"
        }
        description={
          <>
            Players won&apos;t see a team prompt on this date until you assign a new one. Past
            entries are not affected.
          </>
        }
        confirmLabel="Unassign"
        danger
        isLoading={unassigning}
        error={unassignError}
        onConfirm={confirmUnassign}
        onCancel={() => {
          setUnassignDate(null);
          setUnassignError(null);
        }}
      />
    </div>
  );
}

function SchedulePageInner() {
  return (
    <AuthGate>
      <SchedulePageContent />
    </AuthGate>
  );
}

export default function SchedulePage() {
  return (
    <Suspense
      fallback={
        <main className="flex min-h-screen items-center justify-center bg-background text-text-secondary">
          Loading…
        </main>
      }
    >
      <SchedulePageInner />
    </Suspense>
  );
}
