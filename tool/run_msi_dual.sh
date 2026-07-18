#!/usr/bin/env bash
#
# S16 dual-account MSI acceptance launcher (Principal Flutter Engineer B).
#
# Builds the dev-debug APK wired to the NATIVE jeeb-gateway on the MSI host
# (192.168.2.39:10090) — NOT the Express mock — and installs it on the two
# acceptance emulators simultaneously:
#
#   emulator-5554 = CLIENT  (Nour,  role customer -> client)
#   emulator-5556 = JEEBER  (Karim, role driver   -> jeeber)
#
# The acceptance gate REQUIRES USE_MOCK_GATEWAY=false: pointing the "done" run
# at the mock (:4010) is a false PASS (the mock chat-service emits no push).
#
# This script does NOT log in for you and never touches the super-admin
# passcode — read it on MSI at run time from ~/iter5-runtime/keys and drive
# super-login per device from the adb loop (see CODEX-MAESTRO-TESTING-KB.md).
# Firebase: the real dev google-services.json must already be injected at
# android/app/src/dev/google-services.json. The path is ignored by git; start
# from google-services.json.template or the protected CI secret, never VCS.
#
# Prereqs: both emulators booted (Google-Play image, FCM-capable); the dev
# google-services.json in place; the three DEV_FIREBASE_EXPECTED_* identity
# inputs exported from the protected environment; MSI gateway reachable.
set -euo pipefail

MSI_GATEWAY="${MSI_GATEWAY:-http://192.168.2.39:10090}"
CLIENT_SERIAL="${CLIENT_SERIAL:-emulator-5554}"
JEEBER_SERIAL="${JEEBER_SERIAL:-emulator-5556}"
PKG="app.jeeb.mobile.dev"
ADB="${ADB:-$HOME/Library/Android/sdk/platform-tools/adb}"

DEFINES=(
  --dart-define=USE_MOCK_GATEWAY=false
  --dart-define=GATEWAY_BASE_URL="${MSI_GATEWAY}"
  --dart-define=REQUIRE_REAL_PUSH=true
)

if ! bash tool/validate_dev_google_services.sh; then
  echo '[run_msi_dual] Dev Firebase config preflight failed — abort' >&2
  exit 1
fi

echo "[run_msi_dual] MSI gateway target: ${MSI_GATEWAY}"
echo "[run_msi_dual] pre-flight: gateway /health"
curl -fsS -o /dev/null -w "  /health -> HTTP %{http_code}\n" --max-time 8 "${MSI_GATEWAY}/health" \
  || { echo "  MSI gateway unreachable — abort"; exit 1; }

echo "[run_msi_dual] building dev-debug APK (MSI-targeted, real FCM)…"
flutter build apk --flavor dev --debug "${DEFINES[@]}"
APK="build/app/outputs/flutter-apk/app-dev-debug.apk"
[ -f "${APK}" ] || { echo "APK not found at ${APK}"; exit 1; }

for SERIAL in "${CLIENT_SERIAL}" "${JEEBER_SERIAL}"; do
  echo "[run_msi_dual] installing on ${SERIAL}…"
  "${ADB}" -s "${SERIAL}" install -r -d "${APK}"
  # Pre-compile to speed-class to avoid first-launch JIT/dexopt ANR (HARNESS,
  # not a product NO-GO — see testing KB).
  "${ADB}" -s "${SERIAL}" shell cmd package compile -m speed -f "${PKG}" || true
  # POST_NOTIFICATIONS so background/closed-app FCM can post to the HIGH channel.
  "${ADB}" -s "${SERIAL}" shell pm grant "${PKG}" android.permission.POST_NOTIFICATIONS || true
done

echo "[run_msi_dual] install complete; push acceptance is not ready until authenticated registration returns 2xx."
echo "[run_msi_dual] Drive super-login per device via adb:"
echo "  CLIENT  ${CLIENT_SERIAL}: userId d1000000-0000-4000-8000-000000000001 (Nour)"
echo "  JEEBER  ${JEEBER_SERIAL}: userId d1000000-0000-4000-8000-000000000002 (Karim)"
echo "  POST ${MSI_GATEWAY}/api/User/user-id-login {userId, superAdminPassCode}"
echo "  (passcode: read on MSI from ~/iter5-runtime/keys/super_admin_passcode — never print/commit)"
