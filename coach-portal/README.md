# MindsetForge Coach Portal

Web app for coaches and analysts to manage a team: roster, invite links, the
AI journal prompt bank, the daily schedule, and player insights (mood, themes,
AI summaries, never raw journal text).

Routes: `/login`, `/signup`, `/join`, `/dashboard`, `/prompts`, `/schedule`,
`/roster`, `/players`, `/insights`, `/settings`, and `/teams` (analyst only).
Deploy steps and the pilot test script are in [DEPLOY.md](./DEPLOY.md).

`/players` takes the player as a `?uid=` query parameter rather than a
`/players/[playerId]` path segment, because a static export cannot prerender a
dynamic route.

## How player invite links work

Invite links are `https://coach.mindsetforge.app/join/{inviteId}`, but a static
export cannot prerender a route whose parameters are unknowable at build time.
So there is a single static page at `app/join/page.tsx` that reads the invite id
from the last path segment (with a `?invite=` fallback), and `firebase.json`
rewrites `/join/**` to the emitted `/join.html`.

That rewrite **must stay ahead of the `**` SPA catch-all**, or every invite link
falls through to the app shell and the player sees a sign-in page instead of
their invite. The main Flutter repo serves `/partner-invite/**` the same way.

## About this location (temporary)

This repo is currently nested inside `~/MindsetForge` (the Flutter app repo)
because of a sandbox restriction on writing outside the workspace during
scaffolding. **It is fully self-contained**: its own `package.json`,
`tsconfig.json`, `.gitignore`, `firebase.json`, and `.firebaserc`. Nothing in
this directory references a path outside itself, and it does not modify
anything in the parent Flutter repo.

It will be moved to its own sibling repo at `~/mindsetforge-coach` (see the
project's `related-projects` rule) once scaffolding is verified. Moving it is
a straightforward directory move plus `git init`; no code changes required.

## Stack

- Next.js 16 App Router, static export (`output: "export"`)
- TypeScript, strict mode
- Tailwind CSS v4 (`@tailwindcss/postcss`)
- Firebase JS SDK v11 (Auth, Firestore, Callable Functions)
- Firebase project: `mindsetforge-ai`, functions region `us-central1`

The full design token set (colors, radii, glow shadows) lives in
`app/globals.css`, matching the Flutter app and the marketing site
(`~/mindsetforge-web`). Fonts are Space Grotesk (display) and Inter (body),
loaded via `next/font/google`.

## Contract source of truth

`lib/types.ts` and `lib/firebase.ts` mirror the frozen "Shared contracts"
section of the coach team portal plan and
`functions/src/coach_types.ts` / `functions/src/coach.ts` in the main app
repo. This repo does not import across the repo boundary, so if the server
contract changes, these files must be updated by hand to match.

## Local dev

```bash
npm install
npm run dev
```

Open http://localhost:3002

## Build

```bash
npm run build
```

Produces a static export in `out/`.

## Deploy

```bash
npm run deploy
```

Runs `next build && firebase deploy --only hosting:coach-portal-mindset`. This
deploys to the `coach-portal-mindset` Firebase Hosting site (custom domain
`coach.mindsetforge.app`), pinned in this repo's `firebase.json`. The site is
`noindex, nofollow` since it is a private tool, not a public marketing page.

Deploying requires being logged into the Firebase CLI (`firebase login`) with
access to the `mindsetforge-ai` project.
