#!/usr/bin/env bash

set -euo pipefail

IPA_PATH="${1:-}"
PROVENANCE_PATH="${2:-}"
DSYM_PATH="${3:-}"
REVIEWED_SHA="${REVIEWED_SHA:-}"
BUILD_NAME="${BUILD_NAME:-}"
BUILD_NUMBER="${BUILD_NUMBER:-}"
SOURCE_RUN_ID="${SOURCE_RUN_ID:-}"
SOURCE_RUN_ATTEMPT="${SOURCE_RUN_ATTEMPT:-}"
OMDS_SHA="${OMDS_SHA:-}"
EXPECTED_IPA_SHA256="${EXPECTED_IPA_SHA256:-}"
EXPECTED_PROVENANCE_SHA256="${EXPECTED_PROVENANCE_SHA256:-}"
EXPECTED_DSYM_SHA256="${EXPECTED_DSYM_SHA256:-}"

fail() {
  printf 'iOS retained RC rejected: %s\n' "$1" >&2
  exit 1
}

sha256_file() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${file}" | cut -d ' ' -f1
  else
    shasum -a 256 "${file}" | cut -d ' ' -f1
  fi
}

validate_zip() {
  local archive="$1"
  unzip -tqq "${archive}" || fail "archive is invalid: ${archive}"
  if unzip -Z1 "${archive}" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
    fail "archive contains an unsafe path: ${archive}"
  fi
}

validate_expected_hash() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  [[ -z "${expected}" || "${expected}" =~ ^[0-9a-f]{64}$ ]] ||
    fail "expected ${label} hash is malformed"
  [[ -z "${expected}" || "${actual}" == "${expected}" ]] ||
    fail "${label} hash does not match source policy"
}

[[ -s "${IPA_PATH}" ]] || fail 'IPA is missing'
[[ -s "${PROVENANCE_PATH}" ]] || fail 'provenance is missing'
[[ -s "${DSYM_PATH}" ]] || fail 'dSYM archive is missing'
[[ "${REVIEWED_SHA}" =~ ^[0-9a-f]{40}$ ]] || fail 'reviewed SHA is malformed'
[[ "${BUILD_NAME}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
  fail 'marketing version must contain exactly three numeric components'
[[ "${BUILD_NUMBER}" =~ ^[1-9][0-9]{0,9}$ ]] || fail 'build number is malformed'
(( 10#${BUILD_NUMBER} <= 2100000000 )) || fail 'build number exceeds store ceiling'
[[ "${SOURCE_RUN_ID}" =~ ^[1-9][0-9]*$ ]] || fail 'source run ID is malformed'
[[ "${SOURCE_RUN_ATTEMPT}" =~ ^[1-9][0-9]*$ ]] ||
  fail 'source run attempt is malformed'
[[ "${OMDS_SHA}" =~ ^[0-9a-f]{40}$ ]] || fail 'OMDS SHA is malformed'

validate_zip "${IPA_PATH}"
validate_zip "${DSYM_PATH}"
ipa_sha256="$(sha256_file "${IPA_PATH}")"
provenance_sha256="$(sha256_file "${PROVENANCE_PATH}")"
dsym_sha256="$(sha256_file "${DSYM_PATH}")"
validate_expected_hash IPA "${EXPECTED_IPA_SHA256}" "${ipa_sha256}"
validate_expected_hash provenance \
  "${EXPECTED_PROVENANCE_SHA256}" "${provenance_sha256}"
validate_expected_hash dSYM "${EXPECTED_DSYM_SHA256}" "${dsym_sha256}"

jq -e \
  --arg ipa "${ipa_sha256}" \
  --arg dsym "${dsym_sha256}" \
  --arg reviewed "${REVIEWED_SHA}" \
  --arg name "${BUILD_NAME}" \
  --arg number "${BUILD_NUMBER}" \
  --arg source_run "${SOURCE_RUN_ID}" \
  --arg source_attempt "${SOURCE_RUN_ATTEMPT}" \
  --arg omds "${OMDS_SHA}" '
    .platform == "ios"
    and .native_id == "com.olivium.jeeb"
    and .runtime == "staging"
    and .artifact_sha256 == $ipa
    and .dsym_sha256 == $dsym
    and .reviewed_sha == $reviewed
    and .build_name == $name
    and .build_number == $number
    and .dependency_sha == $omds
    and .source_run_id == $source_run
    and .source_run_attempt == $source_attempt
    and .source_head_sha == $reviewed
    and .source_workflow_path == ".github/workflows/trusted-mobile-rc.yml"
    and .source_workflow_ref ==
      "olivium-dev/jeeb-mobile/.github/workflows/trusted-mobile-rc.yml@refs/heads/main"
    and .clarity_enabled == false
    and .retained == true
    and .store_uploaded == false
  ' "${PROVENANCE_PATH}" >/dev/null ||
  fail 'provenance identity, source, version, or artifact binding failed'

printf 'ipa_sha256=%s\n' "${ipa_sha256}"
printf 'provenance_sha256=%s\n' "${provenance_sha256}"
printf 'dsym_sha256=%s\n' "${dsym_sha256}"
