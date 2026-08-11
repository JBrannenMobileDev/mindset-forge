# Coach Portal Deployment Runbook

Everything needed to take the coach portal from "builds locally" to "a real
coach and real athletes are using it." Follow the steps in order. Each step
says whether it is safe, risky, or irreversible.

**Firebase project:** `mindsetforge-ai` (one project, several hosting sites).
**New hosting site:** `coach-portal-mindset` → `coach.mindsetforge.app`.

Read the risk summary before you start.

## Risk summary

| Step | Risk | Why |
|---|---|---|
| 1. Move the repo | Safe | Directory move plus `git init`. No code changes. |
| 2. Pre-flight builds | Safe | Read-only. |
| 3. Deploy Firestore indexes | Low, but **additive-only in practice** | Building an index is safe; the CLI may offer to **delete** indexes missing from the file. Never accept that. |
| 4. Deploy Firestore rules | **RISKY — affects the live app** | The ruleset is replaced atomically for every existing user. Verify before deploying. |
| 5. Deploy Cloud Functions | Moderate | Adds `onJournalEntryCreated`, which fires on **every** journal write by **every** user, including users with no team. |
| 6. Seed `app_config/roles` | **Irreversible in effect** | A leaked signup code mints free coach accounts. Codes are multi-use and are never marked consumed. |
| 7. Create the hosting site | **Irreversible** | A Firebase Hosting site name cannot be renamed or reused after deletion. Get `coach-portal-mindset` right the first time. |
| 8. Deploy the portal | Safe | Rollback is one click in the Hosting console. |
| 9. Attach the custom domain | **Risky if you pick the wrong site** | Attaching a domain to the wrong site has broken this project's apex domain before. |
| 10. Pilot end-to-end test | Safe | Do this on a throwaway team before real athletes. |

---

## 1. Move the repo out of the Flutter workspace

The portal currently lives at `~/MindsetForge/coach-portal`, nested inside the
Flutter repo. That was a sandbox restriction during the build, not a design
decision, and it should not ship that way: a stray `git add` in the Flutter repo
would commit an entire second application into it.

It belongs at `~/mindsetforge-coach`, as a sibling of `~/mindsetforge-web` and
`~/mindsetforge-admin`. It is genuinely self-contained: its own `package.json`,
`tsconfig.json`, `.gitignore` (covering `node_modules/`, `.next/`, `out/`, and
`.firebase/`), `firebase.json` pinned to `coach-portal-mindset`, and `.firebaserc`
pinned to `mindsetforge-ai`. Nothing in it resolves a path outside its own
directory; the only mentions of sibling repos are in comments.

```bash
mv ~/MindsetForge/coach-portal ~/mindsetforge-coach
cd ~/mindsetforge-coach
rm -rf node_modules .next out          # rebuild fresh in the new location
npm install
npm run build
git init && git add -A && git commit -m "Coach portal: initial commit"
```

Then confirm `~/MindsetForge/coach-portal` no longer exists and that
`git status` in `~/MindsetForge` no longer lists it.

Every path in the rest of this document assumes the portal is at
`~/mindsetforge-coach` and the Flutter/Functions repo is at `~/MindsetForge`.

---

## 2. Pre-flight: everything must build before anything is deployed

```bash
cd ~/MindsetForge && flutter analyze && flutter test
cd ~/MindsetForge/functions && node node_modules/typescript/bin/tsc --noEmit
cd ~/mindsetforge-coach && npm run build
```

Known pre-existing failures at the time of writing, unrelated to this feature:
two tests in `test/providers/goals_notifier_test.dart`, one
`prefer_const_constructors` info in `new_journal_entry_screen.dart`, and one
`unused_element_parameter` warning in `dashboard_header.dart`. Anything beyond
those is new and should be fixed before deploying.

Confirm the Firebase CLI is authenticated against the right project:

```bash
firebase login
firebase use mindsetforge-ai
firebase projects:list
```

---

## 3. Deploy Firestore indexes (do this before rules)

Indexes first, because building them is asynchronous and the portal's queries
fail until they are `Enabled`. Deploying them early costs nothing and changes no
existing behavior.

