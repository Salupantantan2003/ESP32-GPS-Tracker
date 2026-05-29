#!/usr/bin/env bash
# ─── ESP32 GPS Tracker — Flutter Web Deploy Script ───────────────────────────
# Usage:
#   ./scripts/deploy_web.sh [--host github|firebase|netlify|vercel|custom]
#
# Examples:
#   ./scripts/deploy_web.sh                           # build only
#   ./scripts/deploy_web.sh --host github             # build + GitHub Pages
#   ./scripts/deploy_web.sh --host firebase           # build + Firebase
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "=== ESP32 GPS Tracker — Web Deploy ==="
echo ""

# ── Parse args ────────────────────────────────────────────────────────────────
HOST="${1:-}"
if [[ "$HOST" == "--host" ]]; then
  HOST="${2:-}"
fi

# ── Build ──────────────────────────────────────────────────────────────────────
echo "[1/3] Cleaning previous build..."
flutter clean 2>/dev/null || true

echo "[2/3] Getting dependencies..."
flutter pub get

echo "[3/3] Building Flutter web (release)..."
flutter build web --release

echo ""
echo "✓ Build complete: $PROJECT_DIR/build/web/"
echo ""

# ── Deploy ─────────────────────────────────────────────────────────────────────
deploy_github() {
  echo "→ Deploying to GitHub Pages..."
  echo "  Option A: Push build/web/ to gh-pages branch"
  echo "    git checkout -b gh-pages"
  echo "    cp -r build/web/* ."
  echo "    git add . && git commit -m 'deploy'"
  echo "    git push origin gh-pages --force"
  echo ""
  echo "  Option B: Use GitHub Actions (recommended)"
  echo "    The .github/workflows/flutter_ci.yml workflow"
  echo "    auto-deploys to GitHub Pages on push to main."
  echo ""
  echo "  Then enable: Settings → Pages → Deploy from branch (gh-pages)"
}

deploy_firebase() {
  echo "→ Deploying to Firebase Hosting..."
  if ! command -v firebase &>/dev/null; then
    echo "  Installing firebase-tools..."
    npm install -g firebase-tools
  fi
  firebase init hosting --project esp32-gps-tracker
  firebase deploy --only hosting
}

deploy_netlify() {
  echo "→ Deploying to Netlify..."
  echo "  Drag & drop build/web/ to https://app.netlify.com"
  echo "  Or use CLI:"
  echo "    npx netlify-cli deploy --prod --dir=build/web"
}

deploy_vercel() {
  echo "→ Deploying to Vercel..."
  echo "  Install Vercel CLI and run:"
  echo "    npx vercel --prod build/web"
}

deploy_custom() {
  echo "→ Deploying to custom server..."
  echo "  Copy build/web/ to your web server's document root:"
  echo "    scp -r build/web/* user@your-server:/var/www/gps-tracker/"
  echo ""
  echo "  Or with rsync:"
  echo "    rsync -avz --delete build/web/ user@your-server:/var/www/gps-tracker/"
}

case "$HOST" in
  github)   deploy_github ;;
  firebase) deploy_firebase ;;
  netlify)  deploy_netlify ;;
  vercel)   deploy_vercel ;;
  custom)   deploy_custom ;;
  *)
    echo "No --host specified. Build output ready at build/web/"
    echo ""
    echo "Available hosts:"
    echo "  --host github     GitHub Pages"
    echo "  --host firebase   Firebase Hosting"
    echo "  --host netlify    Netlify"
    echo "  --host vercel     Vercel"
    echo "  --host custom     Generic web server (scp/rsync)"
    ;;
esac
