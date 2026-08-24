#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_PATH="${REPO_ROOT}/android/app/src/dev/google-services.json"
ENCODED_CONFIG="${DEV_GOOGLE_SERVICES_JSON_B64:-}"

fail() {
  printf 'Protected dev Firebase injection failed: %s\n' "$1" >&2
  exit 1
}

[[ $# -gt 0 ]] || fail 'a build or validation command is required'
[[ -n "${ENCODED_CONFIG}" ]] || fail 'protected JSON input is missing'
[[ -n "${DEV_FIREBASE_EXPECTED_PROJECT_NUMBER:-}" ]] ||
  fail 'protected expected Firebase project number is missing'
[[ -n "${DEV_FIREBASE_EXPECTED_PROJECT_ID:-}" ]] ||
  fail 'protected expected Firebase project identity is missing'
[[ -n "${DEV_FIREBASE_EXPECTED_APP_ID:-}" ]] ||
  fail 'protected expected Firebase app identity is missing'
[[ ! -e "${TARGET_PATH}" ]] || fail 'refusing to overwrite an existing local Firebase config'
if git -C "${REPO_ROOT}" ls-files --error-unmatch \
  android/app/src/dev/google-services.json >/dev/null 2>&1; then
  fail 'the dev Firebase config must never be tracked'
fi

umask 077
DECODED_PATH="$(mktemp)"
created_target=false

cleanup() {
  rm -f -- "${DECODED_PATH}"
  if [[ "${created_target}" == true ]]; then
    rm -f -- "${TARGET_PATH}"
  fi
}
trap cleanup EXIT HUP INT TERM

if printf '%s' "${ENCODED_CONFIG}" | base64 --decode >"${DECODED_PATH}" 2>/dev/null; then
  :
elif printf '%s' "${ENCODED_CONFIG}" | base64 -D >"${DECODED_PATH}" 2>/dev/null; then
  :
else
  fail 'protected JSON input is not valid base64'
fi
unset DEV_GOOGLE_SERVICES_JSON_B64
unset ENCODED_CONFIG

chmod 0600 "${DECODED_PATH}"
bash "${REPO_ROOT}/tool/validate_dev_google_services.sh" "${DECODED_PATH}"
install -m 0600 "${DECODED_PATH}" "${TARGET_PATH}"
created_target=true

"$@"