```bash
cd ~/MindsetForge
firebase deploy --only firestore:indexes
```

Two new composite indexes on `team_entry_summaries` are required:

- `teamId` ASC, `date` DESC — the dashboard's recent-entries and mood queries
- `teamId` ASC, `playerUid` ASC, `date` DESC — the per-player timeline

> ⚠️ If the CLI asks whether to **delete** indexes that exist in the project but
> are not in `firestore.indexes.json`, answer **no**. Deleting a live index
> breaks whatever query depends on it, and rebuilding a large one takes hours.

Wait for both to show **Enabled** at
https://console.firebase.google.com/project/mindsetforge-ai/firestore/indexes
before moving on.

---

## 4. Deploy Firestore rules — RISKY, this affects the live app

`firestore.rules` is a single file for the entire project. Deploying it replaces
the ruleset for **every existing MindsetForge user**, not just coach-portal
users. A mistake here can lock real users out of their own data.

**Verify first, in the Rules Playground** (Firestore → Rules → Playground) or
with the emulator. At minimum confirm all of the following:

1. A normal signed-in user can still read and write `users/{ownUid}` and their
   own `journals` documents. This is the regression that would matter most.
2. A coach uid **cannot** read a player's `journals` document. This is the
   central promise of the product; test it explicitly, not by inspection.
3. A coach can read `team_entry_summaries` where `teamId` is their team, and
   cannot read one belonging to another team.
4. A player in `memberUids` can read `teams/{teamId}/schedule/{date}` and
   **cannot** read `teams/{teamId}`, `.../roster/*`, `.../prompts/*`, or
   `.../reports/*`.
5. Nobody can read `app_config/roles` or `team_invites/*` from a client.
6. Every `teams/**` and `team_entry_summaries` write is denied, including for
   the coach. All mutations go through callables.

Also confirm the file still contains the `blog_seeds` rule. That rule arrived as
an uncommitted change alongside this work, and dropping it would break the blog
admin console.

```bash
cd ~/MindsetForge
firebase deploy --only firestore:rules
```

Rollback: the previous ruleset is kept in the Rules tab's version history and can
be republished from the console in seconds. Know where that button is *before*
you deploy.

---

## 5. Deploy Cloud Functions

```bash
cd ~/MindsetForge
firebase deploy --only functions:getCoachContext,functions:initializeCoachAccount,functions:createPlayerInvites,functions:getTeamInviteInfo,functions:acceptTeamInvite,functions:generateTeamPrompts,functions:addManualPrompt,functions:deletePrompt,functions:assignTeamPrompt,functions:unassignTeamPrompt,functions:removePlayer,functions:updateTeamSettings,functions:onJournalEntryCreated,functions:weeklyTeamReport,functions:generateTeamReport
```

Deploying the named functions rather than `--only functions` avoids
redeploying every unrelated function in the project.

Notes:

- `ANTHROPIC_API_KEY` already exists in Secret Manager and is used by existing
  functions. `generateTeamPrompts`, `onJournalEntryCreated`, `weeklyTeamReport`,
  and `generateTeamReport` bind it via `defineSecret`; the deploy grants access
  automatically. If the deploy prompts about the secret, allow it.
- **`onJournalEntryCreated` fires for every journal entry written by every user
  of the app**, team or not. For a user with no `teamId` it does one projected
  read of three fields and returns, with no Claude call and no writes. That is
  the intended cost, but it is a new per-entry cost on the busiest write path in
  the product, so watch the functions dashboard for the first day.
- The trigger is wrapped so it can never throw. A failure there produces a
  missing summary row for the coach, never a failed journal save for the player.
- `weeklyTeamReport` is scheduled for Sunday 18:00 UTC. Deploying creates the
  Cloud Scheduler job; it will not fire immediately.

Verify with a tail of the logs after the first real journal entry:

```bash
firebase functions:log --only onJournalEntryCreated
```

Log lines carry team ids and error class names only. If you ever see journal
text in these logs, stop and treat it as an incident.

---

## 6. Seed `app_config/roles`

