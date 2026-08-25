#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
REQUIRED_FLUTTER_VERSION="$(python3 - "${REPO_ROOT}/.fvmrc" <<'PY'
import json
import re
import sys

with open(sys.argv[1], encoding='utf-8') as handle:
    version = json.load(handle).get('flutter', '')
if not isinstance(version, str) or not re.fullmatch(r'\d+\.\d+\.\d+', version):
    raise SystemExit('.fvmrc Flutter version is missing or malformed')
print(version)
PY
)"
BUILD_NAME="${IOS_BUILD_NAME:-}"
BUILD_NUMBER="${IOS_BUILD_NUMBER:-}"
GATEWAY_URL="${GATEWAY_BASE_URL:-https://app.jeeb.fds-1.com}"
REALTIME_SOCKET_URL="${JEEB_REALTIME_SOCKET_URL:-}"
FIREBASE_CONFIG="${IOS_GOOGLE_SERVICE_INFO_PLIST_PATH:-}"
MAPS_KEY_FILE="${IOS_GOOGLE_MAPS_API_KEY_FILE:-}"
EXPECTED_FIREBASE_APP_ID="${IOS_FIREBASE_EXPECTED_APP_ID:-}"
EXPECTED_FIREBASE_CLIENT_ID="${IOS_FIREBASE_EXPECTED_CLIENT_ID:-}"
EXPECTED_FIREBASE_REVERSED_CLIENT_ID="${IOS_FIREBASE_EXPECTED_REVERSED_CLIENT_ID:-}"
ARCHIVE_PATH="${REPO_ROOT}/build/ios/archive/Jeeb-${BUILD_NUMBER}.xcarchive"
EXPORT_PATH="${REPO_ROOT}/build/ios/internal-${BUILD_NUMBER}"
EXPORT_OPTIONS="${IOS_EXPORT_OPTIONS_PATH:-}"
PROVISIONING_PROFILE_SPECIFIER="${IOS_PROVISIONING_PROFILE_SPECIFIER:-}"
SIGNING_CERTIFICATE="${IOS_SIGNING_CERTIFICATE:-Apple Distribution}"
WRAPPER="${REPO_ROOT}/tool/run_with_ios_firebase_config.sh"

fail() {
  printf 'Signed iOS internal candidate failed: %s\n' "$1" >&2
  exit 1
}

