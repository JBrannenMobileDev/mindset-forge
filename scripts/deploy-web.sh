#!/usr/bin/env bash
# deploy-web.sh — Build the Flutter web app and deploy to Firebase Hosting.
#
# Usage:
#   ./scripts/deploy-web.sh            # build + deploy
#   ./scripts/deploy-web.sh --build-only   # skip deploy (dry run)
#
# Requirements:
#   flutter, firebase CLI (npm install -g firebase-tools), firebase login

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$REPO_ROOT/build/web"
STATIC_DIR="$REPO_ROOT/public"
BUILD_ONLY=false

# This repo (the Flutter web app) must ONLY ever deploy to the app site.
# The marketing site (mindsetforge.app) is a completely separate repo/site.
EXPECTED_SITE="mindsetforge-ai"   # serves app.mindsetforge.app

for arg in "$@"; do
  [[ "$arg" == "--build-only" ]] && BUILD_ONLY=true
done

# --- Safety guard: refuse to deploy if firebase.json isn't pinned to the app site.
# This makes it impossible to accidentally publish the Flutter app to the
# marketing site, even if firebase.json is ever changed or copied between repos.
CONFIGURED_SITE="$(grep -oE '"site"[[:space:]]*:[[:space:]]*"[^"]+"' "$REPO_ROOT/firebase.json" | head -1 | sed -E 's/.*"site"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
if [[ "$CONFIGURED_SITE" != "$EXPECTED_SITE" ]]; then
  echo "ERROR: firebase.json hosting.site is '$CONFIGURED_SITE' but this repo must deploy to '$EXPECTED_SITE'." >&2
  echo "       Refusing to deploy to avoid overwriting the wrong site." >&2
  exit 1
fi

echo "==> Building Flutter web (release)..."
cd "$REPO_ROOT"
flutter build web --release

echo "==> Merging static assets from public/ into build/web/..."
# Copy partner-invite page, legal docs, and universal-link files so they are
# served as exact-match static files by Firebase Hosting (takes priority over
# the /** → /index.html SPA rewrite).
cp -r "$STATIC_DIR/." "$BUILD_DIR/"

echo "==> Static files copied:"
find "$BUILD_DIR/.well-known" -type f 2>/dev/null | sed 's|'"$BUILD_DIR"'||'
ls "$BUILD_DIR"/*.html 2>/dev/null | xargs -I{} basename {} | sed 's/^/  /'

if $BUILD_ONLY; then
  echo "==> --build-only flag set; skipping deploy."
  echo "    Build output is in build/web/"
  exit 0
fi

echo "==> Deploying to Firebase Hosting (site: $EXPECTED_SITE)..."
firebase deploy --only "hosting:$EXPECTED_SITE"

echo ""
echo "==> Done! Site live at https://app.mindsetforge.app"
