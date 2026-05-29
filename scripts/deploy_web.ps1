# ─── ESP32 GPS Tracker — Flutter Web Deploy Script (PowerShell) ───────────────
# Usage:
#   .\scripts\deploy_web.ps1 [-Host github|firebase|netlify|vercel|custom]
#
# Examples:
#   .\scripts\deploy_web.ps1                         # build only
#   .\scripts\deploy_web.ps1 -Host github            # build + GitHub Pages
# ==============================================================================

param(
  [string]$Host = ""
)

$ProjectDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $ProjectDir

Write-Host "=== ESP32 GPS Tracker — Web Deploy ===" -ForegroundColor Cyan
Write-Host ""

# ── Build ──────────────────────────────────────────────────────────────────────
Write-Host "[1/3] Cleaning previous build..."
flutter clean 2>$null

Write-Host "[2/3] Getting dependencies..."
flutter pub get

Write-Host "[3/3] Building Flutter web (release)..."
flutter build web --release

Write-Host ""
Write-Host "✓ Build complete: $ProjectDir\build\web\" -ForegroundColor Green
Write-Host ""

# ── Deploy ─────────────────────────────────────────────────────────────────────
switch ($Host.ToLower()) {
  "github" {
    Write-Host "→ Deploying to GitHub Pages..." -ForegroundColor Yellow
    Write-Host "  Option A: Push build/web/ to gh-pages branch"
    Write-Host "    git checkout -b gh-pages"
    Write-Host "    Copy-Item -Recurse build/web/* ."
    Write-Host "    git add . && git commit -m 'deploy'"
    Write-Host "    git push origin gh-pages --force"
    Write-Host ""
    Write-Host "  Option B: Use GitHub Actions (recommended)"
    Write-Host "    The .github/workflows/flutter_ci.yml workflow"
    Write-Host "    auto-deploys to GitHub Pages on push to main."
  }
  "firebase" {
    Write-Host "→ Deploying to Firebase Hosting..." -ForegroundColor Yellow
    Write-Host "    npx firebase-tools init hosting"
    Write-Host "    npx firebase-tools deploy --only hosting"
  }
  "netlify" {
    Write-Host "→ Deploying to Netlify..." -ForegroundColor Yellow
    Write-Host "  Drag & drop build/web/ to https://app.netlify.com"
    Write-Host "  Or use CLI: npx netlify-cli deploy --prod --dir=build/web"
  }
  "vercel" {
    Write-Host "→ Deploying to Vercel..." -ForegroundColor Yellow
    Write-Host "    npx vercel --prod build/web"
  }
  "custom" {
    Write-Host "→ Deploying to custom server..." -ForegroundColor Yellow
    Write-Host "  Copy build/web/ to your web server's document root."
  }
  default {
    Write-Host "No -Host specified. Build output ready at build\web\" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Available hosts:" -ForegroundColor Cyan
    Write-Host "  -Host github     GitHub Pages"
    Write-Host "  -Host firebase   Firebase Hosting"
    Write-Host "  -Host netlify    Netlify"
    Write-Host "  -Host vercel     Vercel"
    Write-Host "  -Host custom     Generic web server"
  }
}
