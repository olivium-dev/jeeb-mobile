#!/usr/bin/env bash

set -euo pipefail

AAB_PATH="${1:-}"
PROVENANCE_PATH="${2:-}"
METADATA_PATH="${3:-}"
PACKAGE_NAME="${ANDROID_PACKAGE_NAME:-}"
BUILD_NAME="${MOBILE_BUILD_NAME:-}"
BUILD_NUMBER="${MOBILE_BUILD_NUMBER:-}"
REVIEWED_SHA="${REVIEWED_SHA:-}"
SOURCE_RUN_ID="${SOURCE_RUN_ID:-}"
SOURCE_RUN_ATTEMPT="${SOURCE_RUN_ATTEMPT:-}"
SOURCE_WORKFLOW_REF="${SOURCE_WORKFLOW_REF:-}"
VALIDATION_TMP="$(mktemp -d)"
trap 'rm -rf -- "${VALIDATION_TMP}"' EXIT HUP INT TERM

fail() {
  printf 'Android internal Dev Tool artifact rejected: %s\n' "$1" >&2
  exit 1
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d ' ' -f1
  else
    shasum -a 256 "$1" | cut -d ' ' -f1
  fi
}

validate_identity_inputs() {
  [[ "${PACKAGE_NAME}" == com.olivium.jeeb ]] || fail 'package is not canonical'
  [[ "${BUILD_NAME}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
    fail 'version name is malformed'
  [[ "${BUILD_NUMBER}" =~ ^[1-9][0-9]{0,9}$ ]] ||
    fail 'version code is malformed'
  (( 10#${BUILD_NUMBER} >= 26082601 )) || fail 'version code is below floor'
  (( 10#${BUILD_NUMBER} <= 2100000000 )) || fail 'version code exceeds ceiling'
  [[ "${REVIEWED_SHA}" =~ ^[0-9a-f]{40}$ ]] || fail 'reviewed SHA is malformed'
  [[ "${SOURCE_RUN_ID}" =~ ^[1-9][0-9]*$ ]] || fail 'source run ID is malformed'
  [[ "${SOURCE_RUN_ATTEMPT}" =~ ^[1-9][0-9]*$ ]] ||
    fail 'source run attempt is malformed'
  local expected_workflow='olivium-dev/jeeb-mobile/.github/workflows/trusted-android-internal-devtool-rc.yml@refs/heads/main'
  [[ "${SOURCE_WORKFLOW_REF}" == "${expected_workflow}" ]] ||
    fail 'source workflow ref is not protected main'
}

validate_release_inputs() {
  [[ "${JEEB_DEVTOOL_BUILD:-}" == true ]] || fail 'devtool gate is not true'
  [[ "${JEEB_SUPER_LOGIN_ENABLED:-}" == false ]] ||
    fail 'Super Login gate is not false'
  [[ "${JEEB_CLARITY_ENABLED:-}" == false ]] || fail 'Clarity gate is not false'
  [[ "${JEEB_CLARITY_PRIVACY_APPROVED:-}" == false ]] ||
    fail 'Clarity privacy gate is not false'
  [[ "${JEEB_RELEASE_PROFILE:-}" == release ]] ||
    fail 'release profile gate is not release'
}

validate_archive() {
  unzip -tqq "${AAB_PATH}" || fail 'AAB is not a valid archive'
  if unzip -Z1 "${AAB_PATH}" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
    fail 'AAB contains an unsafe archive path'
  fi
  local manifest="${VALIDATION_TMP}/AndroidManifest.pb"
  unzip -p "${AAB_PATH}" base/manifest/AndroidManifest.xml >"${manifest}" ||
    fail 'AAB manifest is missing'
  for launcher_marker in \
    'com.olivium.jeeb.MainActivity' \
    'com.olivium.jeeb.DevToolLauncher' \
    'android.intent.action.MAIN' \
    'android.intent.category.LAUNCHER'; do
    LC_ALL=C grep -aFq "${launcher_marker}" "${manifest}" ||
      fail "required launcher marker is missing: ${launcher_marker}"
  done
}

validate_metadata() {
  jq -e \
    --arg package "${PACKAGE_NAME}" \
    --arg name "${BUILD_NAME}" \
    --argjson number "${BUILD_NUMBER}" '
      .version == 3
      and .artifactType.type == "MERGED_MANIFESTS"
      and .artifactType.kind == "Directory"
      and .applicationId == $package
      and .variantName == "internalReleaseRelease"
      and .elementType == "File"
      and (.elements | length) == 1
      and .elements[0].versionName == $name
      and .elements[0].versionCode == $number
    ' "${METADATA_PATH}" >/dev/null ||
    fail 'Gradle metadata package, variant, or version is invalid'
}

validate_provenance() {
  local aab_sha="$1"
  local metadata_sha="$2"
  local signer_sha1="$3"
  local signer_sha256="$4"
  jq -e \
    --arg aab "${aab_sha}" \
    --arg metadata "${metadata_sha}" \
    --arg package "${PACKAGE_NAME}" \
    --arg name "${BUILD_NAME}" \
    --arg number "${BUILD_NUMBER}" \
    --arg reviewed "${REVIEWED_SHA}" \
    --arg source_run "${SOURCE_RUN_ID}" \
    --arg source_attempt "${SOURCE_RUN_ATTEMPT}" \
    --arg workflow_ref "${SOURCE_WORKFLOW_REF}" \
    --arg signer_sha1 "${signer_sha1}" \
    --arg signer_sha256 "${signer_sha256}" '
      .platform == "android"
      and .package_name == $package
      and .native_id == $package
      and .flavor == "internalRelease"
      and .build_profile == "release"
      and .release_profile == true
      and .runtime == "staging"
      and .version_name == $name
      and .version_code == $number
      and .build_name == $name
      and .build_number == $number
      and .artifact_sha256 == $aab
      and .metadata_sha256 == $metadata
      and .metadata_kind == "gradle-merged-manifest-v3"
      and .signer_sha1 == $signer_sha1
      and .signer_sha256 == $signer_sha256
      and .reviewed_sha == $reviewed
      and .source_run_id == $source_run
      and .source_run_attempt == $source_attempt
      and .source_head_sha == $reviewed
      and .source_workflow_path ==
        ".github/workflows/trusted-android-internal-devtool-rc.yml"
      and .source_workflow_ref == $workflow_ref
      and .source_repository == "olivium-dev/jeeb-mobile"
      and .source_event == "workflow_dispatch"
      and .source_ref == "refs/heads/main"
      and .gateway_origin == "https://app.jeeb.fds-1.com"
      and .realtime_socket == "wss://app.jeeb.fds-1.com/socket/websocket"
      and .devtool == true
      and .super_login == false
      and .clarity_enabled == false
      and .clarity_privacy_approved == false
      and .retained == true
      and .store_uploaded == false
    ' "${PROVENANCE_PATH}" >/dev/null ||
    fail 'provenance artifact, source, version, or policy binding failed'
}

[[ -s "${AAB_PATH}" ]] || fail 'AAB is missing'
[[ -s "${PROVENANCE_PATH}" ]] || fail 'provenance is missing'
[[ -s "${METADATA_PATH}" ]] || fail 'Gradle metadata is missing'
validate_identity_inputs
validate_release_inputs
validate_archive
validate_metadata
aab_sha256="$(sha256_file "${AAB_PATH}")"
metadata_sha256="$(sha256_file "${METADATA_PATH}")"
signer_result="$(
  bash "$(dirname "${BASH_SOURCE[0]}")/android_internal_candidate_integrity.sh" \
    extract-signer "${AAB_PATH}"
)"
signer_sha1="$(sed -n 's/^signer_sha1=//p' <<<"${signer_result}")"
signer_sha256="$(sed -n 's/^signer_sha256=//p' <<<"${signer_result}")"
[[ "${signer_sha1}" =~ ^[0-9A-F]{40}$ ]] ||
  fail 'AAB SHA-1 signer fingerprint is malformed'
[[ "${signer_sha256}" =~ ^[0-9A-F]{64}$ ]] ||
  fail 'AAB SHA-256 signer fingerprint is malformed'
validate_provenance \
  "${aab_sha256}" "${metadata_sha256}" \
  "${signer_sha1}" "${signer_sha256}"
printf 'artifact_sha256=%s\n' "${aab_sha256}"
printf 'metadata_sha256=%s\n' "${metadata_sha256}"
printf 'signer_sha1=%s\n' "${signer_sha1}"
printf 'signer_sha256=%s\n' "${signer_sha256}"
