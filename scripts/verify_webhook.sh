#!/usr/bin/env bash
#
# Smoke-tests the deployed revenueCatWebhook auth behavior WITHOUT writing any
# data to Firestore. It verifies the function:
#   - rejects non-POST requests        (405)
#   - rejects requests with no/﻿wrong Authorization header (401)
#   - accepts the correct shared secret and then fails on the missing event
#     body (400) — which proves the Authorization check passed.
#
# Usage:
#   REVENUECAT_WEBHOOK_SECRET=<your-secret> ./scripts/verify_webhook.sh
#
# Optional overrides:
#   WEBHOOK_URL=https://...run.app  (defaults to the deployed us-central1 URL)
#
# The secret is read from the environment so it never has to be committed or
# pasted into the script. Get/regenerate it with:
#   firebase functions:secrets:access REVENUECAT_WEBHOOK_SECRET
set -uo pipefail

URL="${WEBHOOK_URL:-https://revenuecatwebhook-uvghikxzra-uc.a.run.app}"
SECRET="${REVENUECAT_WEBHOOK_SECRET:-}"

pass=0
fail=0

check() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    printf 'PASS  %-55s (got %s)\n' "$desc" "$actual"
    pass=$((pass + 1))
  else
    printf 'FAIL  %-55s (expected %s, got %s)\n' "$desc" "$expected" "$actual"
    fail=$((fail + 1))
  fi
}

http_code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }

echo "Target: $URL"
echo

# 1. GET is rejected by the method gate.
check "GET rejected (method gate)" "405" "$(http_code "$URL")"

# 2. POST without an Authorization header is rejected.
check "POST without auth rejected" "401" "$(http_code -X POST "$URL")"

# 3. POST with a wrong Authorization header is rejected.
check "POST with wrong auth rejected" "401" \
  "$(http_code -X POST -H 'Authorization: not-the-secret' "$URL")"

# 4. POST with the correct secret passes auth, then 400 on the empty body.
if [[ -n "$SECRET" ]]; then
  check "POST with correct auth passes (missing-event 400)" "400" \
    "$(http_code -X POST -H "Authorization: $SECRET" \
        -H 'Content-Type: application/json' -d '{}' "$URL")"
else
  echo "SKIP  correct-secret check — set REVENUECAT_WEBHOOK_SECRET to run it"
fi

echo
echo "Passed: $pass  Failed: $fail"
[[ "$fail" -eq 0 ]]
