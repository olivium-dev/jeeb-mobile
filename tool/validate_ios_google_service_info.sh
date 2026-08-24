#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_PATH="${1:-${REPO_ROOT}/ios/Runner/GoogleService-Info.plist}"
REQUIRED_PROJECT_ID="jeeb-5a293"
REQUIRED_BUNDLE_ID="com.olivium.jeeb"
EXPECTED_APP_ID="${IOS_FIREBASE_EXPECTED_APP_ID:-}"

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

if ! plutil -lint "${CONFIG_PATH}" >/dev/null 2>&1; then
  fail 'config is not a valid plist'
fi

if [[ -z "${EXPECTED_APP_ID}" ]]; then
  fail 'protected expected Firebase app identity is missing'
fi

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
[[ "${bundle_id}" == "${REQUIRED_BUNDLE_ID}" ]] ||
  fail 'bundle identity does not match the canonical iOS application'
[[ "${app_id}" == "${EXPECTED_APP_ID}" ]] ||
  fail 'Google app identity does not match the protected expected value'
[[ "${sender_id}" =~ ^[1-9][0-9]{5,}$ ]] ||
  fail 'GCM sender id is missing or malformed'
[[ "${app_id}" =~ ^1:${sender_id}:ios:[0-9a-fA-F]{16,64}$ ]] ||
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
client_subject="${client_id%.apps.googleusercontent.com}"
[[ "${reversed_client_id}" == "com.googleusercontent.apps.${client_subject}" ]] ||
  fail 'Google Sign-In client ids do not form a matching pair'
[[ "${signin_enabled}" == "true" ]] ||
  fail 'Google Sign-In must be enabled in the production config'

if grep -Eiq 'TODO_|PLACEHOLDER|CHANGEME|REPLACE[_ -]?ME|NOT[_ -]?REAL' \
  "${CONFIG_PATH}"; then
  fail 'config contains a placeholder value'
fi

printf '%s\n' \
  'iOS Firebase config structure, permissions, and protected identity match.'
