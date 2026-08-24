#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
REQUIRED_FLUTTER_VERSION="3.44.2"
BUILD_NAME="${IOS_BUILD_NAME:-1.0.0}"
BUILD_NUMBER="${IOS_BUILD_NUMBER:-26082401}"
GATEWAY_URL="${GATEWAY_BASE_URL:-https://app.jeeb.fds-1.com}"
FIREBASE_CONFIG="${IOS_GOOGLE_SERVICE_INFO_PLIST_PATH:-}"
MAPS_KEY_FILE="${IOS_GOOGLE_MAPS_API_KEY_FILE:-}"
EXPECTED_FIREBASE_APP_ID="${IOS_FIREBASE_EXPECTED_APP_ID:-}"
ARCHIVE_PATH="${REPO_ROOT}/build/ios/archive/Jeeb-${BUILD_NUMBER}.xcarchive"
EXPORT_PATH="${REPO_ROOT}/build/ios/internal-${BUILD_NUMBER}"
EXPORT_OPTIONS="${REPO_ROOT}/ios/ExportOptions.Internal.plist"
WRAPPER="${REPO_ROOT}/tool/run_with_ios_firebase_config.sh"
ASC_KEY_PATH="${APP_STORE_CONNECT_KEY_PATH:-}"
ASC_KEY_ID="${APP_STORE_CONNECT_KEY_ID:-}"
ASC_ISSUER_ID="${APP_STORE_CONNECT_ISSUER_ID:-}"

fail() {
  printf 'Signed iOS internal candidate failed: %s\n' "$1" >&2
  exit 1
}

[[ "${GATEWAY_URL}" == https://app.jeeb.fds-1.com ]] ||
  fail 'the internal candidate must point at the canonical staging edge'
[[ -f "${FIREBASE_CONFIG}" && ! -L "${FIREBASE_CONFIG}" ]] ||
  fail 'protected Firebase plist is missing'
[[ -f "${MAPS_KEY_FILE}" && ! -L "${MAPS_KEY_FILE}" ]] ||
  fail 'protected Maps key file is missing'
[[ -s "${EXPORT_OPTIONS}" ]] || fail 'internal export policy is missing'
[[ ! -e "${ARCHIVE_PATH}" ]] || fail 'refusing to overwrite an archive'
[[ ! -e "${EXPORT_PATH}" ]] || fail 'refusing to overwrite an IPA export'

if [[ -n "${ASC_KEY_PATH}${ASC_KEY_ID}${ASC_ISSUER_ID}" ]]; then
  [[ -f "${ASC_KEY_PATH}" && ! -L "${ASC_KEY_PATH}" ]] ||
    fail 'protected App Store Connect API key is missing'
  [[ -n "${ASC_KEY_ID}" && -n "${ASC_ISSUER_ID}" ]] ||
    fail 'App Store Connect Key ID and Issuer ID are both required'
  if [[ "$(uname -s)" == Darwin ]]; then
    [[ "$(stat -f '%Lp' "${ASC_KEY_PATH}")" == 600 ]] ||
      fail 'protected App Store Connect API key must have mode 0600'
  fi
fi

flutter_version="$("${FLUTTER_BIN}" --version --machine | python3 -c \
  'import json,sys; print(json.load(sys.stdin)["frameworkVersion"])')"
[[ "${flutter_version}" == "${REQUIRED_FLUTTER_VERSION}" ]] ||
  fail "Flutter ${REQUIRED_FLUTTER_VERSION} is required"

IOS_FIREBASE_EXPECTED_APP_ID="${EXPECTED_FIREBASE_APP_ID}" \
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

  provisioning_auth_args=()
  if [[ -n "${ASC_KEY_PATH}" ]]; then
    provisioning_auth_args=(
      -authenticationKeyPath "${ASC_KEY_PATH}"
      -authenticationKeyID "${ASC_KEY_ID}"
      -authenticationKeyIssuerID "${ASC_ISSUER_ID}"
    )
  fi

  "${FLUTTER_BIN}" build ios --release --no-codesign --no-pub \
    --build-name="${BUILD_NAME}" \
    --build-number="${BUILD_NUMBER}" \
    --dart-define=APP_FLAVOR=staging \
    --dart-define="GATEWAY_BASE_URL=${GATEWAY_URL}"

  xcodebuild \
    -workspace ios/Runner.xcworkspace \
    -scheme Runner \
    -configuration Release \
    -destination generic/platform=iOS \
    -archivePath "${ARCHIVE_PATH}" \
    -allowProvisioningUpdates \
    "${provisioning_auth_args[@]}" \
    -hideShellScriptEnvironment \
    DEVELOPMENT_TEAM=K5RDQ8J7AN \
    CODE_SIGN_STYLE=Automatic \
    archive

  xcodebuild \
    -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportPath "${EXPORT_PATH}" \
    -exportOptionsPlist "${EXPORT_OPTIONS}" \
    -allowProvisioningUpdates \
    "${provisioning_auth_args[@]}" \
    -hideShellScriptEnvironment
}

export -f run_release_build
export FLUTTER_BIN BUILD_NAME BUILD_NUMBER GATEWAY_URL ARCHIVE_PATH
export EXPORT_PATH EXPORT_OPTIONS
export ASC_KEY_PATH ASC_KEY_ID ASC_ISSUER_ID

(
  cd "${REPO_ROOT}"
  IOS_GOOGLE_SERVICE_INFO_PLIST_B64="${encoded_firebase}" \
  IOS_FIREBASE_EXPECTED_APP_ID="${EXPECTED_FIREBASE_APP_ID}" \
  IOS_GOOGLE_MAPS_API_KEY_FILE="${MAPS_KEY_FILE}" \
    bash "${WRAPPER}" bash -c run_release_build
)
unset encoded_firebase
unset -f run_release_build

ipa_path="$(find "${EXPORT_PATH}" -maxdepth 1 -type f -name '*.ipa' -print -quit)"
[[ -n "${ipa_path}" && -s "${ipa_path}" ]] || fail 'exported IPA is missing'

bash "${REPO_ROOT}/tool/inspect_signed_ios_release.sh" \
  "${ipa_path}" "${FIREBASE_CONFIG}" "${MAPS_KEY_FILE}" "${GATEWAY_URL}"

printf 'Signed internal IPA: %s\n' "${ipa_path}"
printf 'IPA SHA-256: %s\n' "$(shasum -a 256 "${ipa_path}" | awk '{print $1}')"
