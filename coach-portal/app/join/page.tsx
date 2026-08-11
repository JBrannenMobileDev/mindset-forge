import { Suspense } from "react";
import JoinPageClient from "./JoinPageClient";

/**
 * Player-facing invite acceptance page. Deliberately NOT wrapped in AppShell
 * or AuthGate: the player is never signed in when they land here.
 *
 * `output: "export"` can't prerender a dynamic `/join/[inviteId]` route, so
 * this is the one static page for every invite link. JoinPageClient reads
 * the invite id from the browser's actual URL at runtime; see firebase.json
 * for the hosting rewrite that routes `/join/<id>` here.
 */
export default function JoinPage() {
  return (
    <Suspense
      fallback={
        <main className="flex min-h-screen items-center justify-center bg-background text-text-secondary">
          Loading…
        </main>
      }
    >
      <JoinPageClient />
    </Suspense>
  );
}
