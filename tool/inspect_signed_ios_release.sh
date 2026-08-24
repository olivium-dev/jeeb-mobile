#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IPA_PATH="${1:-}"
FIREBASE_CONFIG="${2:-}"
MAPS_KEY_FILE="${3:-}"
EXPECTED_GATEWAY_URL="${4:-}"
TMP_DIR="$(mktemp -d)"

fail() {
  printf 'Signed iOS release inspection failed: %s\n' "$1" >&2
  exit 1
}

cleanup() {
  rm -rf -- "${TMP_DIR}"
}
trap cleanup EXIT HUP INT TERM

[[ -s "${IPA_PATH}" ]] || fail 'IPA is missing'
[[ -s "${FIREBASE_CONFIG}" ]] || fail 'Firebase evidence is missing'
[[ -s "${MAPS_KEY_FILE}" ]] || fail 'Maps evidence is missing'
[[ -n "${EXPECTED_GATEWAY_URL}" ]] || fail 'expected gateway URL is missing'

ditto -x -k "${IPA_PATH}" "${TMP_DIR}"
APP_PATH="$(find "${TMP_DIR}/Payload" -maxdepth 1 -type d -name '*.app' -print -quit)"
[[ -n "${APP_PATH}" ]] || fail 'IPA payload app is missing'

codesign --verify --deep --strict "${APP_PATH}" >/dev/null 2>&1 ||
  fail 'code signature verification failed'

SIGNED_ENTITLEMENTS="${TMP_DIR}/signed-entitlements.plist"
codesign -d --entitlements :- "${APP_PATH}" >"${SIGNED_ENTITLEMENTS}" 2>/dev/null
[[ -s "${SIGNED_ENTITLEMENTS}" ]] || fail 'signed entitlements are missing'

application_identifier="$(/usr/libexec/PlistBuddy -c \
  'Print :application-identifier' "${SIGNED_ENTITLEMENTS}")"
aps_environment="$(/usr/libexec/PlistBuddy -c \
  'Print :aps-environment' "${SIGNED_ENTITLEMENTS}")"
[[ "${application_identifier}" == K5RDQ8J7AN.com.olivium.jeeb ]] ||
  fail 'signed application identifier drifted'
[[ "${aps_environment}" == production ]] ||
  fail 'signed APNs environment is not production'
/usr/libexec/PlistBuddy -c \
  'Print :com.apple.developer.associated-domains' \
  "${SIGNED_ENTITLEMENTS}" 2>/dev/null |
  grep -Fq 'applinks:app.jeeb.fds-1.com' ||
  fail 'signed associated domain is missing'

embedded_profile="${APP_PATH}/embedded.mobileprovision"
[[ -s "${embedded_profile}" ]] || fail 'embedded provisioning profile is missing'
PROFILE_PLIST="${TMP_DIR}/profile.plist"
security cms -D -i "${embedded_profile}" >"${PROFILE_PLIST}" 2>/dev/null
profile_app_identifier="$(/usr/libexec/PlistBuddy -c \
  'Print :Entitlements:application-identifier' "${PROFILE_PLIST}")"
[[ "${profile_app_identifier}" == K5RDQ8J7AN.com.olivium.jeeb ]] ||
  fail 'provisioning profile application identifier drifted'

bash "${REPO_ROOT}/tool/inspect_unsigned_ios_release.sh" \
  "${APP_PATH}" "${FIREBASE_CONFIG}" "${MAPS_KEY_FILE}" \
  "${EXPECTED_GATEWAY_URL}" >/dev/null

info_path="${APP_PATH}/Info.plist"
bundle_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${info_path}")"
short_version="$(/usr/libexec/PlistBuddy -c \
  'Print :CFBundleShortVersionString' "${info_path}")"
[[ "${bundle_version}" == 26082401 ]] || fail 'build number drifted'
[[ "${short_version}" == 1.0.0 ]] || fail 'build name drifted'

printf '%s\n' \
  'Signed iOS identity, entitlements, staging URL, Firebase, Maps, and endpoint contracts passed.'
