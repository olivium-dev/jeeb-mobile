#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATOR="${REPO_ROOT}/tool/validate_ios_google_service_info.sh"
MAPS_VALIDATOR="${REPO_ROOT}/tool/validate_ios_maps_api_key.sh"
WRAPPER="${REPO_ROOT}/tool/run_with_ios_firebase_config.sh"
TARGET="${REPO_ROOT}/ios/Runner/GoogleService-Info.plist"
PROTECTED_XCCONFIG="${REPO_ROOT}/ios/Flutter/ProtectedFirebase.xcconfig"
SYNTHETIC_SENDER_ID="123456789012"
EXPECTED_APP_ID="1:${SYNTHETIC_SENDER_ID}:ios:0123456789abcdef0123456789abcdef"
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
  cp "${REPO_ROOT}/ios/Runner/GoogleService-Info.plist.template" "${path}"
  /usr/libexec/PlistBuddy -c "Set :API_KEY ${SYNTHETIC_API_KEY}" "${path}"
  /usr/libexec/PlistBuddy -c "Set :GCM_SENDER_ID ${SYNTHETIC_SENDER_ID}" "${path}"
  /usr/libexec/PlistBuddy -c 'Set :PROJECT_ID jeeb-5a293' "${path}"
  /usr/libexec/PlistBuddy -c 'Set :STORAGE_BUCKET jeeb-5a293.appspot.com' "${path}"
  /usr/libexec/PlistBuddy -c "Set :GOOGLE_APP_ID ${EXPECTED_APP_ID}" "${path}"
  /usr/libexec/PlistBuddy -c "Set :CLIENT_ID ${SYNTHETIC_CLIENT_ID}" "${path}"
  /usr/libexec/PlistBuddy -c \
    "Set :REVERSED_CLIENT_ID ${SYNTHETIC_REVERSED_CLIENT_ID}" "${path}"
  chmod 0600 "${path}"
}

expect_failure() {
  local label="$1"
  local path="$2"
  if IOS_FIREBASE_EXPECTED_APP_ID="${EXPECTED_APP_ID}" \
    bash "${VALIDATOR}" "${path}" >/dev/null 2>&1; then
    printf 'Expected validator failure: %s\n' "${label}" >&2
    exit 1
  fi
}

valid="${TMP_DIR}/valid.plist"
write_valid_fixture "${valid}"
IOS_FIREBASE_EXPECTED_APP_ID="${EXPECTED_APP_ID}" \
  bash "${VALIDATOR}" "${valid}" >/dev/null

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
  IOS_FIREBASE_EXPECTED_APP_ID="${EXPECTED_APP_ID}" \
    bash "${WRAPPER}" true >/dev/null 2>&1
); then
  printf '%s\n' 'Expected wrapper failure without protected Maps input.' >&2
  exit 1
fi
(
  cd "${REPO_ROOT}"
  IOS_GOOGLE_SERVICE_INFO_PLIST_B64="${encoded_fixture}" \
  IOS_FIREBASE_EXPECTED_APP_ID="${EXPECTED_APP_ID}" \
  IOS_GOOGLE_MAPS_API_KEY_FILE="${maps_key}" \
    bash "${WRAPPER}" bash -c '
      [[ -z "${IOS_GOOGLE_SERVICE_INFO_PLIST_B64:-}" ]]
      [[ -z "${IOS_FIREBASE_EXPECTED_APP_ID:-}" ]]
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

printf '%s\n' \
  'iOS Firebase/Maps validators and protected wrapper cleanup passed.'
