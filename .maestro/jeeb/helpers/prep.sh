#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# prep.sh — clean-install the prod v6 APK and PRE-GRANT the two runtime perms.
# ─────────────────────────────────────────────────────────────────────────────
# Pre-granting POST_NOTIFICATIONS + ACCESS_FINE_LOCATION removes the two OS
# permission dialogs that otherwise pop over onboarding and the location picker,
# saving ~2 taps and making the coordinate journey deterministic.
#
# Usage:
#   helpers/prep.sh <SERIAL> [APK_PATH]
#     SERIAL   — adb device serial (e.g. RFCX306JSRT). Required.
#     APK_PATH — path to the prod v6 APK. Optional: if omitted, the script only
#                pm-clears + grants (assumes the app is already installed).
#
# Examples:
#   helpers/prep.sh RFCX306JSRT ~/Downloads/app-prod-release.apk   # full clean install
#   helpers/prep.sh RFCX306JSRT                                    # reset state + grant only
#
# NOTE: a Maestro `launchApp: { clearState: true }` also resets app state, so for
# a pure re-run you often only need the grants. Use the APK path when you want a
# guaranteed-fresh install of the exact build under test.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SERIAL="${1:?usage: prep.sh <SERIAL> [APK_PATH]}"
APK_PATH="${2:-}"
APP_ID="${APP_ID:-app.jeeb.mobile}"

ADB=(adb -s "${SERIAL}")

echo "prep.sh: target device ${SERIAL}, app ${APP_ID}"

if [[ -n "${APK_PATH}" ]]; then
  echo "prep.sh: uninstalling ${APP_ID} (ignore error if not installed)"
  "${ADB[@]}" uninstall "${APP_ID}" >/dev/null 2>&1 || true
  echo "prep.sh: installing ${APK_PATH}"
  "${ADB[@]}" install -r -g "${APK_PATH}"
else
  echo "prep.sh: no APK given — clearing existing app state"
  "${ADB[@]}" shell pm clear "${APP_ID}" >/dev/null 2>&1 || true
fi

echo "prep.sh: pre-granting runtime permissions"
"${ADB[@]}" shell pm grant "${APP_ID}" android.permission.POST_NOTIFICATIONS   >/dev/null 2>&1 || true
"${ADB[@]}" shell pm grant "${APP_ID}" android.permission.ACCESS_FINE_LOCATION >/dev/null 2>&1 || true
"${ADB[@]}" shell pm grant "${APP_ID}" android.permission.ACCESS_COARSE_LOCATION >/dev/null 2>&1 || true

echo "prep.sh: done. ${APP_ID} is installed with notifications + location pre-granted."
