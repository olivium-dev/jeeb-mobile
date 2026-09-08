#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_PATH="${1:-${REPO_ROOT}/ios/Runner/GoogleService-Info.plist}"
CONTRACT="${REPO_ROOT}/contracts/jeeb-firebase-v1.json"
APPS="${REPO_ROOT}/contracts/jeeb-mobile-firebase-apps-v1.json"
FIREBASE_VARIANT="${IOS_FIREBASE_VARIANT:-store}"
EXPECTED_CLIENT_ID="${IOS_FIREBASE_EXPECTED_CLIENT_ID:-}"
EXPECTED_REVERSED_CLIENT_ID="${IOS_FIREBASE_EXPECTED_REVERSED_CLIENT_ID:-}"

fail() {
  printf 'iOS Firebase config invalid: %s\n' "$1" >&2
  exit 1
}

if [[ ! -s "${CONFIG_PATH}" ]]; then
  fail 'config file is missing or empty; inject the protected production config'
fi

if [[ ! -x /usr/libexec/PlistBuddy ]]; then
  fail 'PlistBuddy is required for structural validation'
fi
command -v jq >/dev/null 2>&1 || fail 'jq is required for contract validation'
bash "${REPO_ROOT}/tool/validate_jeeb_firebase_contract.sh" >/dev/null

case "${FIREBASE_VARIANT}" in
  dev | store) ;;
  *) fail "unknown iOS Firebase variant '${FIREBASE_VARIANT}'" ;;
esac
REQUIRED_PROJECT_ID="$(jq -r '.projectId' "${CONTRACT}")"
REQUIRED_PROJECT_NUMBER="$(jq -r '.projectNumber' "${CONTRACT}")"
REQUIRED_BUNDLE_ID="$(jq -r --arg variant "${FIREBASE_VARIANT}" \
  '.ios[$variant].bundleId' "${APPS}")"
EXPECTED_APP_ID="$(jq -r --arg variant "${FIREBASE_VARIANT}" \
  '.ios[$variant].appId' "${APPS}")"

if ! plutil -lint "${CONFIG_PATH}" >/dev/null 2>&1; then
  fail 'config is not a valid plist'
fi

[[ "${EXPECTED_CLIENT_ID}" =~ ^${REQUIRED_PROJECT_NUMBER}-[0-9A-Za-z_-]+\.apps\.googleusercontent\.com$ ]] ||
  fail 'protected approved Google Sign-In client identity is missing or malformed'
expected_client_subject="${EXPECTED_CLIENT_ID%.apps.googleusercontent.com}"
[[ "${EXPECTED_REVERSED_CLIENT_ID}" == "com.googleusercontent.apps.${expected_client_subject}" ]] ||
  fail 'protected approved Google Sign-In client pair is missing or mismatched'

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

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "${CONFIG_PATH}" 2>/dev/null || true
}

project_id="$(plist_value PROJECT_ID)"
bundle_id="$(plist_value BUNDLE_ID)"
app_id="$(plist_value GOOGLE_APP_ID)"
sender_id="$(plist_value GCM_SENDER_ID)"
api_key="$(plist_value API_KEY)"
plist_version="$(plist_value PLIST_VERSION)"
gcm_enabled="$(plist_value IS_GCM_ENABLED)"
client_id="$(plist_value CLIENT_ID)"
reversed_client_id="$(plist_value REVERSED_CLIENT_ID)"
signin_enabled="$(plist_value IS_SIGNIN_ENABLED)"

[[ "${project_id}" == "${REQUIRED_PROJECT_ID}" ]] ||
  fail 'project identity does not match the canonical Firebase project'
[[ "${sender_id}" == "${REQUIRED_PROJECT_NUMBER}" ]] ||
  fail 'project number does not match the canonical Firebase project'
[[ "${bundle_id}" == "${REQUIRED_BUNDLE_ID}" ]] ||
  fail 'bundle identity does not match the canonical iOS application'
[[ "${app_id}" == "${EXPECTED_APP_ID}" ]] ||
  fail 'Google app identity does not match the protected expected value'
[[ "${app_id}" =~ ^1:${REQUIRED_PROJECT_NUMBER}:ios:[0-9a-fA-F]{16,64}$ ]] ||
  fail 'Google app identity has an invalid shape'
[[ "${api_key}" =~ ^AIza[0-9A-Za-z_-]{35}$ ]] ||
  fail 'Firebase API key has an invalid shape'
[[ "${plist_version}" == "1" ]] ||
  fail 'plist version must be 1'
[[ "${gcm_enabled}" == "true" ]] ||
  fail 'FCM must be enabled in the production config'
[[ "${client_id}" =~ ^[0-9]+-[0-9A-Za-z_-]+\.apps\.googleusercontent\.com$ ]] ||
  fail 'Google Sign-In client id is missing or malformed'
[[ "${reversed_client_id}" =~ ^com\.googleusercontent\.apps\.[0-9]+-[0-9A-Za-z_-]+$ ]] ||
  fail 'Google Sign-In reversed client id is missing or malformed'
[[ "${client_id}" == "${EXPECTED_CLIENT_ID}" ]] ||
  fail 'Google Sign-In client id does not match the protected approved identity'
[[ "${reversed_client_id}" == "${EXPECTED_REVERSED_CLIENT_ID}" ]] ||
  fail 'Google Sign-In reversed client id does not match the protected approved identity'
client_subject="${client_id%.apps.googleusercontent.com}"
[[ "${reversed_client_id}" == "com.googleusercontent.apps.${client_subject}" ]] ||
  fail 'Google Sign-In client ids do not form a matching pair'
[[ "${signin_enabled}" == "true" ]] ||
  fail 'Google Sign-In must be enabled in the selected config'

if grep -Eiq 'TODO_|PLACEHOLDER|CHANGEME|REPLACE[_ -]?ME|NOT[_ -]?REAL' \
  "${CONFIG_PATH}"; then
  fail 'config contains a placeholder value'
fi

printf '%s\n' \
  "iOS Firebase ${FIREBASE_VARIANT} project, bundle, app, and protected Google client pair match."
