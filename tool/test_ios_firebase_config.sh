#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATOR="${REPO_ROOT}/tool/validate_ios_google_service_info.sh"
MAPS_VALIDATOR="${REPO_ROOT}/tool/validate_ios_maps_api_key.sh"
WRAPPER="${REPO_ROOT}/tool/run_with_ios_firebase_config.sh"
DEV_WRAPPER="${REPO_ROOT}/tool/run_with_ios_dev_firebase_config.sh"
TARGET="${REPO_ROOT}/ios/Runner/GoogleService-Info.plist"
PROTECTED_XCCONFIG="${REPO_ROOT}/ios/Flutter/ProtectedFirebase.xcconfig"
SYNTHETIC_SENDER_ID="1051234312170"
EXPECTED_APP_ID="1:${SYNTHETIC_SENDER_ID}:ios:1036d2eaaf63036a23dc93"
DEV_SENDER_ID="313705546061"
DEV_EXPECTED_APP_ID="1:${DEV_SENDER_ID}:ios:800ef6ec4bf51312b6f704"
DEV_CLIENT_ID="${DEV_SENDER_ID}-syntheticfixture.apps.googleusercontent.com"
DEV_REVERSED_CLIENT_ID="com.googleusercontent.apps.${DEV_SENDER_ID}-syntheticfixture"
STORE_BUNDLE_ID="com.olivium.jeeb"
DEV_BUNDLE_ID="app.jeeb.jeebMobile.dev"
SYNTHETIC_CLIENT_ID="${SYNTHETIC_SENDER_ID}-syntheticfixture.apps.googleusercontent.com"
SYNTHETIC_REVERSED_CLIENT_ID="com.googleusercontent.apps.${SYNTHETIC_SENDER_ID}-syntheticfixture"
SYNTHETIC_API_KEY="AIza$(printf 'A%.0s' {1..35})"
SYNTHETIC_MAPS_KEY="AIza$(printf 'M%.0s' {1..35})"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf -- "${TMP_DIR}"
}
trap cleanup EXIT HUP INT TERM

write_valid_fixture() {
  local path="$1"
  local bundle_id="${2:-${STORE_BUNDLE_ID}}"
  local app_id="${3:-${EXPECTED_APP_ID}}"
  local project_id=jeeb-5a293 sender_id="${SYNTHETIC_SENDER_ID}"
  local client_id="${SYNTHETIC_CLIENT_ID}" reversed_id="${SYNTHETIC_REVERSED_CLIENT_ID}"
  if [[ "${bundle_id}" == "${DEV_BUNDLE_ID}" ]]; then
    project_id=jeeb-development-msi
    sender_id="${DEV_SENDER_ID}"
    client_id="${DEV_CLIENT_ID}"
    reversed_id="${DEV_REVERSED_CLIENT_ID}"
  fi
  cp "${REPO_ROOT}/ios/Runner/GoogleService-Info.plist.template" "${path}"
  /usr/libexec/PlistBuddy -c "Set :API_KEY ${SYNTHETIC_API_KEY}" "${path}"
  /usr/libexec/PlistBuddy -c "Set :GCM_SENDER_ID ${sender_id}" "${path}"
  /usr/libexec/PlistBuddy -c "Set :PROJECT_ID ${project_id}" "${path}"
  /usr/libexec/PlistBuddy -c "Set :STORAGE_BUCKET ${project_id}.appspot.com" "${path}"
  /usr/libexec/PlistBuddy -c "Set :BUNDLE_ID ${bundle_id}" "${path}"
  /usr/libexec/PlistBuddy -c "Set :GOOGLE_APP_ID ${app_id}" "${path}"
  /usr/libexec/PlistBuddy -c "Set :CLIENT_ID ${client_id}" "${path}"
  /usr/libexec/PlistBuddy -c \
    "Set :REVERSED_CLIENT_ID ${reversed_id}" "${path}"
  chmod 0600 "${path}"
}

