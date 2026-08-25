#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "${TMP_DIR}"' EXIT HUP INT TERM

manifest="${TMP_DIR}/manifest.pb"
resources="${TMP_DIR}/resources.pb"
binary="${TMP_DIR}/libapp.so"
printf '%s' 'com.olivium.jeeb app.jeeb.fds-1.com' >"${manifest}"
printf '%s' 'firebase maps' >"${resources}"
printf '%s' 'https://app.jeeb.fds-1.com safe-release' >"${binary}"

run_inspector() {
  JEEB_CLARITY_ENABLED="${1}" \
  JEEB_CLARITY_PRIVACY_APPROVED="${2}" \
    bash "${REPO_ROOT}/tool/inspect_android_release_payload.sh" \
      "${manifest}" "${resources}" "${binary}" \
      https://app.jeeb.fds-1.com
}

run_inspector false false >/dev/null

for forbidden in \
  '192.168.2.39' \
  '192.168.2.50' \
  '10.0.2.2' \
  'emulator-5554' \
  'http://localhost' \
  'http://127.0.0.1' \
  'https://api.jeeb.app' \
  'super_login' \
  'unified_payment' \
  '/v1/payments/' \
  'devtool_shell.dart' \
  'main_devtool.dart' \
  'DevToolApp' \
  'JEEB_DEVTOOL_ENABLED=true'; do
  printf ' %s' "${forbidden}" >>"${binary}"
  if run_inspector false false >/dev/null 2>&1; then
    printf 'Inspector accepted forbidden release marker: %s\n' \
      "${forbidden}" >&2
    exit 1
  fi
  printf '%s' 'https://app.jeeb.fds-1.com safe-release' >"${binary}"
done

if run_inspector true false >/dev/null 2>&1; then
  printf '%s\n' 'Inspector accepted Clarity enabled.' >&2
  exit 1
fi
if run_inspector false true >/dev/null 2>&1; then
  printf '%s\n' 'Inspector accepted Clarity privacy approval.' >&2
  exit 1
fi

printf '%s\n' 'Android release payload negative controls passed.'
