# Web Deployment Reference

## Sites

| Domain | Site | Repo |
|--------|------|------|
| `mindsetforge.app` | `mindsetforge-marketing` | `~/mindsetforge-web` (Next.js) |
| `app.mindsetforge.app` | `mindsetforge-ai` (default) | `~/MindsetForge` (Flutter) |

**Firebase project:** `mindsetforge-ai`

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

`app.mindsetforge.app` is connected to the default `mindsetforge-ai` hosting site — add it the same way on that site's custom domain settings.

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
