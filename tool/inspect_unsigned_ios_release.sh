#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-${REPO_ROOT}/build/ios/iphoneos/Runner.app}"
CONFIG_PATH="${2:-}"
MAPS_KEY_PATH="${3:-}"
EXPECTED_GATEWAY_URL="${4:-}"
EXPECTED_REALTIME_SOCKET_URL="${5:-}"
INFO_PATH="${APP_PATH}/Info.plist"
ENTITLEMENTS_PATH="${REPO_ROOT}/ios/Runner/Runner.Release.entitlements"
LAUNCH_IMAGE_DIR="${REPO_ROOT}/ios/Runner/Assets.xcassets/LaunchImage.imageset"

fail() {
  printf 'Unsigned iOS release inspection failed: %s\n' "$1" >&2
  exit 1
}

[[ -d "${APP_PATH}" ]] || fail 'compiled Runner.app is missing'
[[ -s "${INFO_PATH}" ]] || fail 'compiled Info.plist is missing'
bash "${REPO_ROOT}/tool/inspect_ios_permission_descriptions.sh" \
  "${INFO_PATH}" 'unsigned iOS app' >/dev/null
[[ -n "${CONFIG_PATH}" && -s "${CONFIG_PATH}" ]] ||
  fail 'synthetic compile config is missing'
[[ -n "${MAPS_KEY_PATH}" && -s "${MAPS_KEY_PATH}" ]] ||
  fail 'protected Maps key evidence is missing'