expect_failure() {
  local label="$1"
  local path="$2" variant="${3:-store}"
  local client_id="${SYNTHETIC_CLIENT_ID}" reversed_id="${SYNTHETIC_REVERSED_CLIENT_ID}"
  if [[ "${variant}" == dev ]]; then
    client_id="${DEV_CLIENT_ID}"
    reversed_id="${DEV_REVERSED_CLIENT_ID}"
  fi
  if IOS_FIREBASE_VARIANT="${variant}" \
    IOS_FIREBASE_EXPECTED_CLIENT_ID="${client_id}" \
    IOS_FIREBASE_EXPECTED_REVERSED_CLIENT_ID="${reversed_id}" \
    bash "${VALIDATOR}" "${path}" >/dev/null 2>&1; then
    printf 'Expected validator failure: %s\n' "${label}" >&2
    exit 1
  fi
}

valid="${TMP_DIR}/valid.plist"
write_valid_fixture "${valid}"
IOS_FIREBASE_EXPECTED_CLIENT_ID="${SYNTHETIC_CLIENT_ID}" \
  IOS_FIREBASE_EXPECTED_REVERSED_CLIENT_ID="${SYNTHETIC_REVERSED_CLIENT_ID}" \
  bash "${VALIDATOR}" "${valid}" >/dev/null

for missing_input in \
  IOS_FIREBASE_EXPECTED_CLIENT_ID \
  IOS_FIREBASE_EXPECTED_REVERSED_CLIENT_ID; do
  if (
    export IOS_FIREBASE_EXPECTED_CLIENT_ID="${SYNTHETIC_CLIENT_ID}"
    export IOS_FIREBASE_EXPECTED_REVERSED_CLIENT_ID="${SYNTHETIC_REVERSED_CLIENT_ID}"
    unset "${missing_input}"
    bash "${VALIDATOR}" "${valid}" >/dev/null 2>&1
  ); then
    printf 'Expected missing protected input failure: %s\n' \
      "${missing_input}" >&2
    exit 1
  fi
done

valid_dev="${TMP_DIR}/valid-dev.plist"
write_valid_fixture "${valid_dev}" "${DEV_BUNDLE_ID}" "${DEV_EXPECTED_APP_ID}"
IOS_FIREBASE_VARIANT=dev \
  IOS_FIREBASE_EXPECTED_CLIENT_ID="${DEV_CLIENT_ID}" \
  IOS_FIREBASE_EXPECTED_REVERSED_CLIENT_ID="${DEV_REVERSED_CLIENT_ID}" \
  bash "${VALIDATOR}" "${valid_dev}" >/dev/null

staging_dev="${TMP_DIR}/staging-dev.plist"
cp "${valid_dev}" "${staging_dev}"
/usr/libexec/PlistBuddy -c 'Set :PROJECT_ID jeeb-5a293' "${staging_dev}"
/usr/libexec/PlistBuddy -c 'Set :GCM_SENDER_ID 1051234312170' "${staging_dev}"
/usr/libexec/PlistBuddy -c \
  'Set :GOOGLE_APP_ID 1:1051234312170:ios:30f909a175df7f5b23dc93' "${staging_dev}"
expect_failure retired-staging-dev-registration "${staging_dev}" dev

development_store="${TMP_DIR}/development-store.plist"
cp "${valid}" "${development_store}"
/usr/libexec/PlistBuddy -c 'Set :PROJECT_ID jeeb-development-msi' "${development_store}"
/usr/libexec/PlistBuddy -c 'Set :GCM_SENDER_ID 313705546061' "${development_store}"
/usr/libexec/PlistBuddy -c "Set :GOOGLE_APP_ID ${DEV_EXPECTED_APP_ID}" "${development_store}"
expect_failure development-project-for-store "${development_store}"

missing_dev_client="${TMP_DIR}/missing-dev-client.plist"
cp "${valid_dev}" "${missing_dev_client}"
/usr/libexec/PlistBuddy -c 'Delete :CLIENT_ID' "${missing_dev_client}"
expect_failure missing-dev-oauth-client "${missing_dev_client}" dev

maps_key="${TMP_DIR}/maps-api-key"
printf '%s\n' "${SYNTHETIC_MAPS_KEY}" >"${maps_key}"
chmod 0600 "${maps_key}"
bash "${MAPS_VALIDATOR}" "${maps_key}" >/dev/null