This document holds `analystUids` (super-admin read access to every team) and
`coachSignupCodes` (what `initializeCoachAccount` validates). Both are denied to
clients in `firestore.rules`, so this is a server-side write only.

```bash
# Create the analyst Firebase Auth user first, then copy its UID from
# Firebase Console -> Authentication.
cd ~/MindsetForge/functions
npx ts-node scripts/seed_coach_config.ts --analyst=ANALYST_UID --code=PILOT-CODE-2026
```

The script merges by default, so it is safe to rerun to add a code or an
analyst. To **revoke** one, rerun with `--replace` and pass only the values you
want to keep:

```bash
npx ts-node scripts/seed_coach_config.ts --replace --analyst=ANALYST_UID --code=NEW-CODE
```

> ⚠️ Treat a signup code like a password. Codes are deliberately multi-use and
> are never marked consumed, so anyone who has one can create a coach account
> with a team on the public signup page for as long as it stays in the array.
> Use one code per program, and revoke it once that program has signed up.
> Redemptions are logged server-side with the uid and team id, never the code.

Confirm the document exists and that a client genuinely cannot read it (attempt
a client read in the Rules Playground; it must be denied).

---

## 7. Create the hosting site — IRREVERSIBLE NAME

```bash
cd ~/mindsetforge-coach
firebase hosting:sites:create coach-portal-mindset
```

Or in the console: Hosting → **Add another site** → site id `coach-portal-mindset`.

> ⚠️ A hosting site id cannot be renamed, and a deleted id cannot be reused.
> `firebase.json` in this repo is pinned to `"site": "coach-portal-mindset"`, so
> the name must match exactly or every deploy from this repo will fail.

---

## 8. Deploy the portal

```bash
cd ~/mindsetforge-coach
npm run deploy      # next build && firebase deploy --only hosting:coach-portal-mindset
```

Because `firebase.json` is pinned to `coach-portal-mindset`, a deploy from this
repo cannot reach the marketing, admin, or app sites.

Then verify on the temporary `*.web.app` URL, before the custom domain exists:

- `/login` renders.
- `/join/SOMETHING` renders the invite page and reports "invite not found",
  rather than the login page. If you get the login page, the `/join/**` rewrite
  is not ahead of the `**` catch-all in `firebase.json`.
- Response headers include `X-Robots-Tag: noindex, nofollow`.

---

## 9. Attach `coach.mindsetforge.app` — check the site first

1. Open https://console.firebase.google.com/project/mindsetforge-ai/hosting
2. Select the **`coach-portal-mindset`** site. Confirm the site name on screen
   before continuing.
3. **Add custom domain** → `coach.mindsetforge.app`
4. Add the TXT verification record, then the A records Firebase provides, to the
   `mindsetforge.app` DNS zone.
5. Wait for the certificate to provision (typically 20 minutes to a few hours).

> ⚠️ This project has already had an outage from attaching a domain to the wrong
> hosting site: the apex `mindsetforge.app` was once pointed at the Flutter app
> site. The apex belongs to `mindsetforge-marketing`, `app.` to
> `mindsetforge-ai`, `admin.` to `admin-console-mindsetforge`, and `coach.` to
> `coach-portal-mindset`. Confirm the selected site every time.

Invite links are hardcoded to `https://coach.mindsetforge.app/join/{inviteId}`
in `functions/src/coach_types.ts`, so **do not send any invites until this domain
resolves.** Links generated earlier will still work once it does, but a player
who clicks one before then gets a dead page.

Finally, add the new row to `~/MindsetForge/deployment.md`:

| Domain | Hosting site | Repo | Build dir |
|---|---|---|---|
| `coach.mindsetforge.app` (coach portal) | `coach-portal-mindset` | `~/mindsetforge-coach` (Next.js) | `out/` |

---

## 10. Pilot end-to-end test script

Run this whole script against a throwaway team before a real coach touches the
portal. It needs a real phone with the app installed, and two email addresses
you control. Nothing here is verified by an automated test; the privacy check in
step 7 is the entire point of the exercise.

