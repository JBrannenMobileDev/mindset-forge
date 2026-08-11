"use client";

import Link from "next/link";
import { Suspense, useEffect, useMemo, useState } from "react";
import { collection, onSnapshot, orderBy, query } from "firebase/firestore";
import { AuthGate } from "@/components/AuthGate";
import { ConfirmDialog } from "@/components/ui/ConfirmDialog";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { EmptyState } from "@/components/ui/EmptyState";
import { Input, Textarea } from "@/components/ui/Input";
import { Spinner } from "@/components/ui/Spinner";
import { useAuth } from "@/lib/auth-context";
import {
  addManualPromptCallable,
  db,
  deletePromptCallable,
  generateTeamPromptsCallable,
} from "@/lib/firebase";
import { formatCallableError } from "@/lib/errors";
import { formatDayKey } from "@/lib/date-utils";
import type { TeamPromptDoc } from "@/lib/types";

const MIN_GENERATE_COUNT = 1;
const MAX_GENERATE_COUNT = 25;
const DEFAULT_GENERATE_COUNT = 10;

function clampGenerateCount(value: number): number {
  if (!Number.isFinite(value)) return DEFAULT_GENERATE_COUNT;
  return Math.min(MAX_GENERATE_COUNT, Math.max(MIN_GENERATE_COUNT, Math.round(value)));
}

function sourceLabel(source: TeamPromptDoc["source"]): string {
  return source === "ai" ? "Generated" : "Added by you";
}