invalid_maps_key="${TMP_DIR}/invalid-maps-api-key"
printf '%s\n' 'TODO_IOS_MAPS_API_KEY' >"${invalid_maps_key}"
chmod 0600 "${invalid_maps_key}"
if bash "${MAPS_VALIDATOR}" "${invalid_maps_key}" >/dev/null 2>&1; then
  printf '%s\n' 'Expected iOS Maps placeholder validation failure.' >&2
  exit 1
fi

permissive_maps_key="${TMP_DIR}/permissive-maps-api-key"
cp "${maps_key}" "${permissive_maps_key}"
chmod 0644 "${permissive_maps_key}"
if bash "${MAPS_VALIDATOR}" "${permissive_maps_key}" >/dev/null 2>&1; then
  printf '%s\n' 'Expected iOS Maps file-mode validation failure.' >&2
  exit 1
fi

wrong_bundle="${TMP_DIR}/wrong-bundle.plist"
cp "${valid}" "${wrong_bundle}"
/usr/libexec/PlistBuddy -c 'Set :BUNDLE_ID com.example.wrong' "${wrong_bundle}"
expect_failure wrong-bundle "${wrong_bundle}"

wrong_project="${TMP_DIR}/wrong-project.plist"
cp "${valid}" "${wrong_project}"
/usr/libexec/PlistBuddy -c 'Set :PROJECT_ID wrong-project' "${wrong_project}"
expect_failure wrong-project "${wrong_project}"

wrong_project_number="${TMP_DIR}/wrong-project-number.plist"
cp "${valid}" "${wrong_project_number}"
/usr/libexec/PlistBuddy -c 'Set :GCM_SENDER_ID 999999999999' \
  "${wrong_project_number}"
expect_failure wrong-project-number "${wrong_project_number}"

wrong_app="${TMP_DIR}/wrong-app.plist"
cp "${valid}" "${wrong_app}"
/usr/libexec/PlistBuddy -c 'Set :GOOGLE_APP_ID 1:1051234312170:ios:aaaaaaaaaaaaaaaa' "${wrong_app}"
expect_failure wrong-app "${wrong_app}"

placeholder="${TMP_DIR}/placeholder.plist"
cp "${valid}" "${placeholder}"
/usr/libexec/PlistBuddy -c 'Set :API_KEY TODO_IOS_API_KEY' "${placeholder}"
expect_failure placeholder "${placeholder}"

permissive="${TMP_DIR}/permissive.plist"
cp "${valid}" "${permissive}"
chmod 0644 "${permissive}"
expect_failure permissive-mode "${permissive}"

malformed="${TMP_DIR}/malformed.plist"
printf '%s\n' 'not a plist' >"${malformed}"
chmod 0600 "${malformed}"
expect_failure malformed "${malformed}"

missing_client="${TMP_DIR}/missing-client.plist"
cp "${valid}" "${missing_client}"
/usr/libexec/PlistBuddy -c 'Delete :CLIENT_ID' "${missing_client}"
expect_failure missing-client "${missing_client}"

missing_reversed_client="${TMP_DIR}/missing-reversed-client.plist"
cp "${valid}" "${missing_reversed_client}"
/usr/libexec/PlistBuddy -c 'Delete :REVERSED_CLIENT_ID' \
  "${missing_reversed_client}"
expect_failure missing-reversed-client "${missing_reversed_client}"

wrong_client_pair="${TMP_DIR}/wrong-client-pair.plist"
cp "${valid}" "${wrong_client_pair}"
/usr/libexec/PlistBuddy -c \
  'Set :REVERSED_CLIENT_ID com.googleusercontent.apps.123456789012-other' \
  "${wrong_client_pair}"
expect_failure wrong-client-pair "${wrong_client_pair}"

signin_disabled="${TMP_DIR}/signin-disabled.plist"
cp "${valid}" "${signin_disabled}"
/usr/libexec/PlistBuddy -c 'Set :IS_SIGNIN_ENABLED false' "${signin_disabled}"
expect_failure signin-disabled "${signin_disabled}"

if [[ -e "${TARGET}" || -e "${PROTECTED_XCCONFIG}" ]]; then
  printf '%s\n' 'Refusing wrapper test because protected build inputs exist.' >&2
  exit 1
