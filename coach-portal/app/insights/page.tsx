"use client";

import { useEffect, useMemo, useState } from "react";
import { collection, onSnapshot } from "firebase/firestore";
import { AuthGate } from "@/components/AuthGate";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { EmptyState } from "@/components/ui/EmptyState";
import { Input } from "@/components/ui/Input";
import { Spinner } from "@/components/ui/Spinner";
import { useAuth } from "@/lib/auth-context";
import {
  currentIsoWeek,
  formatDayKey,
  formatReportPeriod,
  isValidIsoWeek,
} from "@/lib/date-utils";
import { formatCallableError } from "@/lib/errors";
import { db, generateTeamReportCallable } from "@/lib/firebase";
import type { TeamReportDoc } from "@/lib/types";

function formatParticipation(rate: number): string {
  return `${Math.round(rate * 100)}%`;
}

function ReportCard({ report }: { report: TeamReportDoc }) {
  const themeItems = report.themes.map((theme) => ({ theme, count: 0 }));

  return (
    <Card className="mt-4">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.15em] text-primary">
            {report.period}
          </p>
          <h3 className="mt-1 font-display text-lg font-semibold text-text-primary">
            {formatReportPeriod(report.periodStart, report.periodEnd)}
          </h3>
          <p className="mt-1 text-xs text-text-muted">
            Generated {formatDayKey(report.generatedAt.slice(0, 10))}
          </p>
        </div>
        <div className="text-right text-xs text-text-secondary">
          <p>{report.entryCount} entries</p>
          <p>
            {formatParticipation(report.participationRate)} participation · avg mood{" "}
            {report.averageMoodScore.toFixed(1)}
          </p>
        </div>
      </div>

      <p className="mt-4 text-sm leading-relaxed text-text-primary">{report.summary}</p>

      {report.themes.length > 0 && (
        <div className="mt-5">
          <p className="text-sm font-semibold text-text-primary">Themes</p>
          <div className="mt-2 flex flex-wrap gap-2">
            {themeItems.map(({ theme }) => (
              <span
                key={theme}
                className="rounded-full border border-border bg-surface-elevated px-3 py-1.5 text-xs font-semibold text-text-secondary"
              >
                {theme}
              </span>
            ))}
          </div>
        </div>
      )}

      {report.wins.length > 0 && (
        <div className="mt-5">
          <p className="text-sm font-semibold text-success">Wins</p>
          <ul className="mt-2 list-disc space-y-1 pl-5 text-sm text-text-secondary">
            {report.wins.map((win) => (
              <li key={win}>{win}</li>
            ))}
          </ul>
        </div>
      )}

      {report.concerns.length > 0 && (
        <div className="mt-5">
          <p className="text-sm font-semibold text-warning">Concerns</p>
          <ul className="mt-2 list-disc space-y-1 pl-5 text-sm text-text-secondary">
            {report.concerns.map((concern) => (
              <li key={concern}>{concern}</li>
            ))}
          </ul>
        </div>
      )}

      {report.watchList.length > 0 && (
        <div className="mt-5">
          <p className="text-sm font-semibold text-text-primary">Watch list</p>
          <ul className="mt-2 space-y-2">
            {report.watchList.map((item) => (
              <li
                key={`${item.playerUid}-${item.note}`}
                className="rounded-xl border border-border-subtle px-4 py-3 text-sm"
              >
                <p className="font-semibold text-text-primary">{item.playerName}</p>
                <p className="mt-1 text-text-secondary">{item.note}</p>
              </li>
            ))}
          </ul>
        </div>
      )}
    </Card>
  );
}

