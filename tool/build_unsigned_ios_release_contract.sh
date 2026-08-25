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
TEMPLATE="${REPO_ROOT}/ios/Runner/GoogleService-Info.plist.template"
WRAPPER="${REPO_ROOT}/tool/run_with_ios_firebase_config.sh"
TMP_DIR="$(mktemp -d)"
SYNTHETIC_CONFIG="${TMP_DIR}/GoogleService-Info.plist"
SYNTHETIC_SENDER_ID="123456789012"
SYNTHETIC_APP_ID="1:${SYNTHETIC_SENDER_ID}:ios:0123456789abcdef0123456789abcdef"
SYNTHETIC_CLIENT_ID="${SYNTHETIC_SENDER_ID}-syntheticfixture.apps.googleusercontent.com"
SYNTHETIC_REVERSED_ID="com.googleusercontent.apps.${SYNTHETIC_SENDER_ID}-syntheticfixture"
SYNTHETIC_API_KEY="AIza$(printf 'A%.0s' {1..35})"
SYNTHETIC_MAPS_KEY="AIza$(printf 'M%.0s' {1..35})"
SYNTHETIC_MAPS_KEY_FILE="${TMP_DIR}/maps-api-key"
SYNTHETIC_BUILD_NAME=0.0.0
SYNTHETIC_BUILD_NUMBER=1

flutter_version="$("${FLUTTER_BIN}" --version --machine | python3 -c \
  'import json,sys; print(json.load(sys.stdin)["frameworkVersion"])')"
if [[ "${flutter_version}" != "${REQUIRED_FLUTTER_VERSION}" ]]; then
  printf 'Unsigned iOS compile requires Flutter %s.\n' \
    "${REQUIRED_FLUTTER_VERSION}" >&2
  exit 1
fi
export FLUTTER_SWIFT_PACKAGE_MANAGER=true

cleanup() {
  rm -rf -- "${TMP_DIR}"
}
trap cleanup EXIT HUP INT TERM

cp "${TEMPLATE}" "${SYNTHETIC_CONFIG}"
/usr/libexec/PlistBuddy -c "Set :API_KEY ${SYNTHETIC_API_KEY}" \
  "${SYNTHETIC_CONFIG}"
/usr/libexec/PlistBuddy -c "Set :GCM_SENDER_ID ${SYNTHETIC_SENDER_ID}" \
  "${SYNTHETIC_CONFIG}"
/usr/libexec/PlistBuddy -c 'Set :PROJECT_ID jeeb-5a293' "${SYNTHETIC_CONFIG}"
/usr/libexec/PlistBuddy -c 'Set :STORAGE_BUCKET jeeb-5a293.appspot.com' \
  "${SYNTHETIC_CONFIG}"
/usr/libexec/PlistBuddy -c "Set :GOOGLE_APP_ID ${SYNTHETIC_APP_ID}" \
  "${SYNTHETIC_CONFIG}"
/usr/libexec/PlistBuddy -c "Set :CLIENT_ID ${SYNTHETIC_CLIENT_ID}" \
  "${SYNTHETIC_CONFIG}"
/usr/libexec/PlistBuddy -c "Set :REVERSED_CLIENT_ID ${SYNTHETIC_REVERSED_ID}" \
  "${SYNTHETIC_CONFIG}"
chmod 0600 "${SYNTHETIC_CONFIG}"
printf '%s\n' "${SYNTHETIC_MAPS_KEY}" >"${SYNTHETIC_MAPS_KEY_FILE}"
chmod 0600 "${SYNTHETIC_MAPS_KEY_FILE}"

encoded_config="$(base64 <"${SYNTHETIC_CONFIG}" | tr -d '\n')"
(
  cd "${REPO_ROOT}"
  IOS_GOOGLE_SERVICE_INFO_PLIST_B64="${encoded_config}" \
  IOS_FIREBASE_EXPECTED_APP_ID="${SYNTHETIC_APP_ID}" \
  IOS_FIREBASE_EXPECTED_CLIENT_ID="${SYNTHETIC_CLIENT_ID}" \
  IOS_FIREBASE_EXPECTED_REVERSED_CLIENT_ID="${SYNTHETIC_REVERSED_ID}" \
  IOS_GOOGLE_MAPS_API_KEY_FILE="${SYNTHETIC_MAPS_KEY_FILE}" \
    bash "${WRAPPER}" "${FLUTTER_BIN}" build ios --release --no-codesign \
      --no-pub \
      --build-name="${SYNTHETIC_BUILD_NAME}" \
      --build-number="${SYNTHETIC_BUILD_NUMBER}" \
      --dart-define=APP_FLAVOR=production \
      --dart-define=JEEB_CLARITY_ENABLED=false \
      --dart-define=JEEB_CLARITY_PRIVACY_APPROVED=false \
      --dart-define=GATEWAY_BASE_URL=https://gateway.contract.invalid
)
unset encoded_config

[[ ! -e "${REPO_ROOT}/ios/Runner/GoogleService-Info.plist" ]] || {
  printf '%s\n' 'Unsigned iOS compile left the injected plist on disk.' >&2
  exit 1
}
[[ ! -e "${REPO_ROOT}/ios/Flutter/ProtectedFirebase.xcconfig" ]] || {
  printf '%s\n' 'Unsigned iOS compile left protected build settings on disk.' >&2
  exit 1
}

bash "${REPO_ROOT}/tool/inspect_unsigned_ios_release.sh" \
  "${REPO_ROOT}/build/ios/iphoneos/Runner.app" "${SYNTHETIC_CONFIG}" \
  "${SYNTHETIC_MAPS_KEY_FILE}" 'https://gateway.contract.invalid'
printf '%s\n' \
  'Unsigned iOS release compiled with synthetic config; no provider evidence claimed.'