[[ "${GATEWAY_URL}" == https://app.jeeb.fds-1.com ]] ||
  fail 'the internal candidate must point at the canonical staging edge'
[[ "${REALTIME_SOCKET_URL}" == wss://app.jeeb.fds-1.com/socket/websocket ]] ||
  fail 'the internal candidate must use the canonical staging realtime socket'
[[ -f "${FIREBASE_CONFIG}" && ! -L "${FIREBASE_CONFIG}" ]] ||
  fail 'protected Firebase plist is missing'
[[ -f "${MAPS_KEY_FILE}" && ! -L "${MAPS_KEY_FILE}" ]] ||
  fail 'protected Maps key file is missing'
[[ -f "${EXPORT_OPTIONS}" && ! -L "${EXPORT_OPTIONS}" ]] ||
  fail 'protected manual export policy is missing'
[[ -n "${PROVISIONING_PROFILE_SPECIFIER}" ]] ||
  fail 'manual provisioning profile specifier is missing'
[[ -n "${SIGNING_CERTIFICATE}" ]] ||
  fail 'manual signing certificate selector is missing'
[[ -n "${EXPECTED_FIREBASE_CLIENT_ID}" ]] ||
  fail 'protected approved Google Sign-In client identity is missing'
[[ -n "${EXPECTED_FIREBASE_REVERSED_CLIENT_ID}" ]] ||
  fail 'protected approved reversed Google Sign-In client identity is missing'
[[ "${BUILD_NAME}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
  fail 'IOS_BUILD_NAME must be explicit and valid'
[[ "${BUILD_NUMBER}" =~ ^[1-9][0-9]{0,17}$ ]] ||
  fail 'IOS_BUILD_NUMBER must be explicit and valid'
[[ ! -e "${ARCHIVE_PATH}" ]] || fail 'refusing to overwrite an archive'
[[ ! -e "${EXPORT_PATH}" ]] || fail 'refusing to overwrite an IPA export'

[[ "$(/usr/libexec/PlistBuddy -c 'Print :signingStyle' \
  "${EXPORT_OPTIONS}")" == manual ]] ||
  fail 'export policy must use manual signing'
[[ "$(/usr/libexec/PlistBuddy -c 'Print :destination' \
  "${EXPORT_OPTIONS}")" == export ]] ||
  fail 'export policy must remain local and must not upload'
[[ "$(/usr/libexec/PlistBuddy -c 'Print :manageAppVersionAndBuildNumber' \
  "${EXPORT_OPTIONS}")" == false ]] ||
  fail 'export policy must not mutate the App Store build number'
[[ "$(/usr/libexec/PlistBuddy -c 'Print :uploadSymbols' \
  "${EXPORT_OPTIONS}")" == false ]] ||
  fail 'export policy must not upload symbols'
[[ "$(/usr/libexec/PlistBuddy -c 'Print :teamID' \
  "${EXPORT_OPTIONS}")" == K5RDQ8J7AN ]] ||
  fail 'export policy team drifted'
[[ "$(/usr/libexec/PlistBuddy -c \
  'Print :provisioningProfiles:com.olivium.jeeb' \
  "${EXPORT_OPTIONS}")" == "${PROVISIONING_PROFILE_SPECIFIER}" ]] ||
  fail 'export policy provisioning profile drifted'

flutter_version="$("${FLUTTER_BIN}" --version --machine | python3 -c \
  'import json,sys; print(json.load(sys.stdin)["frameworkVersion"])')"
[[ "${flutter_version}" == "${REQUIRED_FLUTTER_VERSION}" ]] ||
  fail "Flutter ${REQUIRED_FLUTTER_VERSION} is required"

IOS_FIREBASE_EXPECTED_APP_ID="${EXPECTED_FIREBASE_APP_ID}" \
IOS_FIREBASE_EXPECTED_CLIENT_ID="${EXPECTED_FIREBASE_CLIENT_ID}" \
IOS_FIREBASE_EXPECTED_REVERSED_CLIENT_ID="${EXPECTED_FIREBASE_REVERSED_CLIENT_ID}" \
  bash "${REPO_ROOT}/tool/validate_ios_google_service_info.sh" \
    "${FIREBASE_CONFIG}" >/dev/null
bash "${REPO_ROOT}/tool/validate_ios_maps_api_key.sh" \
  "${MAPS_KEY_FILE}" >/dev/null

export FLUTTER_SWIFT_PACKAGE_MANAGER=true
encoded_firebase="$(base64 <"${FIREBASE_CONFIG}" | tr -d '\n')"

# Invoked through the protected wrapper in an exported child-shell function.
# shellcheck disable=SC2329
run_release_build() {
  set -euo pipefail

  "${FLUTTER_BIN}" build ios --release --no-codesign --no-pub \
    --build-name="${BUILD_NAME}" \
    --build-number="${BUILD_NUMBER}" \
    --dart-define=APP_FLAVOR=staging \
    --dart-define=JEEB_CLARITY_ENABLED=false \
    --dart-define=JEEB_CLARITY_PRIVACY_APPROVED=false \
    --dart-define="JEEB_REALTIME_SOCKET_URL=${REALTIME_SOCKET_URL}" \
    --dart-define="GATEWAY_BASE_URL=${GATEWAY_URL}"

  xcodebuild \
    -workspace ios/Runner.xcworkspace \
    -scheme Runner \
    -configuration Release \
    -destination generic/platform=iOS \
    -archivePath "${ARCHIVE_PATH}" \
    -hideShellScriptEnvironment \
    DEVELOPMENT_TEAM=K5RDQ8J7AN \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="${SIGNING_CERTIFICATE}" \
    PROVISIONING_PROFILE_SPECIFIER="${PROVISIONING_PROFILE_SPECIFIER}" \
    archive

  xcodebuild \
    -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportPath "${EXPORT_PATH}" \
    -exportOptionsPlist "${EXPORT_OPTIONS}" \
    -hideShellScriptEnvironment
}

export -f run_release_build
export FLUTTER_BIN BUILD_NAME BUILD_NUMBER GATEWAY_URL REALTIME_SOCKET_URL ARCHIVE_PATH
export EXPORT_PATH EXPORT_OPTIONS
export PROVISIONING_PROFILE_SPECIFIER SIGNING_CERTIFICATE

(
  cd "${REPO_ROOT}"
  IOS_GOOGLE_SERVICE_INFO_PLIST_B64="${encoded_firebase}" \
  IOS_FIREBASE_EXPECTED_APP_ID="${EXPECTED_FIREBASE_APP_ID}" \
  IOS_FIREBASE_EXPECTED_CLIENT_ID="${EXPECTED_FIREBASE_CLIENT_ID}" \
  IOS_FIREBASE_EXPECTED_REVERSED_CLIENT_ID="${EXPECTED_FIREBASE_REVERSED_CLIENT_ID}" \
  IOS_GOOGLE_MAPS_API_KEY_FILE="${MAPS_KEY_FILE}" \
    bash "${WRAPPER}" bash -c run_release_build
)
unset encoded_firebase
unset -f run_release_build

ipa_path="$(find "${EXPORT_PATH}" -maxdepth 1 -type f -name '*.ipa' -print -quit)"
[[ -n "${ipa_path}" && -s "${ipa_path}" ]] || fail 'exported IPA is missing'

IOS_BUILD_NAME="${BUILD_NAME}" IOS_BUILD_NUMBER="${BUILD_NUMBER}" \
  bash "${REPO_ROOT}/tool/inspect_signed_ios_release.sh" \
  "${ipa_path}" "${FIREBASE_CONFIG}" "${MAPS_KEY_FILE}" "${GATEWAY_URL}" \
  "${REALTIME_SOCKET_URL}"

printf 'Signed internal IPA: %s\n' "${ipa_path}"
printf 'IPA SHA-256: %s\n' "$(shasum -a 256 "${ipa_path}" | awk '{print $1}')"