function InsightsPageContent() {
  const { activeTeamId, teams } = useAuth();
  const activeTeam = teams.find((t) => t.teamId === activeTeamId) ?? null;

  const [reports, setReports] = useState<TeamReportDoc[]>([]);
  const [reportsLoading, setReportsLoading] = useState(true);
  const [reportsError, setReportsError] = useState<string | null>(null);

  const [period, setPeriod] = useState(currentIsoWeek());
  const [generating, setGenerating] = useState(false);
  const [generateError, setGenerateError] = useState<string | null>(null);
  const [generateSuccess, setGenerateSuccess] = useState<string | null>(null);

  useEffect(() => {
    if (!activeTeamId) {
      setReports([]);
      setReportsLoading(false);
      return;
    }
    setReportsLoading(true);
    setReportsError(null);
    const unsub = onSnapshot(
      collection(db, "teams", activeTeamId, "reports"),
      (snap) => {
        const next = snap.docs.map((d) => d.data() as TeamReportDoc);
        next.sort((a, b) => b.period.localeCompare(a.period));
        setReports(next);
        setReportsLoading(false);
      },
      () => {
        setReportsError("Failed to load team reports. Please refresh the page.");
        setReportsLoading(false);
      },
    );
    return unsub;
  }, [activeTeamId]);

  const periodError = useMemo(() => {
    if (!period.trim()) return "Enter a week period.";
    if (!isValidIsoWeek(period.trim())) return "Use the format 2026-W33.";
    return null;
  }, [period]);

  async function handleGenerate() {
    if (!activeTeamId || periodError) return;
    setGenerating(true);
    setGenerateError(null);
    setGenerateSuccess(null);
    try {
      const result = await generateTeamReportCallable({
        teamId: activeTeamId,
        period: period.trim(),
      });
      setGenerateSuccess(`Report for ${result.data.period} is ready.`);
    } catch (err) {
      setGenerateError(formatCallableError(err));
    } finally {
      setGenerating(false);
    }
  }

  if (!activeTeamId) {
    return (
      <EmptyState
        title="No team selected"
        subtitle="Choose or set up a team to view weekly insights."
      />
    );
  }

  return (
    <div>
      <div>
        <p className="text-xs font-semibold uppercase tracking-[0.2em] text-primary">Insights</p>
        <h1 className="mt-2 font-display text-3xl font-bold text-text-primary">
          {activeTeam?.name ?? "Your team"}
        </h1>
        <p className="mt-2 text-sm text-text-secondary">
          AI weekly reports on team themes, participation, and patterns.
        </p>
      </div>

      <Card className="mt-8">
        <h2 className="font-display text-lg font-semibold text-text-primary">Generate a report</h2>
        <p className="mt-1 text-sm text-text-secondary">
          Reports are generated automatically each week. Use this to regenerate a week or backfill
          a missing period.
        </p>

        <div className="mt-5 max-w-xs">
          <Input
            label="ISO week"
            value={period}
            onChange={(e) => setPeriod(e.target.value.toUpperCase())}
            disabled={generating}
            placeholder="2026-W33"
            hint="Format: YYYY-Wnn (week 01 through 53)."
            error={periodError ?? undefined}
          />
        </div>

        {generating && (
          <div className="mt-5 flex items-start gap-4 rounded-xl border border-primary/30 bg-primary-container px-4 py-4">
            <Spinner size={24} className="mt-0.5 shrink-0 text-primary" />
            <div>
              <p className="text-sm font-semibold text-text-primary">Generating report…</p>
              <p className="mt-1 text-sm text-text-secondary">
                This calls Claude and can take several minutes. Stay on this page until it finishes.
              </p>
            </div>
          </div>
        )}

        {generateError && (
          <div className="mt-4 rounded-xl border border-error/30 bg-error/10 px-4 py-3 text-sm text-error">
            {generateError}
          </div>
        )}

        {generateSuccess && (
          <div className="mt-4 rounded-xl border border-success/30 bg-success/10 px-4 py-3 text-sm text-success">
            {generateSuccess}
          </div>
        )}

        <div className="mt-6 flex justify-end">
          <Button
            onClick={handleGenerate}
            isLoading={generating}
            disabled={generating || !!periodError}
          >
            Generate report
          </Button>
        </div>
      </Card>

      <div className="mt-8">
        <h2 className="font-display text-lg font-semibold text-text-primary">Past reports</h2>

        {reportsError && (
          <div className="mt-4 rounded-xl border border-error/30 bg-error/10 px-4 py-3 text-sm text-error">
            {reportsError}
          </div>
        )}

        {reportsLoading ? (
          <div className="flex justify-center py-10">
            <Spinner size={28} className="text-primary" />
          </div>
        ) : reports.length === 0 ? (
          <EmptyState
            className="mt-4"
            title="No reports yet"
            subtitle="The first weekly report will appear after your team has entries, or generate one above."
          />
        ) : (
          reports.map((report) => <ReportCard key={report.period} report={report} />)
        )}
      </div>
    </div>
  );
}

export default function InsightsPage() {
  return (
    <AuthGate>
      <InsightsPageContent />
    </AuthGate>
  );
}
