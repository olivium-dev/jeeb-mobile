#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_PATH="${REPO_ROOT}/ios/Runner/GoogleService-Info.plist"
PROTECTED_XCCONFIG_PATH="${REPO_ROOT}/ios/Flutter/ProtectedFirebase.xcconfig"
ENCODED_CONFIG="${IOS_GOOGLE_SERVICE_INFO_PLIST_B64:-}"
MAPS_KEY_FILE="${IOS_GOOGLE_MAPS_API_KEY_FILE:-}"

fail() {
  printf 'Protected iOS Firebase injection failed: %s\n' "$1" >&2
  exit 1
}

[[ $# -gt 0 ]] || fail 'a build or validation command is required'
[[ -n "${ENCODED_CONFIG}" ]] || fail 'protected plist input is missing'
[[ -n "${IOS_FIREBASE_EXPECTED_APP_ID:-}" ]] ||
  fail 'protected expected Firebase app identity is missing'
[[ -n "${MAPS_KEY_FILE}" ]] || fail 'protected iOS Maps key file is missing'

if [[ -e "${TARGET_PATH}" ]]; then
  fail 'refusing to overwrite an existing local Firebase plist'
fi
if [[ -e "${PROTECTED_XCCONFIG_PATH}" ]]; then
  fail 'refusing to overwrite existing protected iOS build settings'
fi
if git -C "${REPO_ROOT}" ls-files --error-unmatch \
  ios/Runner/GoogleService-Info.plist >/dev/null 2>&1; then
  fail 'the production Firebase plist must never be tracked'
fi

umask 077
DECODED_PATH="$(mktemp)"
created_target=false
created_xcconfig=false

cleanup() {
  rm -f -- "${DECODED_PATH}"
  if [[ "${created_target}" == true ]]; then
    rm -f -- "${TARGET_PATH}"
  fi
  if [[ "${created_xcconfig}" == true ]]; then
    rm -f -- "${PROTECTED_XCCONFIG_PATH}"
  fi
}
trap cleanup EXIT HUP INT TERM

if printf '%s' "${ENCODED_CONFIG}" | base64 --decode >"${DECODED_PATH}" 2>/dev/null; then
  :
elif printf '%s' "${ENCODED_CONFIG}" | base64 -D >"${DECODED_PATH}" 2>/dev/null; then
  :
else
  fail 'protected plist input is not valid base64'
fi
unset IOS_GOOGLE_SERVICE_INFO_PLIST_B64
unset ENCODED_CONFIG

chmod 0600 "${DECODED_PATH}"
bash "${REPO_ROOT}/tool/validate_ios_google_service_info.sh" "${DECODED_PATH}"
bash "${REPO_ROOT}/tool/validate_ios_maps_api_key.sh" \
  "${MAPS_KEY_FILE}" >/dev/null
install -m 0600 "${DECODED_PATH}" "${TARGET_PATH}"
created_target=true

reversed_client_id="$(
  /usr/libexec/PlistBuddy -c 'Print :REVERSED_CLIENT_ID' "${DECODED_PATH}"
)"
maps_api_key="$(tr -d '\n' <"${MAPS_KEY_FILE}")"
printf 'GOOGLE_REVERSED_CLIENT_ID = %s\nGOOGLE_MAPS_API_KEY = %s\n' \
  "${reversed_client_id}" "${maps_api_key}" \
  >"${PROTECTED_XCCONFIG_PATH}"
created_xcconfig=true
chmod 0600 "${PROTECTED_XCCONFIG_PATH}"
unset reversed_client_id maps_api_key MAPS_KEY_FILE
unset IOS_FIREBASE_EXPECTED_APP_ID
unset IOS_GOOGLE_MAPS_API_KEY_FILE

"$@"
