"use client";

import { useEffect, useMemo, useState } from "react";
import { collection, onSnapshot, orderBy, query } from "firebase/firestore";
import { AuthGate } from "@/components/AuthGate";
import { ConfirmDialog } from "@/components/ui/ConfirmDialog";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { EmptyState } from "@/components/ui/EmptyState";
import { Input, Textarea } from "@/components/ui/Input";
import { Spinner } from "@/components/ui/Spinner";
import { Table, TableBody, TableCell, TableHead, TableHeaderCell, TableRow } from "@/components/ui/Table";
import { useAuth } from "@/lib/auth-context";
import { createPlayerInvitesCallable, db, removePlayerCallable } from "@/lib/firebase";
import { formatDayKey } from "@/lib/date-utils";
import { formatCallableError } from "@/lib/errors";
import type { CreatedPlayerInvite, CreatePlayerInvitesResponse, RosterStatus, TeamRosterDoc } from "@/lib/types";
import { teamInviteLink } from "@/lib/types";

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

type DraftPlayer = { name: string; email: string };
type BulkLineError = { line: number; text: string; reason: string };

function parseBulkLines(text: string): { valid: DraftPlayer[]; errors: BulkLineError[] } {
  const valid: DraftPlayer[] = [];
  const errors: BulkLineError[] = [];
  const seen = new Set<string>();

  text.split(/\r?\n/).forEach((raw, idx) => {
    const line = raw.trim();
    if (!line) return;
    const commaIdx = line.indexOf(",");
    if (commaIdx === -1) {
      errors.push({ line: idx + 1, text: line, reason: 'Expected "Name, email"' });
      return;
    }
    const name = line.slice(0, commaIdx).trim();
    const email = line.slice(commaIdx + 1).trim().toLowerCase();
    if (!name) {
      errors.push({ line: idx + 1, text: line, reason: "Missing name" });
      return;
    }
    if (!EMAIL_PATTERN.test(email)) {
      errors.push({ line: idx + 1, text: line, reason: "Invalid email" });
      return;
    }
    if (seen.has(email)) {
      errors.push({ line: idx + 1, text: line, reason: "Duplicate email in this list" });
      return;
    }
    seen.add(email);
    valid.push({ name, email });
  });

  return { valid, errors };
}

