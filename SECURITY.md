# Security & Hardening

This document describes MindsetForge's security model and the steps required to
operate it safely — especially before making the repository public or scaling
the production deployment.

## Reporting a vulnerability

If you discover a security issue, please report it privately to
**security@mindsetforge.app** rather than opening a public issue.

---

## What is and isn't a secret in this repo

Some values committed to the repo *look* sensitive but are safe to publish,
because they are designed to ship inside the client app:

| Value | Location | Secret? | Why |
|-------|----------|---------|-----|
| Firebase API keys (`AIza…`) | `lib/firebase_options.dart` | **No** | Client identifiers, present in every shipped binary. Protected by Firestore Rules + App Check + API key restrictions, not by secrecy. |
| RevenueCat **public** SDK key (`appl_…`) | `lib/main.dart` | **No** | RevenueCat public SDK key, designed for client embedding. |
| `ANTHROPIC_API_KEY` | Firebase Secret Manager | **Yes** | Server-only. Never in client code or source. Loaded via `defineSecret`. |
| `REVENUECAT_WEBHOOK_SECRET` | Firebase Secret Manager | **Yes** | Server-only shared secret authenticating inbound RevenueCat webhooks. |
| `MIXPANEL_TOKEN` | Firebase Secret Manager | **No** (public project token) | Same Mixpanel project token as the client SDK; used server-side for `trial_converted` webhook events. |

Real secrets are **never** committed. The following are git-ignored and must be
provided out of band: `.env`, `google-services.json`, `GoogleService-Info.plist`,
signing keystores, and service-account JSON.

---

## Application security model

- **Firestore access** is owner-only. `users`, `journals`, and `chat_sessions`
  are readable/writable only by the authenticated owner (`request.auth.uid`).
  See `firestore.rules`.
- **`partner_invites` and `viral_metrics`** deny all direct client access; they
  are read/written exclusively by Cloud Functions via the Admin SDK.
- **Accountability partners** never read the primary user's private document
  directly. They receive a privacy-curated subset through the
  `getPartnerProgress` callable.
- **AI calls** are proxied through Cloud Functions. The Anthropic key lives only
  in Secret Manager; the client never sees it. Callables reject unauthenticated
  requests with `HttpsError('unauthenticated')`.
- **RevenueCat webhook** (`revenueCatWebhook`) validates a shared-secret
  `Authorization` header using a constant-time comparison before mutating any
  subscription state.

---

## Required setup: secrets

Set the server-side secrets before deploying functions:

```bash
# Anthropic API key (used by the Claude proxy + scheduled AI jobs)
firebase functions:secrets:set ANTHROPIC_API_KEY

# Shared secret for the RevenueCat webhook. Generate a strong random value:
#   openssl rand -hex 32
firebase functions:secrets:set REVENUECAT_WEBHOOK_SECRET
# Mixpanel project token (same value as lib/core/services/analytics_service.dart):
firebase functions:secrets:set MIXPANEL_TOKEN

firebase deploy --only functions
```

Then, in the **RevenueCat dashboard → Integrations → Webhooks**, set the
**Authorization header** to the exact same value you stored in
`REVENUECAT_WEBHOOK_SECRET`. Requests without a matching header are rejected
with `401`.

---

## Pre-launch / pre-public hardening checklist

Complete these before making the repo public or onboarding real users. The
code-level items are already addressed in this repository; the remaining items
are configuration in the Firebase / Google Cloud / Anthropic consoles.

### Code-level (done in this repo)
- [x] Anthropic key stored in Secret Manager, never in client code.
- [x] RevenueCat webhook authenticates via shared secret (constant-time compare).
- [x] Firestore rules restrict data to owners; invite/metrics collections deny
      direct client access.
- [x] Cloud Functions reject unauthenticated callers.
- [x] Logs sanitized to strip any leaked Anthropic key pattern.

### Configuration (do in the consoles)
- [ ] **Enable Firebase App Check** (Play Integrity on Android, DeviceCheck/App
      Attest on iOS, reCAPTCHA on web) and **enforce** it on Cloud Firestore and
      Cloud Functions. Flip the AI callables to `enforceAppCheck: true` once
      clients are sending tokens.
- [ ] **Restrict API keys** in Google Cloud Console → *APIs & Services →
      Credentials*. Lock each key to its platform (iOS bundle ID, Android package
      + SHA-256, HTTP referrers for web).
- [ ] **Set an Anthropic spend cap / budget alert** in the Anthropic console to
      bound worst-case AI cost from abuse.
- [ ] **Add per-user rate limiting** to the AI callables (e.g. a daily request
      counter in Firestore or a token bucket) to prevent a single account from
      draining the Anthropic budget.
- [ ] **Set a Google Cloud billing budget + alerts** for the project.
- [ ] Confirm the **RevenueCat webhook Authorization header** matches
      `REVENUECAT_WEBHOOK_SECRET`.
- [ ] Rotate any secret that may have been shared during development.

---

## Notes on going public

This repository's code (including AI prompts, coaching frameworks, and growth
logic) represents core product IP. Publishing it open-sources that IP under the
proprietary license in `README.md` — others may read it even though reuse is not
permitted. Evaluate that trade-off before changing repository visibility.
