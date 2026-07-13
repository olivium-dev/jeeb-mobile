#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# run-fastest-path.sh — LIVE fastest-path orchestrator for device RFCX306JSRT.
# ─────────────────────────────────────────────────────────────────────────────
# Why an orchestrator instead of one flow file: the OTP does not exist until
# Send code is tapped, and it expires in 5 min, so it cannot be baked into a
# single flow's env. This script drives the journey in two Maestro passes that
# share on-device app state (pass 2 has NO launchApp, so it continues from the
# OTP screen pass 1 left on):
#
#   pass 1  auth-send-code.yaml       fresh launch -> skip onboarding -> phone ->
#                                     Send code  (=> POST /v1/auth/otp/request 200)
#   (read the just-written code from jeeb-otpdb via otp.sh)
#   pass 2  fastest-path-continue.yaml enter OTP -> Verify -> skip profile-name ->
#                                     home -> New Order -> Continue -> location ->
#                                     Confirm (=> POST /v1/requests 201) -> waiting
#
# Deepest customer state reached: waiting-no-coverage ("Finding Jeebers").
#
# Usage: helpers/run-fastest-path.sh [SERIAL] [PHONE]
#   SERIAL defaults to RFCX306JSRT, PHONE defaults to 71963130.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SERIAL="${1:-RFCX306JSRT}"
PHONE="${2:-71963130}"
DESC="${DESC:-Maestro automated test delivery}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVROOT="$(dirname "${HERE}")"
MAESTRO="${MAESTRO:-$HOME/.maestro/bin/maestro}"

export JAVA_HOME="${JAVA_HOME:-$(/usr/libexec/java_home 2>/dev/null || echo "")}"

echo "[run-fastest-path] pass 1/2 — send code (fresh launch) on ${SERIAL}"
"${MAESTRO}" --device "${SERIAL}" test \
  "${DEVROOT}/flows/journeys/auth-send-code.yaml" \
  -e APP_ID=app.jeeb.mobile -e PHONE="${PHONE}"

echo "[run-fastest-path] waiting for the OTP to land in jeeb-otpdb..."
sleep 3
OTP="$("${HERE}/otp.sh" "${PHONE}")"
echo "[run-fastest-path] read OTP=${OTP} for +961 ${PHONE}"

echo "[run-fastest-path] pass 2/2 — verify + drive to waiting-no-coverage"
"${MAESTRO}" --device "${SERIAL}" test \
  "${DEVROOT}/flows/journeys/fastest-path-continue.yaml" \
  -e APP_ID=app.jeeb.mobile -e OTP="${OTP}" -e DESC="${DESC}"

echo "[run-fastest-path] done — deepest customer state (waiting-no-coverage) reached."
