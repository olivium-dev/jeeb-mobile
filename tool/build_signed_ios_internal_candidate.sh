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
AUTHENTICATION_KEY_PATH="${APP_STORE_CONNECT_API_KEY_PATH:-}"
AUTHENTICATION_KEY_ID="${APP_STORE_CONNECT_API_KEY_ID:-}"
AUTHENTICATION_KEY_ISSUER_ID="${APP_STORE_CONNECT_API_ISSUER_ID:-}"
SIGNING_KEYCHAIN_PATH="${IOS_SIGNING_KEYCHAIN_PATH:-}"
SIGNING_IDENTITY_SHA1="${IOS_SIGNING_IDENTITY_SHA1:-}"
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
  fail 'protected automatic export policy is missing'
[[ -f "${AUTHENTICATION_KEY_PATH}" && ! -L "${AUTHENTICATION_KEY_PATH}" ]] ||
  fail 'App Store Connect authentication key is missing'
[[ -f "${SIGNING_KEYCHAIN_PATH}" && ! -L "${SIGNING_KEYCHAIN_PATH}" ]] ||
  fail 'protected iOS signing keychain is missing'
[[ "$(stat -f '%Lp' "${AUTHENTICATION_KEY_PATH}")" == 600 ]] ||
  fail 'App Store Connect authentication key must be owner-only'
[[ "${AUTHENTICATION_KEY_ID}" =~ ^[A-Za-z0-9]{10}$ ]] ||
  fail 'App Store Connect key ID is malformed'
[[ "${AUTHENTICATION_KEY_ISSUER_ID}" =~ \
  ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]] ||
  fail 'App Store Connect issuer ID is malformed'
[[ "${SIGNING_IDENTITY_SHA1}" =~ ^[0-9A-F]{40}$ ]] ||
  fail 'protected iOS signing identity fingerprint is malformed'
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
  "${EXPORT_OPTIONS}")" == automatic ]] ||
  fail 'export policy must use automatic signing'
[[ "$(/usr/libexec/PlistBuddy -c 'Print :destination' \
  "${EXPORT_OPTIONS}")" == export ]] ||
  fail 'export policy must remain local and must not upload'
[[ "$(/usr/libexec/PlistBuddy -c 'Print :method' \
  "${EXPORT_OPTIONS}")" == app-store-connect ]] ||
  fail 'export policy must target App Store Connect packaging'
[[ "$(/usr/libexec/PlistBuddy -c 'Print :testFlightInternalTestingOnly' \
  "${EXPORT_OPTIONS}")" == true ]] ||
  fail 'export policy must remain TestFlight-internal-only'
[[ "$(/usr/libexec/PlistBuddy -c 'Print :manageAppVersionAndBuildNumber' \
  "${EXPORT_OPTIONS}")" == false ]] ||
  fail 'export policy must not mutate the App Store build number'
[[ "$(/usr/libexec/PlistBuddy -c 'Print :uploadSymbols' \
  "${EXPORT_OPTIONS}")" == false ]] ||
  fail 'export policy must not upload symbols'
[[ "$(/usr/libexec/PlistBuddy -c 'Print :teamID' \
  "${EXPORT_OPTIONS}")" == K5RDQ8J7AN ]] ||
  fail 'export policy team drifted'
