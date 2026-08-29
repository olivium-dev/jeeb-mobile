#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "${TMP_DIR}"' EXIT HUP INT TERM

manifest="${TMP_DIR}/manifest.pb"
resources="${TMP_DIR}/resources.pb"
binary="${TMP_DIR}/libapp.so"
english_arb="${TMP_DIR}/app_en.arb"
safe_manifest='com.olivium.jeeb com.olivium.jeeb.MainActivity com.olivium.jeeb.DevToolLauncher android.intent.action.MAIN android.intent.category.LAUNCHER'
safe_binary='https://app.jeeb.fds-1.com wss://app.jeeb.fds-1.com/socket/websocket Jeeber Dev Tool Gesture Logging Super Login Screen Catalog Actions Location Simulator Server URL Clear Local Data Scenario Users Apply & Restart Close Dev Tool without restarting /api/User/user-id-login /api/User/super-login/users'
safe_arb='{"internalDevToolRosterErrorUnreachable":"Could not reach the Dev Tool server."}'
printf '%s' "${safe_manifest}" >"${manifest}"
printf '%s' 'Jeeber Dev Tool firebase maps' >"${resources}"
printf '%s' "${safe_binary}" >"${binary}"
printf '%s' "${safe_arb}" >"${english_arb}"

run_inspector() {
  JEEB_INTERNAL_RELEASE="${1}" \
  JEEB_DEVTOOL_ENABLED="${2}" \
  JEEB_STAGING_DEVTOOL="${3}" \
  JEEB_CLARITY_ENABLED="${4}" \
  JEEB_CLARITY_PRIVACY_APPROVED="${5}" \
    bash "${REPO_ROOT}/tool/inspect_android_internal_release_payload.sh" \
      "${manifest}" "${resources}" "${binary}" "${english_arb}" \
      https://app.jeeb.fds-1.com \
      wss://app.jeeb.fds-1.com/socket/websocket
}

run_inspector true true true false false >/dev/null

for missing_launcher_marker in \
  'com.olivium.jeeb.MainActivity' \
  'com.olivium.jeeb.DevToolLauncher' \
  'android.intent.action.MAIN' \
  'android.intent.category.LAUNCHER'; do
  printf '%s' "${safe_manifest/${missing_launcher_marker}/}" >"${manifest}"
  if run_inspector true true true false false >/dev/null 2>&1; then
    printf 'Internal inspector accepted missing launcher marker: %s\n' \
      "${missing_launcher_marker}" >&2
    exit 1
  fi
done
printf '%s' "${safe_manifest}" >"${manifest}"

for required_tool_marker in \
  'Jeeber Dev Tool' \
  'Gesture Logging' \
  'Super Login' \
  'Screen Catalog' \
  'Actions' \
  'Location Simulator' \
  'Server URL' \
  'Clear Local Data' \
  'Scenario Users' \
  'Apply & Restart' \
  'Close Dev Tool without restarting' \
  '/api/User/user-id-login' \
  '/api/User/super-login/users'; do
  printf '%s' "${safe_binary/${required_tool_marker}/}" >"${binary}"
  if run_inspector true true true false false >/dev/null 2>&1; then
    printf 'Internal inspector accepted missing full-tool marker: %s\n' \
      "${required_tool_marker}" >&2
    exit 1
  fi
done
printf '%s' "${safe_binary}" >"${binary}"

for missing_mode in empty absent; do
  if [[ "${missing_mode}" == empty ]]; then
    : >"${english_arb}"
  else
    rm -f -- "${english_arb}"
  fi
  if run_inspector true true true false false >/dev/null 2>&1; then
    printf 'Internal inspector accepted %s English ARB payload\n' \
      "${missing_mode}" >&2
    exit 1
  fi
done
printf '%s' "${safe_arb}" >"${english_arb}"

for invalid_arb in \
  '{}' \
  '{"internalDevToolRosterErrorUnreachable":false}' \
  'not-json'; do
  printf '%s' "${invalid_arb}" >"${english_arb}"
  if run_inspector true true true false false >/dev/null 2>&1; then
    printf 'Internal inspector accepted invalid English ARB: %s\n' \
      "${invalid_arb}" >&2
    exit 1
  fi
done
printf '%s' "${safe_arb}" >"${english_arb}"

for forbidden_arb in \
  '192.168.2.50' \
  '/api/User/super-login/users' \
  'unified_payment'; do
  jq --arg forbidden "${forbidden_arb}" \
    '.forbiddenTestValue = $forbidden' <<<"${safe_arb}" >"${english_arb}"
  if run_inspector true true true false false >/dev/null 2>&1; then
    printf 'Internal inspector accepted forbidden ARB marker: %s\n' \
      "${forbidden_arb}" >&2
    exit 1
  fi
done
printf '%s' "${safe_arb}" >"${english_arb}"

for forbidden in \
  '192.168.2.39' '192.168.2.50' '10.0.2.2' 'emulator-5554' \
  'http://localhost' 'http://127.0.0.1' 'https://api.jeeb.app' ':10069' \
  'unified_payment' '/v1/payments/' '/api/auth/token' \
  '/v1/matching/find-jeebers' 'JEEB_MOCK_BASE_URL' \
  'USE_MOCK_GATEWAY=true'; do
  printf ' %s' "${forbidden}" >>"${binary}"
  if run_inspector true true true false false >/dev/null 2>&1; then
    printf 'Internal inspector accepted forbidden marker: %s\n' "${forbidden}" >&2
    exit 1
  fi
  printf '%s' "${safe_binary}" >"${binary}"
done

for flags in \
  'false true true false false' \
  'true false true false false' \
  'true true false false false' \
  'true true true true false' \
  'true true true false true'; do
  read -r internal devtool staging clarity privacy <<<"${flags}"
  if run_inspector "${internal}" "${devtool}" "${staging}" \
    "${clarity}" "${privacy}" >/dev/null 2>&1; then
    printf 'Internal inspector accepted policy drift: %s\n' "${flags}" >&2
    exit 1
  fi
done

printf '%s\n' 'Android internal-release payload positive and negative controls passed.'