function csvEscape(value: string): string {
  if (/[",\n]/.test(value)) {
    return `"${value.replace(/"/g, '""')}"`;
  }
  return value;
}

function downloadInvitesCsv(invites: CreatedPlayerInvite[]) {
  const rows = [
    "name,email,inviteLink",
    ...invites.map((inv) => [inv.name, inv.email, inv.inviteLink].map(csvEscape).join(",")),
  ];
  const blob = new Blob([rows.join("\n")], { type: "text/csv;charset=utf-8;" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = "roster-invites.csv";
  link.click();
  URL.revokeObjectURL(url);
}

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

function RosterPageContent() {
  const { activeTeamId, teams } = useAuth();
  const activeTeam = teams.find((t) => t.teamId === activeTeamId) ?? null;

  const [roster, setRoster] = useState<TeamRosterDoc[]>([]);
  const [rosterLoading, setRosterLoading] = useState(true);
  const [rosterError, setRosterError] = useState<string | null>(null);

  const [singleName, setSingleName] = useState("");
  const [singleEmail, setSingleEmail] = useState("");
  const [bulkText, setBulkText] = useState("");
  const [bulkErrors, setBulkErrors] = useState<BulkLineError[]>([]);
  const [draftPlayers, setDraftPlayers] = useState<DraftPlayer[]>([]);
  const [addError, setAddError] = useState<string | null>(null);
  const [sending, setSending] = useState(false);
  const [lastResult, setLastResult] = useState<CreatePlayerInvitesResponse | null>(null);
  const [copiedKey, setCopiedKey] = useState<string | null>(null);

  const [removeTarget, setRemoveTarget] = useState<TeamRosterDoc | null>(null);
  const [removing, setRemoving] = useState(false);
  const [removeError, setRemoveError] = useState<string | null>(null);

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

  const rosterEmails = useMemo(
    () => new Set(roster.map((r) => r.email.toLowerCase())),
    [roster],
  );

  function addToDraft(entries: DraftPlayer[]): string[] {
    const existing = new Set([
      ...draftPlayers.map((p) => p.email.toLowerCase()),
      ...rosterEmails,
    ]);
    const additions: DraftPlayer[] = [];
    const conflicts: string[] = [];
    for (const entry of entries) {
      const key = entry.email.toLowerCase();
      if (existing.has(key)) {
        conflicts.push(entry.email);
        continue;
      }
      existing.add(key);
      additions.push(entry);
    }
    if (additions.length > 0) {
      setDraftPlayers((prev) => [...prev, ...additions]);
    }
    return conflicts;
  }

  function handleAddSingle() {
    setAddError(null);
    const name = singleName.trim();
    const email = singleEmail.trim().toLowerCase();
    if (!name || !email) {
      setAddError("Enter a name and email.");
      return;
    }
    if (!EMAIL_PATTERN.test(email)) {
      setAddError("Enter a valid email address.");
      return;
    }
    const conflicts = addToDraft([{ name, email }]);
    if (conflicts.length > 0) {
      setAddError("That email is already on the roster or already in your list.");
      return;
    }
    setSingleName("");
    setSingleEmail("");
  }

  function handleParseBulk() {
    setAddError(null);
    const { valid, errors } = parseBulkLines(bulkText);
    setBulkErrors(errors);
    if (valid.length > 0) {
      const conflicts = addToDraft(valid);
      if (conflicts.length > 0) {
        setAddError(`Already on the roster or in your list, skipped: ${conflicts.join(", ")}`);
      }
      setBulkText("");
    }
  }

  function removeDraftRow(email: string) {
    setDraftPlayers((prev) => prev.filter((p) => p.email !== email));
  }

  async function handleSendInvites() {
    if (!activeTeamId || draftPlayers.length === 0) return;
    setSending(true);
    setAddError(null);
    try {
      const result = await createPlayerInvitesCallable({ teamId: activeTeamId, players: draftPlayers });
      setLastResult(result.data);
      setDraftPlayers([]);
      setBulkErrors([]);
    } catch (err) {
      setAddError(formatCallableError(err));
    } finally {
      setSending(false);
    }
  }

  async function copyToClipboard(key: string, text: string) {
    try {
      await navigator.clipboard.writeText(text);
      setCopiedKey(key);
      setTimeout(() => setCopiedKey((k) => (k === key ? null : k)), 2000);
    } catch {
      setAddError("Couldn't copy to the clipboard. Copy the link manually instead.");
    }
  }

  function copyAllLinks() {
    if (!lastResult) return;
    const text = lastResult.invites.map((inv) => `${inv.name}: ${inv.inviteLink}`).join("\n");
    copyToClipboard("__all__", text);
  }

  async function confirmRemove() {
    if (!removeTarget || !activeTeamId) return;
    setRemoving(true);
    setRemoveError(null);
    try {
      await removePlayerCallable({ teamId: activeTeamId, playerId: removeTarget.playerId });
      setRemoveTarget(null);
    } catch (err) {
      setRemoveError(formatCallableError(err));
    } finally {
      setRemoving(false);
    }
  }

  if (!activeTeamId) {
    return (
      <EmptyState
        title="No team selected"
        subtitle="Choose or set up a team to manage its roster."
      />
    );
  }

  return (
    <div>
      <div>
        <p className="text-xs font-semibold uppercase tracking-[0.2em] text-primary">Roster</p>
        <h1 className="mt-2 font-display text-3xl font-bold text-text-primary">
          {activeTeam?.name ?? "Your team"}
        </h1>
        <p className="mt-2 text-sm text-text-secondary">
          Invite players, share their links, and manage who is on the team.
        </p>
      </div>

      <Card className="mt-8">
        <h2 className="font-display text-lg font-semibold text-text-primary">Add players</h2>
        <p className="mt-1 text-sm text-text-secondary">
          Add one at a time or paste a list, then send invites together.
        </p>

        <div className="mt-5 grid gap-6 lg:grid-cols-2">
          <div>
            <p className="text-sm font-semibold text-text-primary">One at a time</p>
            <div className="mt-3 space-y-3">
              <Input
                label="Name"
                value={singleName}
                onChange={(e) => setSingleName(e.target.value)}
                disabled={sending}
              />
              <Input
                label="Email"
                type="email"
                value={singleEmail}
                onChange={(e) => setSingleEmail(e.target.value)}
                disabled={sending}
              />
              <Button variant="secondary" onClick={handleAddSingle} disabled={sending}>
                Add to list
              </Button>
            </div>
          </div>

          <div>
            <p className="text-sm font-semibold text-text-primary">Bulk paste</p>
            <div className="mt-3 space-y-3">
              <Textarea
                value={bulkText}
                onChange={(e) => setBulkText(e.target.value)}
                disabled={sending}
                rows={5}
                placeholder={"Jordan Smith, jordan@example.com\nCasey Lee, casey@example.com"}
                hint='One player per line: "Name, email"'
              />
              <Button variant="secondary" onClick={handleParseBulk} disabled={sending || !bulkText.trim()}>
                Parse list
              </Button>
              {bulkErrors.length > 0 && (
                <div className="rounded-xl border border-error/30 bg-error/10 px-4 py-3 text-xs text-error">
                  <p className="font-semibold">Some lines couldn&apos;t be added:</p>
                  <ul className="mt-1.5 list-disc space-y-1 pl-4">
                    {bulkErrors.map((e) => (
                      <li key={e.line}>
                        Line {e.line}: {e.reason} ({e.text || "empty"})
                      </li>
                    ))}
                  </ul>
                </div>
              )}
            </div>
          </div>
        </div>

        {draftPlayers.length > 0 && (
          <div className="mt-6 border-t border-border-subtle pt-6">
            <p className="text-sm font-semibold text-text-primary">
              Ready to invite ({draftPlayers.length})
            </p>
            <ul className="mt-3 space-y-2">
              {draftPlayers.map((p) => (
                <li
                  key={p.email}
                  className="flex items-center justify-between rounded-xl border border-border-subtle px-4 py-2.5 text-sm"
                >
                  <span className="text-text-primary">
                    {p.name} <span className="text-text-muted">{p.email}</span>
                  </span>
                  <button
                    type="button"
                    onClick={() => removeDraftRow(p.email)}
                    className="text-text-muted hover:text-error"
                    aria-label={`Remove ${p.name}`}
                  >
                    ✕
                  </button>
                </li>
              ))}
            </ul>
          </div>
        )}

        {addError && (
          <div className="mt-4 rounded-xl border border-error/30 bg-error/10 px-4 py-3 text-sm text-error">
            {addError}
          </div>
        )}

        <div className="mt-6 flex justify-end">
          <Button
            onClick={handleSendInvites}
            isLoading={sending}
            disabled={sending || draftPlayers.length === 0}
          >
            Send {draftPlayers.length > 0 ? draftPlayers.length : ""} invite
            {draftPlayers.length === 1 ? "" : "s"}
          </Button>
        </div>
      </Card>

      {lastResult && (
        <Card className="mt-6 border-primary/30 shadow-[0_0_36px_rgba(155,64,255,0.16)]">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <h2 className="font-display text-lg font-semibold text-text-primary">
                Invite links ready
              </h2>
              <p className="mt-1 text-sm text-text-secondary">
                Send each player their link. They only get this once, so copy it now.
              </p>
            </div>
            <div className="flex gap-3">
              <Button variant="secondary" size="sm" onClick={copyAllLinks}>
                {copiedKey === "__all__" ? "Copied!" : "Copy all"}
              </Button>
              <Button variant="secondary" size="sm" onClick={() => downloadInvitesCsv(lastResult.invites)}>
                Export CSV
              </Button>
              <Button variant="ghost" size="sm" onClick={() => setLastResult(null)}>
                Dismiss
              </Button>
            </div>
          </div>

          <div className="mt-5 overflow-hidden rounded-2xl border border-border">
            <table className="w-full text-left text-sm">
              <thead className="bg-surface-elevated text-text-secondary">
                <tr>
                  <th className="px-4 py-3 font-medium">Name</th>
                  <th className="px-4 py-3 font-medium">Email</th>
                  <th className="px-4 py-3 font-medium">Invite link</th>
                  <th className="px-4 py-3 font-medium"></th>
                </tr>
              </thead>
              <tbody className="bg-surface">
                {lastResult.invites.map((inv) => (
                  <tr key={inv.playerId} className="border-t border-border">
                    <td className="px-4 py-3 text-text-primary">{inv.name}</td>
                    <td className="px-4 py-3 text-text-muted">{inv.email}</td>
                    <td className="max-w-xs truncate px-4 py-3 text-text-secondary">
                      {inv.inviteLink}
                    </td>
                    <td className="px-4 py-3">
                      <Button
                        variant="secondary"
                        size="sm"
                        onClick={() => copyToClipboard(inv.playerId, inv.inviteLink)}
                      >
                        {copiedKey === inv.playerId ? "Copied!" : "Copy"}
                      </Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {lastResult.skipped.length > 0 && (
            <div className="mt-4 rounded-xl border border-warning/30 bg-warning/10 px-4 py-3 text-sm text-warning">
              <p className="font-semibold">Skipped (already on the roster):</p>
              <p className="mt-1">
                {lastResult.skipped.map((s) => `${s.name} (${s.email})`).join(", ")}
              </p>
            </div>
          )}
        </Card>
      )}

      <Card className="mt-8">
        <h2 className="font-display text-lg font-semibold text-text-primary">Players</h2>

        {rosterError && (
          <div className="mt-4 rounded-xl border border-error/30 bg-error/10 px-4 py-3 text-sm text-error">
            {rosterError}
          </div>
        )}

        {rosterLoading ? (
          <div className="flex justify-center py-10">
            <Spinner size={28} className="text-primary" />
          </div>
        ) : roster.length === 0 ? (
          <EmptyState
            className="mt-4"
            title="No players yet"
            subtitle="Add your first players above to generate their invite links."
          />
        ) : (
          <Table className="mt-4">
            <TableHead>
              <TableRow>
                <TableHeaderCell>Name</TableHeaderCell>
                <TableHeaderCell>Email</TableHeaderCell>
                <TableHeaderCell>Status</TableHeaderCell>
                <TableHeaderCell>Last entry</TableHeaderCell>
                <TableHeaderCell>Invite link</TableHeaderCell>
                <TableHeaderCell>{null}</TableHeaderCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {roster.map((player) => (
                <TableRow key={player.playerId}>
                  <TableCell>{player.name}</TableCell>
                  <TableCell className="text-text-muted">{player.email}</TableCell>
                  <TableCell>
                    <StatusBadge status={player.status} />
                  </TableCell>
                  <TableCell className="text-text-secondary">
                    {formatDayKey(player.lastEntryAt, "No entries yet")}
                  </TableCell>
                  <TableCell>
                    {player.status === "invited" ? (
                      <Button
                        variant="secondary"
                        size="sm"
                        onClick={() =>
                          copyToClipboard(`roster-${player.playerId}`, teamInviteLink(player.inviteId))
                        }
                      >
                        {copiedKey === `roster-${player.playerId}` ? "Copied!" : "Copy"}
                      </Button>
                    ) : (
                      <span className="text-text-muted">—</span>
                    )}
                  </TableCell>
                  <TableCell>
                    {player.status !== "removed" && (
                      <Button variant="danger" size="sm" onClick={() => setRemoveTarget(player)}>
                        Remove
                      </Button>
                    )}
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        )}
      </Card>

      <ConfirmDialog
        open={removeTarget !== null}
        title={`Remove ${removeTarget?.name ?? "this player"}?`}
        description={
          <>
            They&apos;ll stop receiving the team&apos;s daily prompts, but they keep their journal
            and their app access through the season end date. This does not delete anything
            they&apos;ve written.
          </>
        }
        confirmLabel="Remove player"
        danger
        isLoading={removing}
        error={removeError}
        onConfirm={confirmRemove}
        onCancel={() => {
          setRemoveTarget(null);
          setRemoveError(null);
        }}
      />
    </div>
  );
}

export default function RosterPage() {
  return (
    <AuthGate>
      <RosterPageContent />
    </AuthGate>
  );
}