function PromptsPageContent() {
  const { activeTeamId, teams } = useAuth();
  const activeTeam = teams.find((t) => t.teamId === activeTeamId) ?? null;

  const [prompts, setPrompts] = useState<TeamPromptDoc[]>([]);
  const [promptsLoading, setPromptsLoading] = useState(true);
  const [promptsError, setPromptsError] = useState<string | null>(null);

  const [generateCount, setGenerateCount] = useState(DEFAULT_GENERATE_COUNT);
  const [generateTheme, setGenerateTheme] = useState("");
  const [generating, setGenerating] = useState(false);
  const [generateError, setGenerateError] = useState<string | null>(null);

  const [manualText, setManualText] = useState("");
  const [manualTheme, setManualTheme] = useState("");
  const [addingManual, setAddingManual] = useState(false);
  const [addManualError, setAddManualError] = useState<string | null>(null);

  const [themeFilter, setThemeFilter] = useState<string>("all");

  const [deleteTarget, setDeleteTarget] = useState<TeamPromptDoc | null>(null);
  const [deleting, setDeleting] = useState(false);
  const [deleteError, setDeleteError] = useState<string | null>(null);

  useEffect(() => {
    if (!activeTeamId) {
      setPrompts([]);
      setPromptsLoading(false);
      return;
    }
    setPromptsLoading(true);
    setPromptsError(null);
    const promptsQuery = query(
      collection(db, "teams", activeTeamId, "prompts"),
      orderBy("createdAt", "desc"),
    );
    const unsub = onSnapshot(
      promptsQuery,
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

  const distinctThemes = useMemo(() => {
    const themes = new Set<string>();
    for (const prompt of prompts) {
      const theme = prompt.theme.trim();
      if (theme) themes.add(theme);
    }
    return Array.from(themes).sort((a, b) => a.localeCompare(b));
  }, [prompts]);

  const filteredPrompts = useMemo(() => {
    if (themeFilter === "all") return prompts;
    return prompts.filter((p) => p.theme.trim() === themeFilter);
  }, [prompts, themeFilter]);

  async function handleGenerate() {
    if (!activeTeamId) return;
    setGenerating(true);
    setGenerateError(null);
    try {
      await generateTeamPromptsCallable({
        teamId: activeTeamId,
        count: clampGenerateCount(generateCount),
        theme: generateTheme.trim() || undefined,
      });
      setGenerateTheme("");
    } catch (err) {
      setGenerateError(formatCallableError(err));
    } finally {
      setGenerating(false);
    }
  }

  async function handleAddManual() {
    if (!activeTeamId) return;
    const text = manualText.trim();
    if (!text) {
      setAddManualError("Enter prompt text.");
      return;
    }
    setAddingManual(true);
    setAddManualError(null);
    try {
      await addManualPromptCallable({
        teamId: activeTeamId,
        text,
        theme: manualTheme.trim() || undefined,
      });
      setManualText("");
      setManualTheme("");
    } catch (err) {
      setAddManualError(formatCallableError(err));
    } finally {
      setAddingManual(false);
    }
  }

  async function confirmDelete() {
    if (!deleteTarget || !activeTeamId) return;
    setDeleting(true);
    setDeleteError(null);
    try {
      await deletePromptCallable({ teamId: activeTeamId, promptId: deleteTarget.promptId });
      setDeleteTarget(null);
    } catch (err) {
      setDeleteError(formatCallableError(err));
    } finally {
      setDeleting(false);
    }
  }

  if (!activeTeamId) {
    return (
      <EmptyState
        title="No team selected"
        subtitle="Choose or set up a team to manage its prompt bank."
      />
    );
  }

  return (
    <div>
      <div>
        <p className="text-xs font-semibold uppercase tracking-[0.2em] text-primary">Prompts</p>
        <h1 className="mt-2 font-display text-3xl font-bold text-text-primary">
          {activeTeam?.name ?? "Your team"}
        </h1>
        <p className="mt-2 text-sm text-text-secondary">
          Build a bank of journal prompts, then assign one per day on the schedule.
        </p>
      </div>

      <Card className="mt-8">
        <h2 className="font-display text-lg font-semibold text-text-primary">Generate prompts</h2>
        <p className="mt-1 text-sm text-text-secondary">
          AI drafts new prompts using your team settings (sport, focus areas, tone, and notes).{" "}
          <Link href="/settings" className="font-semibold text-primary hover:underline">
            Review team settings
          </Link>
        </p>

        <div className="mt-5 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <Input
            label="How many?"
            type="number"
            min={MIN_GENERATE_COUNT}
            max={MAX_GENERATE_COUNT}
            value={generateCount}
            onChange={(e) => setGenerateCount(clampGenerateCount(Number(e.target.value)))}
            disabled={generating}
            hint={`Between ${MIN_GENERATE_COUNT} and ${MAX_GENERATE_COUNT}.`}
          />
          <Input
            label="Theme (optional)"
            value={generateTheme}
            onChange={(e) => setGenerateTheme(e.target.value)}
            disabled={generating}
            placeholder="e.g. resilience, game day"
          />
        </div>

        {generating && (
          <div className="mt-5 flex items-start gap-4 rounded-xl border border-primary/30 bg-primary-container px-4 py-4">
            <Spinner size={24} className="mt-0.5 shrink-0 text-primary" />
            <div>
              <p className="text-sm font-semibold text-text-primary">Generating prompts…</p>
              <p className="mt-1 text-sm text-text-secondary">
                This calls Claude and usually takes 30 seconds or more. Stay on this page until it
                finishes.
              </p>
            </div>
          </div>
        )}

        {generateError && (
          <div className="mt-4 rounded-xl border border-error/30 bg-error/10 px-4 py-3 text-sm text-error">
            {generateError}
          </div>
        )}

        <div className="mt-6 flex justify-end">
          <Button onClick={handleGenerate} isLoading={generating} disabled={generating}>
            Generate prompts
          </Button>
        </div>
      </Card>

      <Card className="mt-6">
        <h2 className="font-display text-lg font-semibold text-text-primary">Add a prompt</h2>
        <p className="mt-1 text-sm text-text-secondary">
          Write your own question to add to the bank.
        </p>
        <div className="mt-5 space-y-4">
          <Textarea
            label="Prompt text"
            value={manualText}
            onChange={(e) => setManualText(e.target.value)}
            disabled={addingManual}
            rows={3}
            placeholder="What mindset do you want your team to bring into tomorrow's practice?"
          />
          <Input
            label="Theme (optional)"
            value={manualTheme}
            onChange={(e) => setManualTheme(e.target.value)}
            disabled={addingManual}
          />
        </div>

        {addManualError && (
          <div className="mt-4 rounded-xl border border-error/30 bg-error/10 px-4 py-3 text-sm text-error">
            {addManualError}
          </div>
        )}

        <div className="mt-6 flex justify-end">
          <Button
            onClick={handleAddManual}
            isLoading={addingManual}
            disabled={addingManual || !manualText.trim()}
          >
            Add prompt
          </Button>
        </div>
      </Card>

      <Card className="mt-8">
        <div className="flex flex-wrap items-end justify-between gap-4">
          <div>
            <h2 className="font-display text-lg font-semibold text-text-primary">Prompt bank</h2>
            <p className="mt-1 text-sm text-text-secondary">
              {prompts.length === 0
                ? "No prompts yet. Generate or add some above."
                : `${prompts.length} prompt${prompts.length === 1 ? "" : "s"} in the bank.`}
            </p>
          </div>
          {distinctThemes.length > 0 && (
            <label className="block min-w-[180px]">
              <span className="text-sm font-semibold text-text-primary">Filter by theme</span>
              <select
                value={themeFilter}
                onChange={(e) => setThemeFilter(e.target.value)}
                className="mt-2 w-full rounded-xl border border-border bg-background px-4 py-3 text-sm text-text-primary outline-none transition-colors focus:border-primary"
              >
                <option value="all">All themes</option>
                {distinctThemes.map((theme) => (
                  <option key={theme} value={theme}>
                    {theme}
                  </option>
                ))}
              </select>
            </label>
          )}
        </div>

        {promptsError && (
          <div className="mt-4 rounded-xl border border-error/30 bg-error/10 px-4 py-3 text-sm text-error">
            {promptsError}
          </div>
        )}

        {promptsLoading ? (
          <div className="flex justify-center py-10">
            <Spinner size={28} className="text-primary" />
          </div>
        ) : prompts.length === 0 ? (
          <EmptyState
            className="mt-4"
            title="No prompts yet"
            subtitle="Generate a batch with AI or add your own question above."
          />
        ) : filteredPrompts.length === 0 ? (
          <EmptyState
            className="mt-4"
            title="No prompts match this theme"
            subtitle="Choose a different filter or add prompts with this theme."
          />
        ) : (
          <ul className="mt-5 space-y-3">
            {filteredPrompts.map((prompt) => {
              const used = prompt.usedDates.length > 0;
              return (
                <li
                  key={prompt.promptId}
                  className={`rounded-xl border px-4 py-4 ${
                    used
                      ? "border-border-subtle bg-surface opacity-75"
                      : "border-border bg-surface"
                  }`}
                >
                  <div className="flex flex-wrap items-start justify-between gap-3">
                    <div className="min-w-0 flex-1">
                      <p className={`text-sm ${used ? "text-text-secondary" : "text-text-primary"}`}>
                        {prompt.text}
                      </p>
                      <div className="mt-2 flex flex-wrap items-center gap-2 text-xs">
                        {prompt.theme.trim() && (
                          <span className="rounded-full border border-border bg-surface-elevated px-2.5 py-1 font-semibold text-text-secondary">
                            {prompt.theme}
                          </span>
                        )}
                        <span className="text-text-muted">{sourceLabel(prompt.source)}</span>
                        {used ? (
                          <span className="text-text-muted">
                            Used on{" "}
                            {prompt.usedDates
                              .slice()
                              .sort()
                              .map((d) => formatDayKey(d))
                              .join(", ")}
                          </span>
                        ) : (
                          <span className="text-success">Not used yet</span>
                        )}
                      </div>
                    </div>
                    <Button variant="danger" size="sm" onClick={() => setDeleteTarget(prompt)}>
                      Delete
                    </Button>
                  </div>
                </li>
              );
            })}
          </ul>
        )}
      </Card>

      <ConfirmDialog
        open={deleteTarget !== null}
        title="Delete this prompt?"
        description={
          deleteTarget && deleteTarget.usedDates.length > 0 ? (
            <>
              This prompt has been assigned on past dates. Removing it only deletes the bank entry.
              Past journal entries that referenced it stay intact.
            </>
          ) : (
            <>This removes the prompt from your bank. You can always add or generate more later.</>
          )
        }
        confirmLabel="Delete prompt"
        danger
        isLoading={deleting}
        error={deleteError}
        onConfirm={confirmDelete}
        onCancel={() => {
          setDeleteTarget(null);
          setDeleteError(null);
        }}
      />
    </div>
  );
}

function PromptsPageInner() {
  return (
    <AuthGate>
      <PromptsPageContent />
    </AuthGate>
  );
}

export default function PromptsPage() {
  return (
    <Suspense
      fallback={
        <main className="flex min-h-screen items-center justify-center bg-background text-text-secondary">
          Loading…
        </main>
      }
    >
      <PromptsPageInner />
    </Suspense>
  );
}
