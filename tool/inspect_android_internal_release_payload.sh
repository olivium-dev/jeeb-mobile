#!/usr/bin/env bash

set -euo pipefail

MANIFEST_PAYLOAD="${1:-}"
RESOURCES_PAYLOAD="${2:-}"
APP_BINARY="${3:-}"
ENGLISH_ARB_PAYLOAD="${4:-}"
EXPECTED_GATEWAY_URL="${5:-}"
EXPECTED_REALTIME_SOCKET_URL="${6:-}"
CLARITY_ENABLED="${JEEB_CLARITY_ENABLED:-}"
CLARITY_PRIVACY_APPROVED="${JEEB_CLARITY_PRIVACY_APPROVED:-}"
INTERNAL_RELEASE="${JEEB_INTERNAL_RELEASE:-}"

fail() {
  printf 'Android internal-release inspection failed: %s\n' "$1" >&2
  exit 1
}

for payload in \
  "${MANIFEST_PAYLOAD}" \
  "${RESOURCES_PAYLOAD}" \
  "${APP_BINARY}" \
  "${ENGLISH_ARB_PAYLOAD}"; do
  [[ -s "${payload}" ]] || fail "required payload is missing: ${payload}"
done
[[ "${EXPECTED_GATEWAY_URL}" == https://app.jeeb.fds-1.com ]] ||
  fail 'staging gateway contract drifted'
[[ "${EXPECTED_REALTIME_SOCKET_URL}" == wss://app.jeeb.fds-1.com/socket/websocket ]] ||
  fail 'staging realtime contract drifted'
[[ "${CLARITY_ENABLED}" == false ]] || fail 'Clarity must be explicitly off'
[[ "${CLARITY_PRIVACY_APPROVED}" == false ]] ||
  fail 'Clarity privacy approval must be explicitly off'
[[ "${INTERNAL_RELEASE}" == true ]] ||
  fail 'JEEB_INTERNAL_RELEASE must be explicitly true'

for launcher_marker in \
  'com.olivium.jeeb.MainActivity' \
  'com.olivium.jeeb.DevToolLauncher' \
  'android.intent.action.MAIN' \
  'android.intent.category.LAUNCHER'; do
  LC_ALL=C grep -aFq "${launcher_marker}" "${MANIFEST_PAYLOAD}" ||
    fail "required launcher marker is absent: ${launcher_marker}"
done
LC_ALL=C grep -aFq 'Jeeb Internal QA' "${RESOURCES_PAYLOAD}" ||
  fail 'internal launcher label is absent'
for required in \
  "${EXPECTED_GATEWAY_URL}" \
  "${EXPECTED_REALTIME_SOCKET_URL}" \
  'internal_devtool_root' \
  'internal_devtool_environment' \
  'internal_devtool_auth_mode' \
  'internal_devtool_close'; do
  LC_ALL=C grep -aFq "${required}" "${APP_BINARY}" ||
    fail "required restricted-tool marker is absent: ${required}"
done
jq -e \
  '.internalDevToolNormalSmsOnly == "Normal SMS only"' \
  "${ENGLISH_ARB_PAYLOAD}" >/dev/null ||
  fail 'English ARB does not require normal SMS authentication'

for payload in "${MANIFEST_PAYLOAD}" "${RESOURCES_PAYLOAD}" "${APP_BINARY}"; do
  if LC_ALL=C grep -aEiq \
    '192\.168\.2\.(39|50)|10\.0\.2\.2|emulator-|http://(localhost|127\.0\.0\.1)|api\.jeeb\.app|:[[:digit:]]*10069|unified[_-]?payment|/v1/payments/|/v1/matching/(find-jeebers|broadcast)|/api/auth/token|/api/User/(user-id-login|super-login/users)|super[_-]?login|DefaultSuperLogin|SuperLoginService|SuperLoginDemoUser|devtool_shell\.dart|main_devtool\.dart|(^|[^[:alnum:]_])DevToolApp([^[:alnum:]_]|$)|DevGatewayClient|ScenarioUsers|FullRoster|location_simulation|devtool_shake|JEEB_DEVTOOL_ENABLED=true|JEEB_MOCK_BASE_URL|USE_MOCK_GATEWAY=true' \
    "${payload}"; then
    fail "unsafe endpoint, mutation, auth, payment, or legacy developer material reached ${payload}"
  fi
done

# The shared ARB intentionally carries dormant copy for app surfaces that the
# internal entrypoint cannot reach. Scan it for concrete unsafe infrastructure,
# endpoint, and payment material without treating presentation-only keys as
# executable capability evidence.
if LC_ALL=C grep -aEiq \
  '192\.168\.2\.(39|50)|10\.0\.2\.2|emulator-|http://(localhost|127\.0\.0\.1)|api\.jeeb\.app|:[[:digit:]]*10069|unified[_-]?payment|/v1/payments/|/v1/matching/(find-jeebers|broadcast)|/api/auth/token|/api/User/(user-id-login|super-login/users)|JEEB_MOCK_BASE_URL|USE_MOCK_GATEWAY=true' \
  "${ENGLISH_ARB_PAYLOAD}"; then
  fail "unsafe endpoint, infrastructure, or payment material reached ${ENGLISH_ARB_PAYLOAD}"
fi

printf '%s\n' \
  'Android internal release is restricted, staging-only, Clarity-off, and legacy-devtool free.'
