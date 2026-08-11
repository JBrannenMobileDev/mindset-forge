"use client";

import Link from "next/link";
import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { FirebaseError } from "firebase/app";
import { createUserWithEmailAndPassword, signOut } from "firebase/auth";
import { auth, initializeCoachAccountCallable } from "@/lib/firebase";
import { useAuth } from "@/lib/auth-context";
import { formatAuthError } from "@/lib/errors";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { Input } from "@/components/ui/Input";

const MIN_PASSWORD_LENGTH = 8;

export default function SignupPage() {
  const router = useRouter();
  const { user, role, loading, refresh } = useAuth();

  const [accessCode, setAccessCode] = useState("");
  const [coachName, setCoachName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [teamName, setTeamName] = useState("");
  const [sport, setSport] = useState("");
  const [seasonEndsAt, setSeasonEndsAt] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  // Already owns a team (a normal revisit, or the callable finally succeeded
  // here on an earlier attempt): skip straight to the dashboard.
  useEffect(() => {
    if (!loading && user && role === "coach") {
      router.replace("/dashboard");
    }
  }, [loading, user, role, router]);

  // Signed in but with no team: the Auth account survived a previous attempt
  // where initializeCoachAccount failed partway through. Resuming means
  // calling the callable again without recreating the Auth account.
  const resuming = !loading && !!user && role === null;

  useEffect(() => {
    if (resuming && user?.email) {
      setEmail(user.email);
    }
  }, [resuming, user]);

  function validate(): string | null {
    if (!accessCode.trim()) return "Enter the access code your program gave you.";
    if (!coachName.trim()) return "Enter your name.";
    if (!teamName.trim()) return "Enter your team's name.";
    if (!sport.trim()) return "Enter your sport.";
    if (!seasonEndsAt) return "Choose when your season ends.";
    if (!resuming) {
      if (!email.trim()) return "Enter your email.";
      if (password.length < MIN_PASSWORD_LENGTH) {
        return `Password must be at least ${MIN_PASSWORD_LENGTH} characters.`;
      }
      if (password !== confirmPassword) return "Passwords don't match.";
    }
    return null;
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    const validationError = validate();
    if (validationError) {
      setError(validationError);
      return;
    }

    setSubmitting(true);
    try {
      if (!resuming) {
        // Fresh signup. If a stale/unrelated session is active, drop it so
        // the account we create matches the email typed in this form.
        if (auth.currentUser && auth.currentUser.email?.toLowerCase() !== email.trim().toLowerCase()) {
          await signOut(auth);
        }
        if (!auth.currentUser) {
          try {
            await createUserWithEmailAndPassword(auth, email.trim(), password);
          } catch (err) {
            setError(formatAuthError(err, "Could not create your account."));
            setSubmitting(false);
            return;
          }
        }
      }

      // The Auth account definitely exists now, either just created or
      // carried over from a previous attempt. If this call fails, the
      // account is left signed in with no team; `resuming` becomes true on
      // the next render, so retrying calls this same callable again instead
      // of trying to create the account a second time.
      try {
        await initializeCoachAccountCallable({
          accessCode: accessCode.trim(),
          coachName: coachName.trim(),
          teamName: teamName.trim(),
          sport: sport.trim(),
          seasonEndsAt,
        });
      } catch (err) {
        if (err instanceof FirebaseError && err.code === "functions/already-exists") {
          await refresh();
          router.replace("/dashboard");
          return;
        }
        setError(formatAuthError(err));
        setSubmitting(false);
        return;
      }

      await refresh();
      router.replace("/dashboard");
    } catch (err) {
      setError(formatAuthError(err));
      setSubmitting(false);
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-background px-6 py-12">
      <div className="w-full max-w-lg">
        <Card>
          <p className="text-xs font-semibold uppercase tracking-[0.2em] text-primary">
            MindsetForge
          </p>
          <h1 className="mt-3 font-display text-2xl font-bold text-text-primary">
            Set up your team
          </h1>
          <p className="mt-2 text-sm text-text-secondary">
            You&apos;ll need an access code from MindsetForge to create a coach account.
          </p>

          {resuming && (
            <div className="mt-4 rounded-xl border border-warning/30 bg-warning/10 px-4 py-3 text-sm text-warning">
              You&apos;re signed in as {user?.email}. Your account was created, but your team
              wasn&apos;t finished setting up. Fill in the rest below to continue.
            </div>
          )}

          <form onSubmit={handleSubmit} className="mt-6 space-y-6">
            <div className="space-y-4">
              <h2 className="text-sm font-semibold text-text-primary">Access</h2>
              <Input
                label="Access code"
                value={accessCode}
                onChange={(e) => setAccessCode(e.target.value)}
                disabled={submitting}
                placeholder="Provided by MindsetForge"
                required
              />
            </div>

            <div className="space-y-4 border-t border-border-subtle pt-6">
              <h2 className="text-sm font-semibold text-text-primary">Your account</h2>
              <Input
                label="Your name"
                value={coachName}
                onChange={(e) => setCoachName(e.target.value)}
                disabled={submitting}
                required
              />
              <Input
                label="Email"
                type="email"
                autoComplete="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                disabled={submitting || resuming}
                required
              />
              {!resuming && (
                <>
                  <Input
                    label="Password"
                    type="password"
                    autoComplete="new-password"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    disabled={submitting}
                    hint={`At least ${MIN_PASSWORD_LENGTH} characters.`}
                    required
                  />
                  <Input
                    label="Confirm password"
                    type="password"
                    autoComplete="new-password"
                    value={confirmPassword}
                    onChange={(e) => setConfirmPassword(e.target.value)}
                    disabled={submitting}
                    required
                  />
                </>
              )}
            </div>

            <div className="space-y-4 border-t border-border-subtle pt-6">
              <h2 className="text-sm font-semibold text-text-primary">Your team</h2>
              <Input
                label="Team name"
                value={teamName}
                onChange={(e) => setTeamName(e.target.value)}
                disabled={submitting}
                required
              />
              <Input
                label="Sport"
                value={sport}
                onChange={(e) => setSport(e.target.value)}
                disabled={submitting}
                required
              />
              <Input
                label="Season end date"
                type="date"
                value={seasonEndsAt}
                onChange={(e) => setSeasonEndsAt(e.target.value)}
                disabled={submitting}
                hint="Players get full, comped access through this date. It expires automatically after."
                required
              />
            </div>

            {error && (
              <div className="rounded-xl border border-error/30 bg-error/10 px-4 py-3 text-sm text-error">
                {error}
              </div>
            )}

            <Button type="submit" className="w-full" isLoading={submitting} disabled={submitting}>
              {resuming ? "Finish setting up my team" : "Create my team"}
            </Button>
          </form>

          <p className="mt-6 text-center text-sm text-text-secondary">
            Already have a team?{" "}
            <Link href="/login" className="font-semibold text-primary hover:underline">
              Sign in
            </Link>
          </p>
        </Card>
      </div>
    </main>
  );
}