[[ -n "${EXPECTED_GATEWAY_URL}" ]] || fail 'expected gateway URL is missing'
[[ "${EXPECTED_REALTIME_SOCKET_URL}" == wss://*/socket/websocket ]] ||
  fail 'expected realtime socket URL is missing or malformed'

declare -a launch_images=(
  'LaunchImage.png:182:74'
  'LaunchImage@2x.png:364:148'
  'LaunchImage@3x.png:546:222'
)
for launch_image in "${launch_images[@]}"; do
  IFS=: read -r filename expected_width expected_height <<<"${launch_image}"
  image_path="${LAUNCH_IMAGE_DIR}/${filename}"
  [[ -s "${image_path}" ]] || fail "${filename} is missing"
  width="$(sips -g pixelWidth "${image_path}" 2>/dev/null | awk '/pixelWidth/ {print $2}')"
  height="$(sips -g pixelHeight "${image_path}" 2>/dev/null | awk '/pixelHeight/ {print $2}')"
  [[ "${width}" == "${expected_width}" && "${height}" == "${expected_height}" ]] ||
    fail "${filename} is still a placeholder or has the wrong scale"
done

python3 - "${INFO_PATH}" "${CONFIG_PATH}" "${MAPS_KEY_PATH}" <<'PY'
import plistlib
import sys

with open(sys.argv[1], "rb") as handle:
    built = plistlib.load(handle)
with open(sys.argv[2], "rb") as handle:
    source = plistlib.load(handle)
with open(sys.argv[3], "r", encoding="ascii") as handle:
    maps_key = handle.read().strip()

if built.get("CFBundleIdentifier") != "com.olivium.jeeb":
    raise SystemExit("Unsigned iOS release inspection failed: bundle id drifted")
if "NSAppTransportSecurity" in built or "NSLocalNetworkUsageDescription" in built:
    raise SystemExit("Unsigned iOS release inspection failed: LAN policy leaked")

schemes = {
    scheme
    for entry in built.get("CFBundleURLTypes", [])
    for scheme in entry.get("CFBundleURLSchemes", [])
}
expected_scheme = source.get("REVERSED_CLIENT_ID")
if not expected_scheme or expected_scheme not in schemes or "jeeb" not in schemes:
    raise SystemExit("Unsigned iOS release inspection failed: URL scheme mismatch")
if source.get("IS_SIGNIN_ENABLED") is not True:
    raise SystemExit("Unsigned iOS release inspection failed: sign-in disabled")
if built.get("GMSApiKey") != maps_key:
    raise SystemExit("Unsigned iOS release inspection failed: Maps key mismatch")
if not maps_key.startswith("AIza") or len(maps_key) != 39:
    raise SystemExit("Unsigned iOS release inspection failed: Maps key malformed")
PY

release_apns="$(
  /usr/libexec/PlistBuddy -c 'Print :aps-environment' "${ENTITLEMENTS_PATH}"
)"
[[ "${release_apns}" == production ]] ||
  fail 'release APNs entitlement is not production'
grep -Fq '<string>applinks:app.jeeb.fds-1.com</string>' \
  "${ENTITLEMENTS_PATH}" ||
  fail 'owner-gated associated domain was not preserved'

APP_BINARY="${APP_PATH}/Frameworks/App.framework/App"
RUNNER_BINARY="${APP_PATH}/Runner"
FIREBASE_VERIFY_ASSERTION_SOURCE="${REPO_ROOT}/build/ios/SourcePackages/checkouts/firebase-ios-sdk/FirebaseAuth/Sources/Swift/Backend/RPC/VerifyAssertionRequest.swift"
FIREBASE_VERIFY_ASSERTION_SHA256="36f46bb2b04544a15ffb339ce522c3a943e9b061567352f078663d7067b8bd83"

if [[ -f "${APP_BINARY}" ]] && LC_ALL=C grep -aEq \
    'api\.jeeb\.app|192\.168\.2\.(39|50)|10\.0\.2\.2|http://(localhost|127\.0\.0\.1)|/api/auth/token|/v1/matching/(find-jeebers|broadcast)|/api/User/(user-id-login|super-login/users)|jeeb\.seam\.super_login_|DefaultSuperLogin|SuperLoginService|SuperLoginDemoUser|devtool_shell\.dart|main_android_internal\.dart|DevToolApp|InternalDevToolApp|internal_devtool_root|Jeeb Internal QA|JEEB_INTERNAL_RELEASE=true' \
  "${APP_BINARY}"; then
  fail 'forbidden endpoint, developer auth, or wildcard token mint leaked from Jeeb-owned code'
fi
LC_ALL=C grep -aFq "${EXPECTED_GATEWAY_URL}" "${APP_BINARY}" ||
  fail 'expected gateway URL is absent from Jeeb-owned application code'
LC_ALL=C grep -aFq "${EXPECTED_REALTIME_SOCKET_URL}" "${APP_BINARY}" ||
  fail 'expected realtime socket URL is absent from Jeeb-owned application code'

if [[ -f "${RUNNER_BINARY}" ]]; then
  if LC_ALL=C grep -aEq \
    'api\.jeeb\.app|192\.168\.2\.(39|50)|10\.0\.2\.2|http://127\.0\.0\.1|/api/auth/token|/v1/matching/(find-jeebers|broadcast)|/api/User/(user-id-login|super-login/users)|jeeb\.seam\.super_login_' \
    "${RUNNER_BINARY}"; then
    fail 'forbidden endpoint, developer auth, or wildcard token mint leaked into native code'
  fi

  runner_localhost_count="$({
    LC_ALL=C grep -aoF 'http://localhost' "${RUNNER_BINARY}" || true
  } | wc -l | tr -d '[:space:]')"
  if [[ "${runner_localhost_count}" != 0 ]]; then
    [[ "${runner_localhost_count}" == 1 ]] ||
      fail 'unexpected localhost literal count in the native application'
    [[ -s "${FIREBASE_VERIFY_ASSERTION_SOURCE}" ]] ||
      fail 'FirebaseAuth localhost provenance source is missing'
    source_localhost_count="$({
      LC_ALL=C grep -oF 'http://localhost' \
        "${FIREBASE_VERIFY_ASSERTION_SOURCE}" || true
    } | wc -l | tr -d '[:space:]')"
    [[ "${source_localhost_count}" == 1 ]] ||
      fail 'FirebaseAuth localhost provenance changed'
    source_sha256="$(
      shasum -a 256 "${FIREBASE_VERIFY_ASSERTION_SOURCE}" | awk '{print $1}'
    )"
    [[ "${source_sha256}" == "${FIREBASE_VERIFY_ASSERTION_SHA256}" ]] ||
      fail 'FirebaseAuth localhost provenance hash changed'
  fi
fi

if [[ -d "${APP_PATH}/Frameworks" ]]; then
  duplicate_frameworks="$(
    find "${APP_PATH}/Frameworks" -maxdepth 1 -type d -name '*.framework' \
      -exec basename {} .framework \; | sort | uniq -d
  )"
  [[ -z "${duplicate_frameworks}" ]] ||
    fail 'duplicate embedded framework basename detected'
fi

if [[ -x "${APP_PATH}/Runner" ]]; then
  duplicate_loads="$(
    otool -L "${APP_PATH}/Runner" | tail -n +2 | awk '{print $1}' |
      awk -F/ '{print $NF}' | sort | uniq -d
  )"
  [[ -z "${duplicate_loads}" ]] ||
    fail 'duplicate Mach-O framework load detected'
fi

bash "${REPO_ROOT}/tool/check_ios_dependency_ownership.sh"
printf '%s\n' 'Unsigned iOS release artifact contracts passed.'