openssl pkey -in "${AUTHENTICATION_KEY_PATH}" -noout >/dev/null 2>&1 ||
  fail 'App Store Connect authentication key is invalid'

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
#
# Builds the STAGING internal-QA artifact. Owner directive 2026-08-27: the
# staging build must carry the Dev Tool — iOS has no launcher icon and no URL
# scheme, so without it a staging tester has no way into the tool at all.
#
# Two halves must BOTH agree before the Dev Tool exists, and they are supplied
# by different mechanisms on purpose:
#   * Dart  — `JEEB_DEVTOOL_ENABLED` + `JEEB_STAGING_DEVTOOL` dart-defines below.
#   * Swift — `JEEB_DEV`, which comes from the `Release-staging` CONFIGURATION,
#             not from a define. Plain `Release` does not define it.
# A store-bound build uses `-configuration Release` and passes neither define,
# so neither half is satisfied and the Dev Tool cannot reach the App Store.
run_release_build() {
  set -euo pipefail

  "${FLUTTER_BIN}" build ios --release --no-codesign --no-pub \
    --build-name="${BUILD_NAME}" \
    --build-number="${BUILD_NUMBER}" \
    --dart-define=APP_FLAVOR=staging \
    --dart-define=JEEB_DEVTOOL_ENABLED=true \
    --dart-define=JEEB_STAGING_DEVTOOL=true \
    --dart-define=JEEB_CLARITY_ENABLED=false \
    --dart-define=JEEB_CLARITY_PRIVACY_APPROVED=false \
    --dart-define="JEEB_REALTIME_SOCKET_URL=${REALTIME_SOCKET_URL}" \
    --dart-define="GATEWAY_BASE_URL=${GATEWAY_URL}"

  xcodebuild \
    -allowProvisioningUpdates \
    -authenticationKeyPath "${AUTHENTICATION_KEY_PATH}" \
    -authenticationKeyID "${AUTHENTICATION_KEY_ID}" \
    -authenticationKeyIssuerID "${AUTHENTICATION_KEY_ISSUER_ID}" \
    -workspace ios/Runner.xcworkspace \
    -scheme Runner \
    -configuration Release-staging \
    -destination generic/platform=iOS \
    -archivePath "${ARCHIVE_PATH}" \
    -hideShellScriptEnvironment \
    DEVELOPMENT_TEAM=K5RDQ8J7AN \
    CODE_SIGN_STYLE=Automatic \
    OTHER_CODE_SIGN_FLAGS="--keychain ${SIGNING_KEYCHAIN_PATH}" \
    archive

  xcodebuild \
    -allowProvisioningUpdates \
    -authenticationKeyPath "${AUTHENTICATION_KEY_PATH}" \
    -authenticationKeyID "${AUTHENTICATION_KEY_ID}" \
    -authenticationKeyIssuerID "${AUTHENTICATION_KEY_ISSUER_ID}" \
    -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportPath "${EXPORT_PATH}" \
    -exportOptionsPlist "${EXPORT_OPTIONS}" \
    -hideShellScriptEnvironment
}

export -f run_release_build
export FLUTTER_BIN BUILD_NAME BUILD_NUMBER GATEWAY_URL REALTIME_SOCKET_URL ARCHIVE_PATH
export EXPORT_PATH EXPORT_OPTIONS
export AUTHENTICATION_KEY_PATH AUTHENTICATION_KEY_ID AUTHENTICATION_KEY_ISSUER_ID
export SIGNING_KEYCHAIN_PATH SIGNING_IDENTITY_SHA1

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

# This builder produces the STAGING internal-QA artifact, which legitimately
# carries the Dev Tool. Exported so it reaches the unsigned inspector too, which
# the signed inspector invokes as a child process. Every OTHER caller —
# `tool/build_unsigned_ios_release_contract.sh`, run by the "iOS release
# contracts" CI job — leaves it unset and therefore inspects as `production`,
# which still hard-fails on any developer-surface marker.
export JEEB_IOS_RELEASE_PROFILE=staging

ipa_path="$(find "${EXPORT_PATH}" -maxdepth 1 -type f -name '*.ipa' -print -quit)"
[[ -n "${ipa_path}" && -s "${ipa_path}" ]] || fail 'exported IPA is missing'

IOS_BUILD_NAME="${BUILD_NAME}" IOS_BUILD_NUMBER="${BUILD_NUMBER}" \
  bash "${REPO_ROOT}/tool/inspect_signed_ios_release.sh" \
  "${ipa_path}" "${FIREBASE_CONFIG}" "${MAPS_KEY_FILE}" "${GATEWAY_URL}" \
  "${REALTIME_SOCKET_URL}"

printf 'Signed internal IPA: %s\n' "${ipa_path}"
printf 'IPA SHA-256: %s\n' "$(shasum -a 256 "${ipa_path}" | awk '{print $1}')"
