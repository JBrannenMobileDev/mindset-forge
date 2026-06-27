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

for arg in "$@"; do
  [[ "$arg" == "--build-only" ]] && BUILD_ONLY=true
done

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

echo "==> Deploying to Firebase Hosting (project: mindsetforge-ai)..."
firebase deploy --only hosting

echo ""
echo "==> Done! Site live at https://app.mindsetforge.app"
