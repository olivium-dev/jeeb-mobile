#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_PATH="${1:-${REPO_ROOT}/android/app/google-services.json}"
REQUIRED_PROJECT_ID="jeeb-5a293"
REQUIRED_PACKAGE="com.olivium.jeeb"
EXPECTED_APP_ID="${ANDROID_FIREBASE_EXPECTED_APP_ID:-}"
EXPECTED_SHA1="${ANDROID_FIREBASE_EXPECTED_SHA1:-}"

fail() {
  printf 'Android Firebase config invalid: %s\n' "$1" >&2
  exit 1
}

[[ -s "${CONFIG_PATH}" ]] || fail 'config file is missing or empty'
command -v jq >/dev/null 2>&1 || fail 'jq is required for structural validation'
[[ -n "${EXPECTED_APP_ID}" ]] || fail 'protected expected Firebase app identity is missing'
[[ "${EXPECTED_SHA1}" =~ ^([0-9A-Fa-f]{2}:){19}[0-9A-Fa-f]{2}$ ]] ||
  fail 'approved release SHA-1 fingerprint is missing or malformed'

if file_mode="$(stat -f '%Lp' "${CONFIG_PATH}" 2>/dev/null)"; then
  :
elif file_mode="$(stat -c '%a' "${CONFIG_PATH}" 2>/dev/null)"; then
  :
else
  fail 'could not verify config file permissions'
fi
if (( (8#${file_mode}) & 8#077 )); then
  fail 'config permissions must be owner-only (0600)'
fi

jq -e . "${CONFIG_PATH}" >/dev/null 2>&1 || fail 'config is not valid JSON'

project_id="$(jq -r '.project_info.project_id // empty' "${CONFIG_PATH}")"
project_number="$(jq -r '.project_info.project_number // empty' "${CONFIG_PATH}")"
client_count="$(jq --arg package "${REQUIRED_PACKAGE}" \
  '[.client[]? | select(.client_info.android_client_info.package_name == $package)] | length' \
  "${CONFIG_PATH}")"
[[ "${client_count}" == 1 ]] || fail 'config must contain exactly one canonical Android client'

app_id="$(jq -r --arg package "${REQUIRED_PACKAGE}" \
  '.client[]? | select(.client_info.android_client_info.package_name == $package) | .client_info.mobilesdk_app_id' \
  "${CONFIG_PATH}")"
api_key="$(jq -r --arg package "${REQUIRED_PACKAGE}" \
  '.client[]? | select(.client_info.android_client_info.package_name == $package) | .api_key[0].current_key // empty' \
  "${CONFIG_PATH}")"
expected_sha1_compact="$(printf '%s' "${EXPECTED_SHA1}" | tr -d ':' | tr '[:lower:]' '[:upper:]')"
oauth_match_count="$(jq --arg package "${REQUIRED_PACKAGE}" --arg sha1 "${expected_sha1_compact}" \
  '[.client[]? | select(.client_info.android_client_info.package_name == $package) | .oauth_client[]? | select(.client_type == 1 and .android_info.package_name == $package and ((.android_info.certificate_hash // "") | ascii_upcase) == $sha1)] | length' \
  "${CONFIG_PATH}")"

[[ "${project_id}" == "${REQUIRED_PROJECT_ID}" ]] ||
  fail 'project identity does not match the canonical Firebase project'
[[ "${project_number}" =~ ^[1-9][0-9]{5,}$ ]] || fail 'project number is missing or malformed'
[[ "${app_id}" == "${EXPECTED_APP_ID}" ]] ||
  fail 'Google app identity does not match the protected expected value'
[[ "${app_id}" =~ ^1:${project_number}:android:[0-9a-fA-F]{16,64}$ ]] ||
  fail 'Google app identity has an invalid shape'
[[ "${api_key}" =~ ^AIza[0-9A-Za-z_-]{35}$ ]] || fail 'Firebase API key has an invalid shape'
[[ "${oauth_match_count}" -ge 1 ]] ||
  fail 'release SHA-1 is not bound to an Android OAuth client'

if grep -Eiq 'TODO_|PLACEHOLDER|CHANGEME|REPLACE[_ -]?ME|NOT[_ -]?REAL' \
  "${CONFIG_PATH}"; then
  fail 'config contains a placeholder value'
fi

printf '%s\n' 'Android Firebase config structure, permissions, OAuth signer, and protected identity match.'
