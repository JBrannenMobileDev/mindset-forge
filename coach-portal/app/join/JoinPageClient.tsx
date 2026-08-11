"use client";

import { FormEvent, ReactNode, useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import { FirebaseError } from "firebase/app";
import { createUserWithEmailAndPassword, signOut, updateProfile } from "firebase/auth";
import { auth, acceptTeamInviteCallable, getTeamInviteInfoCallable } from "@/lib/firebase";
import { formatAuthError } from "@/lib/errors";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { Input } from "@/components/ui/Input";
import { Spinner } from "@/components/ui/Spinner";
import type { GetTeamInviteInfoResponse } from "@/lib/types";

const MIN_PASSWORD_LENGTH = 8;

// Real store URLs, copied from ~/mindsetforge-web/lib/site.ts (a sibling repo
// this one can't import across the repo boundary). Keep in sync by hand.
const APP_STORE_URL = "https://apps.apple.com/app/id6784144678";
const PLAY_STORE_URL = "https://play.google.com/store/apps/details?id=com.mindsetforge.mindsetforge";
const DOWNLOAD_FALLBACK_URL = "https://mindsetforge.app/download";

/**
 * Static export serves this same file for every `/join/<inviteId>` URL (see
 * the firebase.json rewrite), so the id has to come from the browser's real
 * URL at runtime, not from Next's routing.
 */
function readInviteIdFromLocation(searchParamInvite: string | null): string | null {
  if (typeof window === "undefined") return searchParamInvite;
  const segments = window.location.pathname.split("/").filter(Boolean);
  const last = segments[segments.length - 1];
  const fromPath = last && last.toLowerCase() !== "join" ? last : null;
  return fromPath ?? searchParamInvite;
}

type Stage = "resolving" | "loading" | "invalid" | "unavailable" | "ready" | "done";

export default function JoinPageClient() {
  const searchParams = useSearchParams();
  const [inviteId, setInviteId] = useState<string | null>(null);
  const [stage, setStage] = useState<Stage>("resolving");
  const [invite, setInvite] = useState<GetTeamInviteInfoResponse | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [teamNameOnDone, setTeamNameOnDone] = useState("");

  const [name, setName] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [formError, setFormError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    const id = readInviteIdFromLocation(searchParams.get("invite"));
    setInviteId(id);
    if (!id) {
      setStage("invalid");
    }
  }, [searchParams]);

  useEffect(() => {
    if (!inviteId) return;
    let cancelled = false;
    setStage("loading");
    getTeamInviteInfoCallable({ inviteId })
      .then((result) => {
        if (cancelled) return;
        const data = result.data;
        setInvite(data);
        setName(data.playerName);
        setStage(data.status === "pending" ? "ready" : "unavailable");
      })
      .catch((err) => {
        if (cancelled) return;
        setLoadError(
          err instanceof FirebaseError && err.code === "functions/not-found"
            ? "We couldn't find this invite. Double check the link your coach sent you, or ask them to resend it."
            : formatAuthError(err, "We couldn't load this invite. Please try again."),
        );
        setStage("invalid");
      });
    return () => {
      cancelled = true;
    };
  }, [inviteId]);

  function validate(): string | null {
    if (!name.trim()) return "Enter your name.";
    if (password.length < MIN_PASSWORD_LENGTH) {
      return `Password must be at least ${MIN_PASSWORD_LENGTH} characters.`;
    }
    if (password !== confirmPassword) return "Passwords don't match.";
    return null;
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    if (!invite || !inviteId) return;
    setFormError(null);
    const validationError = validate();
    if (validationError) {
      setFormError(validationError);
      return;
    }

    setSubmitting(true);
    try {
      const alreadySignedIn =
        !!auth.currentUser &&
        auth.currentUser.email?.toLowerCase() === invite.playerEmail.toLowerCase();

      if (!alreadySignedIn) {
        if (auth.currentUser) {
          await signOut(auth);
        }
        try {
          const credential = await createUserWithEmailAndPassword(
            auth,
            invite.playerEmail,
            password,
          );
          if (name.trim()) {
            // Best-effort only: acceptTeamInvite always stores the coach's
            // roster name on the user doc, so this just keeps the Auth
            // record itself consistent with what the player typed.
            await updateProfile(credential.user, { displayName: name.trim() }).catch(() => {});
          }
        } catch (err) {
          setFormError(formatAuthError(err, "Could not create your account."));
          setSubmitting(false);
          return;
        }
      }

      // The Auth account now definitely exists. If acceptTeamInvite fails
      // here, the player is left signed in with an account but no team.
      // Retrying re-enters this function, `alreadySignedIn` is now true
      // (same email), and we skip straight to calling acceptTeamInvite again
      // instead of trying to create the account a second time.
      try {
        const result = await acceptTeamInviteCallable({ inviteId });
        setTeamNameOnDone(result.data.teamName);
      } catch (err) {
        if (err instanceof FirebaseError && err.code === "functions/failed-precondition") {
          setFormError(
            "This invite has already been used. If that was you, just sign in on the app with your email and password.",
          );
          setSubmitting(false);
          return;
        }
        setFormError(formatAuthError(err));
        setSubmitting(false);
        return;
      }

      setStage("done");
    } catch (err) {
      setFormError(formatAuthError(err));
      setSubmitting(false);
    }
  }

  if (stage === "resolving" || stage === "loading") {
    return (
      <JoinShell>
        <div className="flex justify-center py-10">
          <Spinner size={28} className="text-primary" />
        </div>
      </JoinShell>
    );
  }

  if (stage === "invalid") {
    return (
      <JoinShell>
        <h1 className="font-display text-xl font-bold text-text-primary">Invite not found</h1>
        <p className="mt-3 text-sm text-text-secondary">
          {loadError ?? "This invite link looks incomplete. Ask your coach to resend it."}
        </p>
      </JoinShell>
    );
  }

  if (stage === "unavailable" && invite) {
    const message =
      invite.status === "accepted"
        ? "This invite has already been used. If that was you, download the app and sign in with the email and password you set."
        : "This invite is no longer active. Ask your coach for a new one.";
    return (
      <JoinShell>
        <h1 className="font-display text-xl font-bold text-text-primary">{invite.teamName}</h1>
        <p className="mt-1 text-sm text-text-secondary">Coach {invite.coachName}</p>
        <p className="mt-4 text-sm text-text-secondary">{message}</p>
      </JoinShell>
    );
  }

  if (stage === "done") {
    return (
      <JoinShell>
        <h1 className="font-display text-2xl font-bold text-text-primary">
          Welcome to {teamNameOnDone || invite?.teamName}
        </h1>
        <p className="mt-3 text-sm text-text-secondary">
          Your account is ready. Download the MindsetForge app and sign in with the email and
          password you just set.
        </p>
        <div className="mt-6 flex flex-col gap-3 sm:flex-row">
          <a
            href={APP_STORE_URL}
            target="_blank"
            rel="noreferrer noopener"
            className="flex-1 rounded-xl border border-border bg-surface-highest px-4 py-3 text-center text-sm font-semibold text-text-primary transition-colors hover:border-primary/50"
          >
            Download for iPhone
          </a>
          <a
            href={PLAY_STORE_URL}
            target="_blank"
            rel="noreferrer noopener"
            className="flex-1 rounded-xl border border-border bg-surface-highest px-4 py-3 text-center text-sm font-semibold text-text-primary transition-colors hover:border-primary/50"
          >
            Download for Android
          </a>
        </div>
        <p className="mt-4 text-center text-xs text-text-muted">
          Having trouble?{" "}
          <a href={DOWNLOAD_FALLBACK_URL} className="text-primary hover:underline">
            Get the app here
          </a>
          .
        </p>
        <div className="mt-6 rounded-xl border border-border-subtle bg-background px-4 py-3 text-xs text-text-secondary">
          Your coach sees short summaries and themes from your journal entries, never the actual
          words you write.
        </div>
      </JoinShell>
    );
  }

  if (!invite) return null;

  return (
    <JoinShell>
      <p className="text-xs font-semibold uppercase tracking-[0.2em] text-primary">
        You&apos;re invited
      </p>
      <h1 className="mt-2 font-display text-2xl font-bold text-text-primary">{invite.teamName}</h1>
      <p className="mt-1 text-sm text-text-secondary">
        Coach {invite.coachName} added you as {invite.playerName}.
      </p>
      <p className="mt-4 text-sm text-text-secondary">
        Set a password to finish creating your account. Your coach will see short summaries and
        themes from your journal entries, never the words you actually write.
      </p>

      <form onSubmit={handleSubmit} className="mt-6 space-y-4">
        <Input label="Email" value={invite.playerEmail} disabled readOnly />
        <Input
          label="Your name"
          value={name}
          onChange={(e) => setName(e.target.value)}
          disabled={submitting}
          required
        />
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
        {formError && (
          <div className="rounded-xl border border-error/30 bg-error/10 px-4 py-3 text-sm text-error">
            {formError}
          </div>
        )}
        <Button type="submit" className="w-full" isLoading={submitting} disabled={submitting}>
          Create my account
        </Button>
      </form>
    </JoinShell>
  );
}

function JoinShell({ children }: { children: ReactNode }) {
  return (
    <main className="flex min-h-screen items-center justify-center bg-background px-6 py-12">
      <div className="w-full max-w-md">
        <Card>{children}</Card>
      </div>
    </main>
  );
}
