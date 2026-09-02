#!/usr/bin/env bash
#
# S16 dual-account MSI acceptance launcher (Principal Flutter Engineer B).
#
# Builds the dev-debug APK wired to the NATIVE jeeb-gateway on the MSI host
# (192.168.2.39:10090) — NOT the Express mock — and installs it on the two
# acceptance phones simultaneously:
#
#   Galaxy S24 = CLIENT  (Nour,  role customer -> client)
#   Galaxy A33 = JEEBER  (Karim, role driver   -> jeeber)
#
# The acceptance gate REQUIRES USE_MOCK_GATEWAY=false: pointing the "done" run
# at the mock (:4010) is a false PASS (the mock chat-service emits no push).
#
# This script does NOT log in for you and never touches the super-admin
# passcode — read it on MSI at run time from ~/iter5-runtime/keys and drive
# super-login per device from the adb loop (see CODEX-MAESTRO-TESTING-KB.md).
# Firebase: the real dev google-services.json (project jeeb-5a293) must already
# be in android/app/src/dev/ + android/app/ via `git update-index --skip-worktree`
# (never committed — the secret hook does NOT catch Firebase assets).
#
# Prereqs: two physical Android devices attached and authorized; the dev
# google-services.json in place; MSI gateway reachable (ufw 10090 open).
set -euo pipefail

MSI_GATEWAY="${MSI_GATEWAY:-http://192.168.2.39:10090}"
MSI_REALTIME_SOCKET="${MSI_REALTIME_SOCKET:-ws://192.168.2.39:5804/socket/websocket}"
CLIENT_SERIAL="${CLIENT_SERIAL:-}"
JEEBER_SERIAL="${JEEBER_SERIAL:-}"
S24_SERIAL="${S24_SERIAL:-RFCX306JSRT}"
A33_SERIAL="${A33_SERIAL:-RZCT505K7WF}"
PKG="app.jeeb.mobile.dev"
ADB="${ADB:-$HOME/Library/Android/sdk/platform-tools/adb}"

DEFINES=(
  --dart-define=USE_MOCK_GATEWAY=false
  --dart-define=JEEB_MOCK_BASE_URL="${MSI_GATEWAY}"
  --dart-define=JEEB_USE_MOCK_PREFIXES=false
  --dart-define=JEEB_DEVTOOL_ENABLED=true
  --dart-define=JEEB_OBS_OVERLAY=true
  --dart-define=JEEB_REALTIME_TRACKING=true
  --dart-define=JEEB_REALTIME_SOCKET_URL="${MSI_REALTIME_SOCKET}"
)

fail() {
  echo "[run_msi_dual] ERROR: $*" >&2
  exit 1
}

is_ready_device() {
  local target="$1"
  "${ADB}" devices | awk -v target="${target}" \
    '$1 == target && $2 == "device" { found = 1 } END { exit !found }'
}

discover_physical_serials() {
  "${ADB}" devices -l | awk \
    'NR > 1 && $2 == "device" && $1 !~ /^emulator-/ { print $1 }'
}

pick_physical_serial() {
  local preferred="$1"
  local excluded="$2"
  shift 2
  local candidate
  for candidate in "${preferred}" "$@"; do
    if [[ -n "${candidate}" && "${candidate}" != "${excluded}" ]]; then
      local attached
      for attached in "$@"; do
        if [[ "${candidate}" == "${attached}" ]]; then
          echo "${candidate}"
          return 0
        fi
      done
    fi
  done
  return 1
}

select_devices() {
  local physical_serials=()
  local serial
  while IFS= read -r serial; do
    [[ -n "${serial}" ]] && physical_serials+=("${serial}")
  done < <(discover_physical_serials)

  if [[ -n "${CLIENT_SERIAL}" ]] && ! is_ready_device "${CLIENT_SERIAL}"; then
    fail "CLIENT_SERIAL '${CLIENT_SERIAL}' is not an attached, authorized device."
  fi
  if [[ -n "${JEEBER_SERIAL}" ]] && ! is_ready_device "${JEEBER_SERIAL}"; then
    fail "JEEBER_SERIAL '${JEEBER_SERIAL}' is not an attached, authorized device."
  fi

  if [[ -z "${CLIENT_SERIAL}" ]]; then
    CLIENT_SERIAL="$(
      pick_physical_serial "${S24_SERIAL}" "${JEEBER_SERIAL}" \
        "${physical_serials[@]}"
    )" || fail "No physical device is available for CLIENT_SERIAL. Attach and authorize the S24/A33, or set an explicit serial."
  fi
  if [[ -z "${JEEBER_SERIAL}" ]]; then
    JEEBER_SERIAL="$(
      pick_physical_serial "${A33_SERIAL}" "${CLIENT_SERIAL}" \
        "${physical_serials[@]}"
    )" || fail "No second physical device is available for JEEBER_SERIAL. Attach and authorize two phones, or set an explicit serial."
  fi
  if [[ "${CLIENT_SERIAL}" == "${JEEBER_SERIAL}" ]]; then
    fail "CLIENT_SERIAL and JEEBER_SERIAL must select different devices."
  fi
}

main() {
  select_devices
  echo "[run_msi_dual] devices: CLIENT=${CLIENT_SERIAL} JEEBER=${JEEBER_SERIAL}"
  echo "[run_msi_dual] MSI gateway target: ${MSI_GATEWAY}"
  echo "[run_msi_dual] pre-flight: gateway /health"
  curl -fsS -o /dev/null -w "  /health -> HTTP %{http_code}\n" --max-time 8 "${MSI_GATEWAY}/health" \
    || { echo "  MSI gateway unreachable — abort"; exit 1; }

  echo "[run_msi_dual] building dev-debug APK (MSI-targeted, real FCM)…"
  flutter build apk --flavor dev --debug \
    --android-project-arg=jeeb.devtool=true "${DEFINES[@]}"
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

  echo "[run_msi_dual] done. Drive super-login per device via adb:"
  echo "  CLIENT  ${CLIENT_SERIAL}: userId d1000000-0000-4000-8000-000000000001 (Nour)"
  echo "  JEEBER  ${JEEBER_SERIAL}: userId d1000000-0000-4000-8000-000000000002 (Karim)"
  echo "  POST ${MSI_GATEWAY}/api/User/user-id-login {userId, superAdminPassCode}"
  echo "  (passcode: read on MSI from ~/iter5-runtime/keys/super_admin_passcode — never print/commit)"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
