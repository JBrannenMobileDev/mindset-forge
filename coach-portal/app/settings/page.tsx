"use client";

import { FormEvent, useEffect, useMemo, useState } from "react";
import { doc, onSnapshot } from "firebase/firestore";
import { AuthGate } from "@/components/AuthGate";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { EmptyState } from "@/components/ui/EmptyState";
import { Input, Textarea } from "@/components/ui/Input";
import { Spinner } from "@/components/ui/Spinner";
import { useAuth } from "@/lib/auth-context";
import { toDateInputValue } from "@/lib/date-utils";
import { formatCallableError } from "@/lib/errors";
import { db, updateTeamSettingsCallable } from "@/lib/firebase";
import type { TeamDoc, TeamGuidance, UpdateTeamSettingsRequest } from "@/lib/types";

type FormState = {
  name: string;
  sport: string;
  seasonEndsAt: string;
  focusAreas: string[];
  tone: string;
  notes: string;
  guidanceSeason: string;
};

function teamToForm(team: TeamDoc): FormState {
  return {
    name: team.name,
    sport: team.sport,
    seasonEndsAt: toDateInputValue(team.seasonEndsAt),
    focusAreas: [...team.guidance.focusAreas],
    tone: team.guidance.tone,
    notes: team.guidance.notes,
    guidanceSeason: team.guidance.season,
  };
}

