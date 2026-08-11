"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { ReactNode, useState } from "react";
import { useAuth } from "@/lib/auth-context";
import { Button } from "@/components/ui/Button";

const BASE_NAV_ITEMS = [
  { href: "/dashboard", label: "Dashboard" },
  { href: "/prompts", label: "Prompts" },
  { href: "/schedule", label: "Schedule" },
  { href: "/roster", label: "Roster" },
  { href: "/insights", label: "Insights" },
  { href: "/settings", label: "Settings" },
];

const ANALYST_NAV_ITEM = { href: "/teams", label: "Teams" };

function isActivePath(pathname: string, href: string): boolean {
  if (pathname === href) return true;
  if (href === "/roster" && pathname === "/players") return true;
  return pathname.startsWith(`${href}/`);
}

export function AppShell({ children }: { children: ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const { role, teams, activeTeamId, setActiveTeamId, logout } = useAuth();
  const [switcherOpen, setSwitcherOpen] = useState(false);

  const activeTeam = teams.find((t) => t.teamId === activeTeamId) ?? null;
  const showSwitcher = (role === "analyst" || teams.length > 1) && teams.length > 0;
  const navItems =
    role === "analyst" ? [...BASE_NAV_ITEMS, ANALYST_NAV_ITEM] : BASE_NAV_ITEMS;

  async function handleSignOut() {
    setSwitcherOpen(false);
    await logout();
    router.replace("/login");
  }

  return (
    <div className="flex min-h-screen bg-background">
      <aside className="hidden w-64 flex-col border-r border-border bg-surface px-4 py-6 md:flex">
        <div className="px-2">
          <p className="font-display text-lg font-bold text-text-primary">MindsetForge</p>
          <p className="text-xs font-semibold uppercase tracking-[0.2em] text-primary">
            Coach Portal
          </p>
        </div>
        <nav className="mt-8 flex flex-1 flex-col gap-1">
          {navItems.map((item) => {
            const active = isActivePath(pathname, item.href);
            return (
              <Link
                key={item.href}
                href={item.href}
                className={`rounded-xl px-3 py-2.5 text-sm font-semibold transition-colors ${
                  active
                    ? "bg-primary-container text-primary"
                    : "text-text-secondary hover:bg-surface-elevated hover:text-text-primary"
                }`}
              >
                {item.label}
              </Link>
            );
          })}
        </nav>
        <div className="mt-auto border-t border-border-subtle pt-4">
          <p className="px-2 text-xs text-text-muted">
            {role === "analyst" ? "Analyst" : "Coach"}
          </p>
        </div>
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="flex flex-wrap items-center justify-between gap-3 border-b border-border bg-surface px-6 py-4">
          <div className="min-w-0">
            <p className="truncate font-display text-base font-semibold text-text-primary">
              {activeTeam?.name ?? "No team yet"}
            </p>
            {activeTeam && <p className="text-xs text-text-secondary">{activeTeam.sport}</p>}
          </div>

          <div className="flex items-center gap-3">
            {showSwitcher && (
              <div className="relative">
                <button
                  type="button"
                  onClick={() => setSwitcherOpen((open) => !open)}
                  className="flex items-center gap-2 rounded-xl border border-border bg-surface-elevated px-3 py-2 text-sm text-text-primary transition-colors hover:border-primary/50"
                >
                  Switch team
                  <span aria-hidden>▾</span>
                </button>
                {switcherOpen && (
                  <>
                    <div
                      className="fixed inset-0 z-10"
                      onClick={() => setSwitcherOpen(false)}
                      aria-hidden
                    />
                    <div className="absolute right-0 z-20 mt-2 w-64 rounded-xl border border-border bg-surface-elevated p-1 shadow-2xl">
                      {teams.map((team) => (
                        <button
                          key={team.teamId}
                          type="button"
                          onClick={() => {
                            setActiveTeamId(team.teamId);
                            setSwitcherOpen(false);
                          }}
                          className={`block w-full rounded-lg px-3 py-2 text-left text-sm ${
                            team.teamId === activeTeamId
                              ? "bg-primary-container text-primary"
                              : "text-text-secondary hover:bg-surface-highest hover:text-text-primary"
                          }`}
                        >
                          {team.name}
                          <span className="ml-2 text-xs text-text-muted">{team.sport}</span>
                        </button>
                      ))}
                    </div>
                  </>
                )}
              </div>
            )}
            <Button variant="secondary" size="sm" onClick={handleSignOut}>
              Sign out
            </Button>
          </div>
        </header>

        <div className="border-b border-border bg-surface px-4 py-2 md:hidden">
          <nav className="flex gap-2 overflow-x-auto">
            {navItems.map((item) => {
              const active = isActivePath(pathname, item.href);
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className={`whitespace-nowrap rounded-lg px-3 py-1.5 text-sm font-semibold ${
                    active
                      ? "bg-primary-container text-primary"
                      : "text-text-secondary hover:text-text-primary"
                  }`}
                >
                  {item.label}
                </Link>
              );
            })}
          </nav>
        </div>

        <main className="flex-1 px-6 py-8">
          <div className="mx-auto max-w-5xl">{children}</div>
        </main>
      </div>
    </div>
  );
}
