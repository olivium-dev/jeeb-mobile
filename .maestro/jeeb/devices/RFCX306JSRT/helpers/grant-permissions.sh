#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# grant-permissions.sh — fresh-state + pre-grant so the fastest path skips the
# two Android OS permission dialogs (POST_NOTIFICATIONS + ACCESS_FINE_LOCATION).
# ─────────────────────────────────────────────────────────────────────────────
# 0 taps saved vs. dismissing the dialogs in-flow. Run this BEFORE a fastest-path
# run when you want the tightest, most deterministic journey. The page-object
# _os-permissions.yaml still dismisses the dialogs optionally if you skip this.
#
# Usage: helpers/grant-permissions.sh [SERIAL]   (SERIAL defaults to RFCX306JSRT)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SERIAL="${1:-RFCX306JSRT}"
APP_ID="${APP_ID:-app.jeeb.mobile}"
ADB="${ADB:-$HOME/Library/Android/sdk/platform-tools/adb}"

"${ADB}" -s "${SERIAL}" shell pm clear "${APP_ID}"
"${ADB}" -s "${SERIAL}" shell pm grant "${APP_ID}" android.permission.POST_NOTIFICATIONS || true
"${ADB}" -s "${SERIAL}" shell pm grant "${APP_ID}" android.permission.ACCESS_FINE_LOCATION || true
"${ADB}" -s "${SERIAL}" shell pm grant "${APP_ID}" android.permission.ACCESS_COARSE_LOCATION || true

echo "grant-permissions.sh: cleared state + granted notifications/location for ${APP_ID} on ${SERIAL}"
