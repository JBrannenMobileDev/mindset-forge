"use client";

import Link from "next/link";
import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth-context";
import { formatAuthError } from "@/lib/errors";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { Input } from "@/components/ui/Input";

export default function LoginPage() {
  const router = useRouter();
  const { user, loading, login } = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (!loading && user) {
      router.replace("/dashboard");
    }
  }, [loading, user, router]);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    if (!email.trim() || !password) {
      setError("Enter your email and password.");
      return;
    }

    setSubmitting(true);
    try {
      await login(email.trim(), password);
      // AuthGate on /dashboard already handles an account with no coach or
      // analyst role, so there's nothing else to check here.
      router.replace("/dashboard");
    } catch (err) {
      setError(formatAuthError(err, "Sign in failed. Check your email and password."));
      setSubmitting(false);
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-background px-6">
      <div className="w-full max-w-md">
        <Card>
          <p className="text-xs font-semibold uppercase tracking-[0.2em] text-primary">
            MindsetForge
          </p>
          <h1 className="mt-3 font-display text-2xl font-bold text-text-primary">Coach portal</h1>
          <p className="mt-2 text-sm text-text-secondary">
            Sign in to manage your team, roster, and prompts.
          </p>

          <form onSubmit={handleSubmit} className="mt-8 space-y-4">
            <Input
              label="Email"
              type="email"
              autoComplete="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              disabled={submitting}
              required
            />
            <Input
              label="Password"
              type="password"
              autoComplete="current-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              disabled={submitting}
              required
            />
            {error && (
              <div className="rounded-xl border border-error/30 bg-error/10 px-4 py-3 text-sm text-error">
                {error}
              </div>
            )}
            <Button type="submit" className="w-full" isLoading={submitting} disabled={submitting}>
              Sign in
            </Button>
          </form>

          <p className="mt-6 text-center text-sm text-text-secondary">
            New coach?{" "}
            <Link href="/signup" className="font-semibold text-primary hover:underline">
              Create your team
            </Link>
          </p>
        </Card>
      </div>
    </main>
  );
}
