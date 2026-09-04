#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_PATH="${1:-${REPO_ROOT}/android/app/google-services.json}"
CONTRACT="${REPO_ROOT}/contracts/jeeb-firebase-v1.json"
APPS="${REPO_ROOT}/contracts/jeeb-mobile-firebase-apps-v1.json"
REQUIRED_PLAY_APP_SIGNING_SHA1="2E:CF:AF:7F:13:AB:9E:B5:34:E4:04:AD:3B:A9:F6:B2:A1:EA:77:12"
EXPECTED_UPLOAD_SHA1="${ANDROID_UPLOAD_CERT_SHA1:-}"
EXPECTED_UPLOAD_SHA256="${ANDROID_UPLOAD_CERT_SHA256:-}"
EXPECTED_UPLOAD_OAUTH_CLIENT_ID="${ANDROID_FIREBASE_UPLOAD_OAUTH_CLIENT_ID:-}"
EXPECTED_PLAY_OAUTH_CLIENT_ID="${ANDROID_FIREBASE_PLAY_OAUTH_CLIENT_ID:-}"

fail() {
  printf 'Android Firebase config invalid: %s\n' "$1" >&2
  exit 1
}

[[ -s "${CONFIG_PATH}" ]] || fail 'config file is missing or empty'
command -v jq >/dev/null 2>&1 || fail 'jq is required for structural validation'
bash "${REPO_ROOT}/tool/validate_jeeb_firebase_contract.sh" >/dev/null
REQUIRED_PROJECT_ID="$(jq -r '.projectId' "${CONTRACT}")"
REQUIRED_PROJECT_NUMBER="$(jq -r '.projectNumber' "${CONTRACT}")"
REQUIRED_PACKAGE="$(jq -r '.android.store.packageName' "${APPS}")"
EXPECTED_APP_ID="$(jq -r '.android.store.appId' "${APPS}")"
[[ "${EXPECTED_UPLOAD_SHA1}" =~ ^([0-9A-Fa-f]{2}:){19}[0-9A-Fa-f]{2}$ ]] ||
  fail 'approved upload SHA-1 fingerprint is missing or malformed'
[[ "${EXPECTED_UPLOAD_SHA256}" =~ ^([0-9A-Fa-f]{2}:){31}[0-9A-Fa-f]{2}$ ]] ||
  fail 'approved upload SHA-256 fingerprint is missing or malformed'
[[ "${EXPECTED_UPLOAD_OAUTH_CLIENT_ID}" =~ ^${REQUIRED_PROJECT_NUMBER}-[0-9A-Za-z_-]+\.apps\.googleusercontent\.com$ ]] ||
  fail 'approved upload OAuth client identity is missing or malformed'
[[ "${EXPECTED_PLAY_OAUTH_CLIENT_ID}" =~ ^${REQUIRED_PROJECT_NUMBER}-[0-9A-Za-z_-]+\.apps\.googleusercontent\.com$ ]] ||
  fail 'approved Play app-signing OAuth client identity is missing or malformed'
[[ "${EXPECTED_UPLOAD_OAUTH_CLIENT_ID}" != "${EXPECTED_PLAY_OAUTH_CLIENT_ID}" ]] ||
  fail 'upload and Play app-signing OAuth clients must be distinct'

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
upload_sha1_compact="$(printf '%s' "${EXPECTED_UPLOAD_SHA1}" | tr -d ':' | tr '[:lower:]' '[:upper:]')"
play_sha1_compact="$(printf '%s' "${REQUIRED_PLAY_APP_SIGNING_SHA1}" | tr -d ':' | tr '[:lower:]' '[:upper:]')"
upload_oauth_match_count="$(jq --arg package "${REQUIRED_PACKAGE}" \
  --arg sha1 "${upload_sha1_compact}" \
  --arg client_id "${EXPECTED_UPLOAD_OAUTH_CLIENT_ID}" \
  '[.client[]? | select(.client_info.android_client_info.package_name == $package) | .oauth_client[]? | select(.client_type == 1 and .client_id == $client_id and .android_info.package_name == $package and ((.android_info.certificate_hash // "") | ascii_upcase) == $sha1)] | length' \
  "${CONFIG_PATH}")"
play_oauth_match_count="$(jq --arg package "${REQUIRED_PACKAGE}" \
  --arg sha1 "${play_sha1_compact}" \
  --arg client_id "${EXPECTED_PLAY_OAUTH_CLIENT_ID}" \
  '[.client[]? | select(.client_info.android_client_info.package_name == $package) | .oauth_client[]? | select(.client_type == 1 and .client_id == $client_id and .android_info.package_name == $package and ((.android_info.certificate_hash // "") | ascii_upcase) == $sha1)] | length' \
  "${CONFIG_PATH}")"

[[ "${project_id}" == "${REQUIRED_PROJECT_ID}" ]] ||
  fail 'project identity does not match the canonical Firebase project'
[[ "${project_number}" == "${REQUIRED_PROJECT_NUMBER}" ]] ||
  fail 'project number does not match the canonical Firebase project'
[[ "${app_id}" == "${EXPECTED_APP_ID}" ]] ||
  fail 'Google app identity does not match the protected expected value'
[[ "${app_id}" =~ ^1:${REQUIRED_PROJECT_NUMBER}:android:[0-9a-fA-F]{16,64}$ ]] ||
  fail 'Google app identity has an invalid shape'
[[ "${api_key}" =~ ^AIza[0-9A-Za-z_-]{35}$ ]] || fail 'Firebase API key has an invalid shape'
[[ "${upload_oauth_match_count}" == 1 ]] ||
  fail 'upload SHA-1 is not bound to the approved Android OAuth client'
[[ "${play_oauth_match_count}" == 1 ]] ||
  fail 'Play app-signing SHA-1 is not bound to the approved Android OAuth client'

if grep -Eiq 'TODO_|PLACEHOLDER|CHANGEME|REPLACE[_ -]?ME|NOT[_ -]?REAL' \
  "${CONFIG_PATH}"; then
  fail 'config contains a placeholder value'
fi

printf '%s\n' \
  'Android Firebase project, upload/Play OAuth signers, and protected identity match.'
