"use client";

import { useRouter } from "next/navigation";
import { AuthGate } from "@/components/AuthGate";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { EmptyState } from "@/components/ui/EmptyState";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeaderCell,
  TableRow,
} from "@/components/ui/Table";
import { useAuth } from "@/lib/auth-context";
import { formatDayKey } from "@/lib/date-utils";

function TeamsPageContent() {
  const router = useRouter();
  const { role, teams, activeTeamId, setActiveTeamId } = useAuth();

  if (role !== "analyst") {
    return (
      <EmptyState
        title="Not available"
        subtitle="The teams overview is only available to analyst accounts."
        action={
          <Button href="/dashboard" variant="secondary">
            Back to dashboard
          </Button>
        }
      />
    );
  }

  function selectTeam(teamId: string) {
    setActiveTeamId(teamId);
    router.push("/dashboard");
  }

  return (
    <div>
      <div>
        <p className="text-xs font-semibold uppercase tracking-[0.2em] text-primary">Teams</p>
        <h1 className="mt-2 font-display text-3xl font-bold text-text-primary">All teams</h1>
        <p className="mt-2 text-sm text-text-secondary">
          Switch the active team to view its dashboard, roster, and insights.
        </p>
      </div>

      <Card className="mt-8">
        {teams.length === 0 ? (
          <EmptyState title="No teams" subtitle="No teams are linked to this analyst account." />
        ) : (
          <Table>
            <TableHead>
              <TableRow>
                <TableHeaderCell>Name</TableHeaderCell>
                <TableHeaderCell>Sport</TableHeaderCell>
                <TableHeaderCell>Players</TableHeaderCell>
                <TableHeaderCell>Season ends</TableHeaderCell>
                <TableHeaderCell>{null}</TableHeaderCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {teams.map((team) => {
                const isActive = team.teamId === activeTeamId;
                return (
                  <TableRow key={team.teamId} className={isActive ? "bg-primary-container/30" : undefined}>
                    <TableCell className="font-semibold">{team.name}</TableCell>
                    <TableCell className="text-text-muted">{team.sport}</TableCell>
                    <TableCell className="text-text-secondary">
                      {team.activeCount} active / {team.playerCount} total
                    </TableCell>
                    <TableCell className="text-text-secondary">
                      {formatDayKey(team.seasonEndsAt.slice(0, 10))}
                    </TableCell>
                    <TableCell>
                      {isActive ? (
                        <span className="text-xs font-semibold text-primary">Active</span>
                      ) : (
                        <Button size="sm" variant="secondary" onClick={() => selectTeam(team.teamId)}>
                          Make active
                        </Button>
                      )}
                    </TableCell>
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        )}
      </Card>
    </div>
  );
}

export default function TeamsPage() {
  return (
    <AuthGate>
      <TeamsPageContent />
    </AuthGate>
  );
}
