#!/usr/bin/env bash
# DT-10 (partial) — build, install and E2E-smoke the Jeeber Dev Tool's
# gateway-independent features on a connected Android device.
#
# Usage: scripts/devtool-smoke.sh [--no-build]
#
# The Dev Tool is a SECOND launcher icon (activity-alias .DevToolLauncher) on the
# same app, so we launch that component explicitly via adb, then run a Maestro
# flow that asserts on the already-open Dev Tool (the flow itself has no
# launchApp, since the default launcher would open the normal Jeeb app instead).
set -euo pipefail

FLUTTER_BIN="${FLUTTER_BIN:-$HOME/development/flutter/bin}"
ANDROID_PLATFORM_TOOLS="${ANDROID_PLATFORM_TOOLS:-$HOME/Library/Android/sdk/platform-tools}"
MAESTRO_BIN="${MAESTRO_BIN:-$HOME/.maestro/bin}"
export PATH="$PATH:$FLUTTER_BIN:$ANDROID_PLATFORM_TOOLS:$MAESTRO_BIN"

APP_ID="app.jeeb.mobile.dev"
ALIAS="$APP_ID/app.jeeb.mobile.DevToolLauncher"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ "${1:-}" != "--no-build" ]]; then
  echo "==> Building dev flavor with the Dev Tool enabled…"
  flutter build apk --flavor dev --debug --dart-define=JEEB_DEVTOOL_ENABLED=true
  adb install -r build/app/outputs/flutter-apk/app-dev-debug.apk
fi

echo "==> Launching the Dev Tool (activity-alias) …"
adb shell am force-stop "$APP_ID" || true
adb shell am start -n "$ALIAS" >/dev/null
sleep 5

echo "==> Running Maestro smoke…"
maestro test .maestro/flows/devtool-smoke.yaml
echo "==> Dev Tool smoke PASSED"