function SettingsPageContent() {
  const { activeTeamId, teams, refresh } = useAuth();
  const activeTeam = teams.find((t) => t.teamId === activeTeamId) ?? null;

  const [team, setTeam] = useState<TeamDoc | null>(null);
  const [initialForm, setInitialForm] = useState<FormState | null>(null);
  const [form, setForm] = useState<FormState | null>(null);
  const [teamLoading, setTeamLoading] = useState(true);
  const [teamError, setTeamError] = useState<string | null>(null);

  const [newFocusArea, setNewFocusArea] = useState("");
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [saveSuccess, setSaveSuccess] = useState(false);

  useEffect(() => {
    if (!activeTeamId) {
      setTeam(null);
      setForm(null);
      setInitialForm(null);
      setTeamLoading(false);
      return;
    }
    setTeamLoading(true);
    setTeamError(null);
    const teamRef = doc(db, "teams", activeTeamId);
    const unsub = onSnapshot(
      teamRef,
      (snap) => {
        if (!snap.exists()) {
          setTeam(null);
          setForm(null);
          setInitialForm(null);
          setTeamError("Team not found.");
        } else {
          const data = snap.data() as TeamDoc;
          setTeam(data);
          const nextForm = teamToForm(data);
          setForm(nextForm);
          setInitialForm(nextForm);
        }
        setTeamLoading(false);
      },
      () => {
        setTeamError("Failed to load team settings. Please refresh the page.");
        setTeamLoading(false);
      },
    );
    return unsub;
  }, [activeTeamId]);

  const hasChanges = useMemo(() => {
    if (!form || !initialForm) return false;
    return JSON.stringify(form) !== JSON.stringify(initialForm);
  }, [form, initialForm]);

  function addFocusArea() {
    const label = newFocusArea.trim();
    if (!label || !form) return;
    if (form.focusAreas.some((f) => f.toLowerCase() === label.toLowerCase())) {
      setNewFocusArea("");
      return;
    }
    setForm({ ...form, focusAreas: [...form.focusAreas, label] });
    setNewFocusArea("");
  }

  function removeFocusArea(label: string) {
    if (!form) return;
    setForm({ ...form, focusAreas: form.focusAreas.filter((f) => f !== label) });
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    if (!activeTeamId || !form || !initialForm || !hasChanges) return;

    const payload: UpdateTeamSettingsRequest = { teamId: activeTeamId };

    if (form.name.trim() !== initialForm.name) {
      payload.name = form.name.trim();
    }
    if (form.sport.trim() !== initialForm.sport) {
      payload.sport = form.sport.trim();
    }
    if (form.seasonEndsAt !== initialForm.seasonEndsAt && form.seasonEndsAt) {
      payload.seasonEndsAt = form.seasonEndsAt;
    }

    const guidanceChanged =
      form.tone !== initialForm.tone ||
      form.notes !== initialForm.notes ||
      form.guidanceSeason !== initialForm.guidanceSeason ||
      JSON.stringify(form.focusAreas) !== JSON.stringify(initialForm.focusAreas) ||
      form.sport.trim() !== initialForm.sport;

    if (guidanceChanged && team) {
      const guidance: TeamGuidance = {
        sport: form.sport.trim() || team.guidance.sport,
        season: form.guidanceSeason,
        focusAreas: form.focusAreas,
        tone: form.tone,
        notes: form.notes,
      };
      payload.guidance = guidance;
    }

    setSaving(true);
    setSaveError(null);
    setSaveSuccess(false);
    try {
      await updateTeamSettingsCallable(payload);
      setSaveSuccess(true);
      await refresh();
    } catch (err) {
      setSaveError(formatCallableError(err));
    } finally {
      setSaving(false);
    }
  }

  if (!activeTeamId) {
    return (
      <EmptyState
        title="No team selected"
        subtitle="Choose or set up a team to edit its settings."
      />
    );
  }

  return (
    <div>
      <div>
        <p className="text-xs font-semibold uppercase tracking-[0.2em] text-primary">Settings</p>
        <h1 className="mt-2 font-display text-3xl font-bold text-text-primary">
          {activeTeam?.name ?? "Your team"}
        </h1>
        <p className="mt-2 text-sm text-text-secondary">
          Team details and the guidance that shapes AI-generated prompts.
        </p>
      </div>

      {teamError && (
        <div className="mt-6 rounded-xl border border-error/30 bg-error/10 px-4 py-3 text-sm text-error">
          {teamError}
        </div>
      )}

      {teamLoading || !form ? (
        <div className="flex justify-center py-16">
          <Spinner size={32} className="text-primary" />
        </div>
      ) : (
        <form onSubmit={handleSubmit}>
          <Card className="mt-8">
            <h2 className="font-display text-lg font-semibold text-text-primary">Team details</h2>
            <div className="mt-5 space-y-4">
              <Input
                label="Team name"
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
                disabled={saving}
              />
              <Input
                label="Sport"
                value={form.sport}
                onChange={(e) => setForm({ ...form, sport: e.target.value })}
                disabled={saving}
              />
              <Input
                label="Season end date"
                type="date"
                value={form.seasonEndsAt}
                onChange={(e) => setForm({ ...form, seasonEndsAt: e.target.value })}
                disabled={saving}
                hint="Players keep full app access through this date (inclusive)."
              />
            </div>
          </Card>

          <Card className="mt-6">
            <h2 className="font-display text-lg font-semibold text-text-primary">
              Prompt guidance
            </h2>
            <p className="mt-1 text-sm text-text-secondary">
              This is your main lever for generated prompts. Focus areas, tone, and notes are sent
              to Claude whenever you generate new prompts. Players are never forced to use the
              team prompt.
            </p>

            <div className="mt-5 space-y-4">
              <div>
                <p className="text-sm font-semibold text-text-primary">Focus areas</p>
                <p className="mt-1 text-xs text-text-secondary">
                  Topics you want prompts to emphasize (e.g. pre-game focus, recovery, leadership).
                </p>
                {form.focusAreas.length > 0 && (
                  <ul className="mt-3 flex flex-wrap gap-2">
                    {form.focusAreas.map((area) => (
                      <li
                        key={area}
                        className="inline-flex items-center gap-2 rounded-full border border-border bg-surface-elevated px-3 py-1.5 text-sm text-text-primary"
                      >
                        {area}
                        <button
                          type="button"
                          onClick={() => removeFocusArea(area)}
                          className="text-text-muted hover:text-error"
                          aria-label={`Remove ${area}`}
                          disabled={saving}
                        >
                          ✕
                        </button>
                      </li>
                    ))}
                  </ul>
                )}
                <div className="mt-3 flex gap-2">
                  <Input
                    value={newFocusArea}
                    onChange={(e) => setNewFocusArea(e.target.value)}
                    disabled={saving}
                    placeholder="Add a focus area"
                    className="flex-1"
                  />
                  <Button
                    type="button"
                    variant="secondary"
                    onClick={addFocusArea}
                    disabled={saving || !newFocusArea.trim()}
                  >
                    Add
                  </Button>
                </div>
              </div>

              <Input
                label="Tone"
                value={form.tone}
                onChange={(e) => setForm({ ...form, tone: e.target.value })}
                disabled={saving}
                placeholder="e.g. direct and encouraging"
                hint="How generated prompts should sound."
              />

              <Textarea
                label="Notes for the AI"
                value={form.notes}
                onChange={(e) => setForm({ ...form, notes: e.target.value })}
                disabled={saving}
                rows={4}
                placeholder="Anything else the prompt generator should know about your team or season."
              />
            </div>
          </Card>

          {saveError && (
            <div className="mt-4 rounded-xl border border-error/30 bg-error/10 px-4 py-3 text-sm text-error">
              {saveError}
            </div>
          )}

          {saveSuccess && (
            <div className="mt-4 rounded-xl border border-success/30 bg-success/10 px-4 py-3 text-sm text-success">
              Settings saved.
            </div>
          )}

          <div className="mt-6 flex justify-end">
            <Button type="submit" isLoading={saving} disabled={saving || !hasChanges}>
              Save changes
            </Button>
          </div>
        </form>
      )}
    </div>
  );
}

export default function SettingsPage() {
  return (
    <AuthGate>
      <SettingsPageContent />
    </AuthGate>
  );
}
