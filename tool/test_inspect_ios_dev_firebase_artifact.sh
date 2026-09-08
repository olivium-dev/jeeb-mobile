#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSPECTOR="${REPO_ROOT}/tool/inspect_ios_dev_firebase_artifact.sh"
TMP_DIR="$(mktemp -d)"
VALID_APP="${TMP_DIR}/valid/Runner.app"
SYNTHETIC_API_KEY="AIza$(printf 'A%.0s' {1..35})"
SYNTHETIC_MAPS_KEY="AIza$(printf 'M%.0s' {1..35})"
SYNTHETIC_CLIENT_ID='1051234312170-synthetic.apps.googleusercontent.com'
SYNTHETIC_REVERSED_ID='com.googleusercontent.apps.1051234312170-synthetic'

cleanup() {
  rm -rf -- "${TMP_DIR}"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "${VALID_APP}"
cp "${REPO_ROOT}/ios/Runner/Info-dev.plist" "${VALID_APP}/Info.plist"
cp "${REPO_ROOT}/ios/Runner/GoogleService-Info.plist.template" \
  "${VALID_APP}/GoogleService-Info.plist"

/usr/libexec/PlistBuddy -c \
  'Set :CFBundleIdentifier app.jeeb.jeebMobile.dev' "${VALID_APP}/Info.plist"
/usr/libexec/PlistBuddy -c "Set :GMSApiKey ${SYNTHETIC_MAPS_KEY}" \
  "${VALID_APP}/Info.plist"
/usr/libexec/PlistBuddy -c \
  "Set :CFBundleURLTypes:1:CFBundleURLSchemes:0 ${SYNTHETIC_REVERSED_ID}" \
  "${VALID_APP}/Info.plist"

firebase_plist="${VALID_APP}/GoogleService-Info.plist"
/usr/libexec/PlistBuddy -c "Set :API_KEY ${SYNTHETIC_API_KEY}" \
  "${firebase_plist}"
/usr/libexec/PlistBuddy -c 'Set :PROJECT_ID jeeb-5a293' "${firebase_plist}"
/usr/libexec/PlistBuddy -c 'Set :GCM_SENDER_ID 1051234312170' \
  "${firebase_plist}"
/usr/libexec/PlistBuddy -c 'Set :BUNDLE_ID app.jeeb.jeebMobile.dev' \
  "${firebase_plist}"
/usr/libexec/PlistBuddy -c \
  'Set :GOOGLE_APP_ID 1:1051234312170:ios:30f909a175df7f5b23dc93' \
  "${firebase_plist}"
/usr/libexec/PlistBuddy -c "Set :CLIENT_ID ${SYNTHETIC_CLIENT_ID}" \
  "${firebase_plist}"
/usr/libexec/PlistBuddy -c "Set :REVERSED_CLIENT_ID ${SYNTHETIC_REVERSED_ID}" \
  "${firebase_plist}"

bash "${INSPECTOR}" "${VALID_APP}" >/dev/null

expect_failure() {
  local label="$1"
  local candidate="${TMP_DIR}/${label}/Runner.app"
  shift
  mkdir -p "${candidate}"
  cp -R "${VALID_APP}/." "${candidate}/"
  "$@" "${candidate}"
  if bash "${INSPECTOR}" "${candidate}" >/dev/null 2>&1; then
    printf 'Expected iOS dev artifact rejection: %s\n' "${label}" >&2
    exit 1
  fi
}

remove_firebase_plist() {
  find "$1/GoogleService-Info.plist" -delete
}

wrong_project() {
  /usr/libexec/PlistBuddy -c 'Set :PROJECT_ID wrong-project' \
    "$1/GoogleService-Info.plist"
}

wrong_sender() {
  /usr/libexec/PlistBuddy -c 'Set :GCM_SENDER_ID 999999999999' \
    "$1/GoogleService-Info.plist"
}

wrong_app() {
  /usr/libexec/PlistBuddy -c \
    'Set :GOOGLE_APP_ID 1:1051234312170:ios:aaaaaaaaaaaaaaaa' \
    "$1/GoogleService-Info.plist"
}

wrong_bundle() {
  /usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.olivium.jeeb' \
    "$1/Info.plist"
}

expect_failure missing-plist remove_firebase_plist
expect_failure wrong-project wrong_project
expect_failure wrong-sender wrong_sender
expect_failure wrong-app wrong_app
expect_failure wrong-bundle wrong_bundle

invalid_delegate="${TMP_DIR}/AppDelegate-without-firebase.swift"
sed '/FirebaseApp\.configure()/d' \
  "${REPO_ROOT}/ios/Runner/AppDelegate.swift" >"${invalid_delegate}"
if JEEB_IOS_APP_DELEGATE_PATH="${invalid_delegate}" \
  bash "${INSPECTOR}" "${VALID_APP}" >/dev/null 2>&1; then
  printf '%s\n' 'Expected missing native Firebase initialization rejection.' >&2
  exit 1
fi

printf '%s\n' 'iOS dev Firebase artifact negative controls passed.'
