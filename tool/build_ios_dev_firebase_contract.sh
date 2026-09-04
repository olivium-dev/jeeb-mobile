#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
REQUIRED_FLUTTER_VERSION="$(jq -er '.flutter' "${REPO_ROOT}/.fvmrc")"
TEMPLATE="${REPO_ROOT}/ios/Runner/GoogleService-Info.plist.template"
TMP_DIR="$(mktemp -d)"
CONFIG="${TMP_DIR}/GoogleService-Info.plist"
MAPS_KEY_FILE="${TMP_DIR}/maps-api-key"
SENDER_ID='1051234312170'
APP_ID='1:1051234312170:ios:30f909a175df7f5b23dc93'
CLIENT_ID='1051234312170-syntheticdev.apps.googleusercontent.com'
REVERSED_ID='com.googleusercontent.apps.1051234312170-syntheticdev'
FIREBASE_API_KEY="AIza$(printf 'A%.0s' {1..35})"
MAPS_API_KEY="AIza$(printf 'M%.0s' {1..35})"

cleanup() {
  rm -rf -- "${TMP_DIR}"
}
trap cleanup EXIT HUP INT TERM

flutter_version="$("${FLUTTER_BIN}" --version --machine | jq -er '.frameworkVersion')"
[[ "${flutter_version}" == "${REQUIRED_FLUTTER_VERSION}" ]] || {
  printf 'iOS dev compile requires Flutter %s.\n' \
    "${REQUIRED_FLUTTER_VERSION}" >&2
  exit 1
}

cp "${TEMPLATE}" "${CONFIG}"
/usr/libexec/PlistBuddy -c "Set :API_KEY ${FIREBASE_API_KEY}" "${CONFIG}"
/usr/libexec/PlistBuddy -c "Set :GCM_SENDER_ID ${SENDER_ID}" "${CONFIG}"
/usr/libexec/PlistBuddy -c 'Set :PROJECT_ID jeeb-5a293' "${CONFIG}"
/usr/libexec/PlistBuddy -c 'Set :STORAGE_BUCKET jeeb-5a293.appspot.com' \
  "${CONFIG}"
/usr/libexec/PlistBuddy -c 'Set :BUNDLE_ID app.jeeb.jeebMobile.dev' "${CONFIG}"
/usr/libexec/PlistBuddy -c "Set :GOOGLE_APP_ID ${APP_ID}" "${CONFIG}"
/usr/libexec/PlistBuddy -c "Set :CLIENT_ID ${CLIENT_ID}" "${CONFIG}"
/usr/libexec/PlistBuddy -c "Set :REVERSED_CLIENT_ID ${REVERSED_ID}" "${CONFIG}"
chmod 0600 "${CONFIG}"
printf '%s\n' "${MAPS_API_KEY}" >"${MAPS_KEY_FILE}"
chmod 0600 "${MAPS_KEY_FILE}"

encoded_config="$(base64 <"${CONFIG}" | tr -d '\n')"
(
  cd "${REPO_ROOT}"
  IOS_DEV_GOOGLE_SERVICE_INFO_PLIST_B64="${encoded_config}" \
  IOS_DEV_FIREBASE_EXPECTED_CLIENT_ID="${CLIENT_ID}" \
  IOS_DEV_FIREBASE_EXPECTED_REVERSED_CLIENT_ID="${REVERSED_ID}" \
  IOS_GOOGLE_MAPS_API_KEY_FILE="${MAPS_KEY_FILE}" \
    bash tool/run_with_ios_dev_firebase_config.sh \
      "${FLUTTER_BIN}" build ios --flavor dev --debug --simulator --no-pub \
      --dart-define=APP_FLAVOR=dev \
      --dart-define=REQUIRE_REAL_PUSH=true
)
unset encoded_config

[[ ! -e "${REPO_ROOT}/ios/Runner/GoogleService-Info.plist" ]]
[[ ! -e "${REPO_ROOT}/ios/Flutter/ProtectedFirebase.xcconfig" ]]
bash "${REPO_ROOT}/tool/inspect_ios_dev_firebase_artifact.sh" \
  "${REPO_ROOT}/build/ios/iphonesimulator/Runner.app"

printf '%s\n' \
  'Synthetic iOS dev artifact compiled and passed Firebase inspection.'
