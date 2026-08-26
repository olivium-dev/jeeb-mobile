#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "${TMP_DIR}"' EXIT HUP INT TERM

manifest="${TMP_DIR}/manifest.pb"
resources="${TMP_DIR}/resources.pb"
binary="${TMP_DIR}/libapp.so"
safe_binary='https://app.jeeb.fds-1.com wss://app.jeeb.fds-1.com/socket/websocket internal_devtool_root internal_devtool_environment internal_devtool_auth_mode internal_devtool_close Normal SMS only'
printf '%s' 'com.olivium.jeeb com.olivium.jeeb.DevToolLauncher' >"${manifest}"
printf '%s' 'Jeeb Internal QA firebase maps' >"${resources}"
printf '%s' "${safe_binary}" >"${binary}"

run_inspector() {
  JEEB_INTERNAL_RELEASE="${1}" \
  JEEB_CLARITY_ENABLED="${2}" \
  JEEB_CLARITY_PRIVACY_APPROVED="${3}" \
    bash "${REPO_ROOT}/tool/inspect_android_internal_release_payload.sh" \
      "${manifest}" "${resources}" "${binary}" \
      https://app.jeeb.fds-1.com \
      wss://app.jeeb.fds-1.com/socket/websocket
}

run_inspector true false false >/dev/null

for forbidden in \
  '192.168.2.39' '192.168.2.50' '10.0.2.2' 'emulator-5554' \
  'http://localhost' 'http://127.0.0.1' 'https://api.jeeb.app' ':10069' \
  'super_login' 'unified_payment' '/v1/payments/' '/api/auth/token' \
  '/api/User/super-login/users' '/v1/matching/find-jeebers' \
  'devtool_shell.dart' 'main_devtool.dart' 'DevToolApp' 'DevGatewayClient' \
  'ScenarioUsers' 'FullRoster' 'location_simulation' 'devtool_shake' \
  'JEEB_DEVTOOL_ENABLED=true' 'JEEB_MOCK_BASE_URL' 'USE_MOCK_GATEWAY=true'; do
  printf ' %s' "${forbidden}" >>"${binary}"
  if run_inspector true false false >/dev/null 2>&1; then
    printf 'Internal inspector accepted forbidden marker: %s\n' "${forbidden}" >&2
    exit 1
  fi
  printf '%s' "${safe_binary}" >"${binary}"
done

for flags in 'false false false' 'true true false' 'true false true'; do
  read -r internal clarity privacy <<<"${flags}"
  if run_inspector "${internal}" "${clarity}" "${privacy}" >/dev/null 2>&1; then
    printf 'Internal inspector accepted policy drift: %s\n' "${flags}" >&2
    exit 1
  fi
done

printf '%s\n' 'Android internal-release payload positive and negative controls passed.'
