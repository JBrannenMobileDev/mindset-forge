# Web Deployment Reference

## Sites — the one table that matters

| Domain | Hosting site | Repo | Build dir |
|--------|--------------|------|-----------|
| `mindsetforge.app` (marketing) | `mindsetforge-marketing` | `~/mindsetforge-web` (Next.js) | `out/` |
| `app.mindsetforge.app` (web app) | `mindsetforge-ai` | `~/MindsetForge` (Flutter) | `build/web/` |

**Firebase project:** `mindsetforge-ai` (one project, two hosting sites).

## How mix-ups are prevented

Each repo's `firebase.json` is **pinned to exactly one site** via the
`hosting.site` field, and neither repo references the other's site:

- `~/MindsetForge/firebase.json` → `"site": "mindsetforge-ai"`
- `~/mindsetforge-web/firebase.json` → `"site": "mindsetforge-marketing"`

Because of this, `firebase deploy --only hosting` from either repo can **only**
target its own site. The Flutter deploy script (`scripts/deploy-web.sh`) also
hard-fails if `firebase.json` is ever changed to point anywhere other than
`mindsetforge-ai`.

> ⚠️ **Domain rule of thumb:** the bare apex `mindsetforge.app` is **marketing**.
> Only the `app.` subdomain is the Flutter app. When attaching a custom domain
> in the Firebase Console, double-check you selected the correct **site** first.

---

## Deploy the Marketing Site (`mindsetforge.app`)

```bash
cd ~/mindsetforge-web
npm run deploy
```

That runs `next build && firebase deploy --only hosting:marketing`.  
Build output is the `out/` directory (static export).

---

## Deploy the Flutter Web App (`app.mindsetforge.app`)

```bash
cd ~/MindsetForge
./scripts/deploy-web.sh
```

That runs `flutter build web --release`, merges static assets from `public/`, then deploys.

### Build-only (no deploy)

```bash
./scripts/deploy-web.sh --build-only
```

---

## Prerequisites (one-time setup)

Firebase CLI must be installed and authenticated:

```bash
npm install -g firebase-tools
firebase login
```

Flutter must be on PATH (verify with `flutter --version`).

---

## Custom Domain Setup (one-time, done in Firebase Console)

The `mindsetforge-marketing` hosting site needs `mindsetforge.app` connected to it.  
Do this once in the Firebase Console:

1. Go to https://console.firebase.google.com/project/mindsetforge-ai/hosting
2. Click the **mindsetforge-marketing** site → **Add custom domain**
3. Enter `mindsetforge.app`
4. Follow the steps: add the verification TXT record to your DNS, then add the A records Firebase provides
5. Repeat for `www.mindsetforge.app` if desired

`app.mindsetforge.app` is connected to the `mindsetforge-ai` hosting site — add it the same way on **that** site's custom domain settings.

> ⚠️ **This is exactly where it once broke:** `mindsetforge.app` was accidentally
> attached to the `mindsetforge-ai` (app) site, so the apex domain served the
> Flutter app instead of the marketing site. Before clicking **Add custom domain**,
> always confirm which **site** you are editing — the bare apex domain belongs to
> `mindsetforge-marketing`, never to `mindsetforge-ai`.

---

## Static Files Included in Every Flutter Deploy

These live in `~/MindsetForge/public/` and are merged into `build/web/` at deploy time. **Edit them in `public/`**, not in `build/web/`.

| URL | Purpose |
|-----|---------|
| `/.well-known/apple-app-site-association` | iOS Universal Links |
| `/.well-known/assetlinks.json` | Android App Links |
| `/partner-invite/*` | Accountability partner invite landing page |
| `/privacy-policy` | Privacy policy |
| `/terms-of-service` | Terms of service |
| `/support` | Support page |

---

## Firebase Console Links

- **Hosting dashboard:** https://console.firebase.google.com/project/mindsetforge-ai/hosting
- **Deploy history / rollback:** available in the Hosting dashboard per site