**Setup:** one signup code seeded in step 6, one test email for the coach, one
for the player.

1. **Coach signs up.** Go to `coach.mindsetforge.app/signup`. Enter the access
   code, coach name, coach email, a password, a team name, a sport, and a season
   end date **in the future**.
   - Expected: lands on `/dashboard` with the team name in the header and "No
     prompt assigned for today".
   - Also check: submitting signup a second time with the same account sends you
     to the dashboard rather than creating a second team.
   - Also check: a wrong access code is rejected with a clear message and no
     account is left behind in a broken state.

2. **Coach builds a prompt bank.** `/prompts` → set a theme, generate 5.
   - Expected: 5 prompts appear within a minute, each a single open-ended
     question, none of them asking for medical or clinical detail.
   - Add one manual prompt too, and confirm it is labelled "Added by you".

3. **Coach assigns today's prompt.** `/schedule` → find the row badged **Today**
   → pick a prompt → **Assign**.
   - Expected: the row shows the prompt text, and `/dashboard` now shows it
     under "Today's prompt" with the 4 AM note.
   - The "Today" row is the app's active day, which runs 4 AM to 4 AM. Between
     midnight and 4 AM it is still yesterday's calendar date, on purpose.

4. **Coach adds the player.** `/roster` → add the player's name and email →
   **Send invites** → copy the invite link.
   - Expected: the player appears with status **invited** and a
     `coach.mindsetforge.app/join/...` link.
   - Also check: adding the same email again returns it under "Skipped".

5. **Player joins.** Open the invite link in a browser (ideally on the phone).
   The email is prefilled and read-only. Set a name and a password.
   - Expected: a welcome screen with App Store and Play Store links, plus the
     line about the coach seeing summaries and not the words.
   - Refresh the same link: it should now say the invite has already been used.
   - Back in the portal, the player's roster status flips to **active**.

6. **Player writes an entry in the app.** Install the app, sign in with the
   player's email and password, complete onboarding.
   - Expected: **no paywall**, because `acceptTeamInvite` set `premiumUntil` to
     the season end date.
   - Start a journal entry. On the prompt-choice step the coach's prompt appears
     as a pinned card, and choosing "blank page" instead is still possible. That
     is intentional: the app never forces the coach's prompt.
   - Write something with a distinctive, private-sounding sentence in it, so the
     next step is a real test. Save the entry.

7. **The privacy check. This is the step that matters.** Within a minute or two,
   in the portal:
   - `/dashboard` → "Recent entries" shows the player's name, mood, date, and a
     1 to 2 sentence summary.
   - `/players?uid=...` → mood chart, themes, and the entry timeline.
   - **Read the summary against what the player actually wrote.** It must not
     quote the entry, reuse its distinctive phrasing, name another person, or
     repeat a specific private detail. Search the page for the distinctive
     sentence from step 6; it must not appear.
   - Confirm no raw journal text is reachable anywhere: no "view entry" control,
     no expandable text, and nothing in the browser's network tab beyond the
     summary fields. There is no `content` field in `team_entry_summaries` by
     contract, and `journals` is owner-only in the rules.
   - Confirm the roster's "Last entry" column shows a **date**, not a time.
   - If any of this fails, stop the pilot and treat it as a privacy incident
     rather than a bug.

8. **Weekly report.** `/insights` → generate a report for the current ISO week.
   - Expected: participation, average mood, themes, wins, and concerns, all
     aggregate. The watch list should mention participation only. Nothing should
     read as a mental-health assessment of a named player.

9. **Remove the player.** `/roster` → **Remove**.
   - Expected: status **removed**; in the app the player keeps their journal and
     their access, and stops receiving the team prompt.

10. **Analyst access.** Sign in as the seeded analyst uid. `/teams` lists every
    team and switching the active team changes the dashboard.

---

## Related documents

- `~/MindsetForge/deployment.md` — the other three sites and the custom-domain
  history behind the warnings above.
- `README.md` in this repo — local dev, the `/join` rewrite, and why
  `lib/types.ts` is a hand-maintained mirror of
  `functions/src/coach_types.ts`.
