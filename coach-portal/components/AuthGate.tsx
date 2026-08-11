"use client";

import { useEffect, type ReactNode } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth-context";
import { AppShell } from "@/components/AppShell";
import { Button } from "@/components/ui/Button";
import { Spinner } from "@/components/ui/Spinner";

/**
 * Single place that handles the loading / signed-out / wrong-role states for
 * every authenticated page, so pages themselves only render their content.
 *
 * Usage: wrap a page's content in <AuthGate>...</AuthGate>. AuthGate renders
 * AppShell (sidebar + header) once the user is signed in with a coach or
 * analyst role, so pages never wrap themselves in AppShell directly.
 */
export function AuthGate({ children }: { children: ReactNode }) {
  const router = useRouter();
  const { user, role, loading, error, logout, refresh } = useAuth();

  useEffect(() => {
    if (loading) return;
    if (!user) {
      router.replace("/login");
    }
  }, [user, loading, router]);

  if (loading) {
    return (
      <main className="flex min-h-screen items-center justify-center bg-background">
        <Spinner size={32} className="text-primary" />
      </main>
    );
  }

  if (!user) {
    // The redirect above is already in flight; render a lightweight
    // placeholder instead of flashing protected content.
    return (
      <main className="flex min-h-screen items-center justify-center bg-background text-text-secondary">
        Redirecting to sign in…
      </main>
    );
  }

  if (!role) {
    return (
      <main className="flex min-h-screen flex-col items-center justify-center gap-4 bg-background px-6 text-center">
        <h1 className="font-display text-xl font-semibold text-text-primary">
          No coach access on this account
        </h1>
        <p className="max-w-sm text-sm text-text-secondary">
          {error ?? "This account isn't set up as a coach or analyst yet. Sign in with a coach account, or contact your program to get access."}
        </p>
        <div className="mt-2 flex gap-3">
          <Button variant="secondary" onClick={() => refresh()}>
            Try again
          </Button>
          <Button variant="ghost" onClick={() => logout()}>
            Sign out
          </Button>
        </div>
      </main>
    );
  }

  return <AppShell>{children}</AppShell>;
}