fi
encoded_fixture="$(base64 <"${valid}" | tr -d '\n')"
if (
  cd "${REPO_ROOT}"
  IOS_GOOGLE_SERVICE_INFO_PLIST_B64="${encoded_fixture}" \
  IOS_FIREBASE_EXPECTED_CLIENT_ID="${SYNTHETIC_CLIENT_ID}" \
  IOS_FIREBASE_EXPECTED_REVERSED_CLIENT_ID="${SYNTHETIC_REVERSED_CLIENT_ID}" \
    bash "${WRAPPER}" true >/dev/null 2>&1
); then
  printf '%s\n' 'Expected wrapper failure without protected Maps input.' >&2
  exit 1
fi
(
  cd "${REPO_ROOT}"
  IOS_GOOGLE_SERVICE_INFO_PLIST_B64="${encoded_fixture}" \
  IOS_FIREBASE_EXPECTED_CLIENT_ID="${SYNTHETIC_CLIENT_ID}" \
  IOS_FIREBASE_EXPECTED_REVERSED_CLIENT_ID="${SYNTHETIC_REVERSED_CLIENT_ID}" \
  IOS_GOOGLE_MAPS_API_KEY_FILE="${maps_key}" \
    bash "${WRAPPER}" bash -c '
      [[ -z "${IOS_GOOGLE_SERVICE_INFO_PLIST_B64:-}" ]]
      [[ -z "${IOS_FIREBASE_EXPECTED_CLIENT_ID:-}" ]]
      [[ -z "${IOS_FIREBASE_EXPECTED_REVERSED_CLIENT_ID:-}" ]]
      [[ -z "${IOS_GOOGLE_MAPS_API_KEY_FILE:-}" ]]
      test -s ios/Runner/GoogleService-Info.plist
      test -s ios/Flutter/ProtectedFirebase.xcconfig
      expected="$(/usr/libexec/PlistBuddy -c \
        "Print :REVERSED_CLIENT_ID" ios/Runner/GoogleService-Info.plist)"
      actual="$(sed -n "s/^GOOGLE_REVERSED_CLIENT_ID = //p" \
        ios/Flutter/ProtectedFirebase.xcconfig)"
      [[ "${actual}" == "${expected}" ]]
      maps_value="$(sed -n "s/^GOOGLE_MAPS_API_KEY = //p" \
        ios/Flutter/ProtectedFirebase.xcconfig)"
      [[ "${maps_value}" =~ ^AIza[A-Za-z0-9_-]{35}$ ]]
    '
)
[[ ! -e "${TARGET}" ]] || {
  printf '%s\n' 'Protected wrapper did not clean the injected plist.' >&2
  exit 1
}
[[ ! -e "${PROTECTED_XCCONFIG}" ]] || {
  printf '%s\n' 'Protected wrapper did not clean the transient xcconfig.' >&2
  exit 1
}

encoded_dev_fixture="$(base64 <"${valid_dev}" | tr -d '\n')"
(
  cd "${REPO_ROOT}"
  IOS_DEV_GOOGLE_SERVICE_INFO_PLIST_B64="${encoded_dev_fixture}" \
  IOS_DEV_FIREBASE_EXPECTED_CLIENT_ID="${DEV_CLIENT_ID}" \
  IOS_DEV_FIREBASE_EXPECTED_REVERSED_CLIENT_ID="${DEV_REVERSED_CLIENT_ID}" \
  IOS_GOOGLE_MAPS_API_KEY_FILE="${maps_key}" \
    bash "${DEV_WRAPPER}" bash -c '
      test -s ios/Runner/GoogleService-Info.plist
      bundle_id="$(/usr/libexec/PlistBuddy -c \
        "Print :BUNDLE_ID" ios/Runner/GoogleService-Info.plist)"
      [[ "${bundle_id}" == app.jeeb.jeebMobile.dev ]]
    '
)
unset encoded_dev_fixture
[[ ! -e "${TARGET}" ]] || {
  printf '%s\n' 'Protected iOS dev wrapper did not clean the injected plist.' >&2
  exit 1
}
[[ ! -e "${PROTECTED_XCCONFIG}" ]] || {
  printf '%s\n' 'Protected iOS dev wrapper did not clean build settings.' >&2
  exit 1
}

printf '%s\n' \
  'iOS store/dev Firebase validators and protected wrapper cleanup passed.'
