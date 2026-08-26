#!/usr/bin/env bash

set -euo pipefail

MANIFEST_PAYLOAD="${1:-}"
RESOURCES_PAYLOAD="${2:-}"
APP_BINARY="${3:-}"
EXPECTED_GATEWAY_URL="${4:-}"
EXPECTED_REALTIME_SOCKET_URL="${5:-}"
CLARITY_ENABLED="${JEEB_CLARITY_ENABLED:-}"
CLARITY_PRIVACY_APPROVED="${JEEB_CLARITY_PRIVACY_APPROVED:-}"

fail() {
  printf 'Android release payload inspection failed: %s\n' "$1" >&2
  exit 1
}

for payload in "${MANIFEST_PAYLOAD}" "${RESOURCES_PAYLOAD}" "${APP_BINARY}"; do
  [[ -s "${payload}" ]] || fail "required payload is missing: ${payload}"
done
[[ "${EXPECTED_GATEWAY_URL}" == https://app.jeeb.fds-1.com ]] ||
  fail 'staging gateway contract drifted'
[[ "${EXPECTED_REALTIME_SOCKET_URL}" == wss://app.jeeb.fds-1.com/socket/websocket ]] ||
  fail 'staging realtime socket contract drifted'
[[ "${CLARITY_ENABLED}" == false ]] ||
  fail 'JEEB_CLARITY_ENABLED must be explicitly false for this candidate'
[[ "${CLARITY_PRIVACY_APPROVED}" == false ]] ||
  fail 'JEEB_CLARITY_PRIVACY_APPROVED must be explicitly false for this candidate'
LC_ALL=C grep -aFq "${EXPECTED_GATEWAY_URL}" "${APP_BINARY}" ||
  fail 'staging gateway is absent from the compiled application'
LC_ALL=C grep -aFq "${EXPECTED_REALTIME_SOCKET_URL}" "${APP_BINARY}" ||
  fail 'staging realtime socket is absent from the compiled application'

for payload in "${MANIFEST_PAYLOAD}" "${RESOURCES_PAYLOAD}" "${APP_BINARY}"; do
  if LC_ALL=C grep -aEiq \
    '192\.168\.2\.(39|50)|10\.0\.2\.2|emulator-|http://(localhost|127\.0\.0\.1)|api\.jeeb\.app|unified[_-]?payment|/v1/payments/|/v1/matching/(find-jeebers|broadcast)|super[_-]?login|devtool_shell\.dart|main_devtool\.dart|main_android_internal\.dart|DevToolApp|InternalDevToolApp|internal_devtool_root|Jeeb Internal QA|JEEB_DEVTOOL_ENABLED=true|JEEB_INTERNAL_RELEASE=true' \
    "${payload}"; then
    fail "forbidden endpoint, emulator, payment, or developer material reached ${payload}"
  fi
done

printf '%s\n' \
  'Android release payload has staging-only networking, no developer seams, and Clarity explicitly disabled.'
