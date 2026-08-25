#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "${TMP_DIR}"' EXIT HUP INT TERM

export REVIEWED_SHA=1111111111111111111111111111111111111111
export BUILD_NAME=1.4.0
export BUILD_NUMBER=26082501
export SOURCE_RUN_ID=123456
export SOURCE_RUN_ATTEMPT=2
export OMDS_SHA=2222222222222222222222222222222222222222
ipa_path="${TMP_DIR}/jeeb.ipa"
dsym_path="${TMP_DIR}/Jeeb-dSYMs.zip"
provenance_path="${TMP_DIR}/provenance.json"

mkdir -p "${TMP_DIR}/ipa/Payload/Runner.app"
printf '%s\n' 'signed-app-fixture' >"${TMP_DIR}/ipa/Payload/Runner.app/fixture"
(
  cd "${TMP_DIR}/ipa"
  zip -qr "${ipa_path}" Payload
)
mkdir -p "${TMP_DIR}/dsym/Runner.app.dSYM/Contents/Resources"
printf '%s\n' 'symbol-fixture' \
  >"${TMP_DIR}/dsym/Runner.app.dSYM/Contents/Resources/fixture"
(
  cd "${TMP_DIR}/dsym"
  zip -qr "${dsym_path}" Runner.app.dSYM
)

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d ' ' -f1
  else
    shasum -a 256 "$1" | cut -d ' ' -f1
  fi
}

ipa_sha="$(sha256_file "${ipa_path}")"
dsym_sha="$(sha256_file "${dsym_path}")"
jq -n \
  --arg ipa "${ipa_sha}" \
  --arg dsym "${dsym_sha}" \
  --arg reviewed "${REVIEWED_SHA}" \
  --arg name "${BUILD_NAME}" \
  --arg number "${BUILD_NUMBER}" \
  --arg source_run "${SOURCE_RUN_ID}" \
  --arg source_attempt "${SOURCE_RUN_ATTEMPT}" \
  --arg omds "${OMDS_SHA}" '
    {
      platform: "ios",
      native_id: "com.olivium.jeeb",
      runtime: "staging",
      artifact_sha256: $ipa,
      dsym_sha256: $dsym,
      reviewed_sha: $reviewed,
      build_name: $name,
      build_number: $number,
      dependency_sha: $omds,
      source_run_id: $source_run,
      source_run_attempt: $source_attempt,
      source_head_sha: $reviewed,
      source_workflow_path: ".github/workflows/trusted-mobile-rc.yml",
      source_workflow_ref:
        "olivium-dev/jeeb-mobile/.github/workflows/trusted-mobile-rc.yml@refs/heads/main",
      clarity_enabled: false,
      retained: true,
      store_uploaded: false
    }
  ' >"${provenance_path}"

validator="${REPO_ROOT}/tool/validate_ios_rc_artifact.sh"
bash "${validator}" "${ipa_path}" "${provenance_path}" "${dsym_path}" \
  >/dev/null

assert_rejected_provenance() {
  local filter="$1"
  local label="$2"
  local candidate="${TMP_DIR}/${label}.json"
  jq "${filter}" "${provenance_path}" >"${candidate}"
  if bash "${validator}" "${ipa_path}" "${candidate}" "${dsym_path}" \
    >/dev/null 2>&1; then
    printf 'iOS RC validator accepted negative provenance: %s\n' \
      "${label}" >&2
    exit 1
  fi
}

assert_rejected_provenance '.artifact_sha256 = ("a" * 64)' wrong-ipa
assert_rejected_provenance '.dsym_sha256 = ("b" * 64)' wrong-dsym
assert_rejected_provenance '.reviewed_sha = ("3" * 40)' wrong-reviewed-sha
assert_rejected_provenance '.source_run_attempt = "9"' wrong-run-attempt
assert_rejected_provenance '.source_workflow_path = "Trusted mobile release candidate"' display-name-source
assert_rejected_provenance '.source_workflow_ref = "refs/heads/main"' wrong-workflow-ref

if EXPECTED_IPA_SHA256="$(printf 'f%.0s' {1..64})" \
  bash "${validator}" "${ipa_path}" "${provenance_path}" "${dsym_path}" \
  >/dev/null 2>&1; then
  printf '%s\n' 'iOS RC validator accepted a mismatched source-policy IPA hash.' >&2
  exit 1
fi
if EXPECTED_PROVENANCE_SHA256="$(printf 'e%.0s' {1..64})" \
  bash "${validator}" "${ipa_path}" "${provenance_path}" "${dsym_path}" \
  >/dev/null 2>&1; then
  printf '%s\n' \
    'iOS RC validator accepted a mismatched source-policy provenance hash.' >&2
  exit 1
fi
if EXPECTED_DSYM_SHA256="$(printf 'd%.0s' {1..64})" \
  bash "${validator}" "${ipa_path}" "${provenance_path}" "${dsym_path}" \
  >/dev/null 2>&1; then
  printf '%s\n' 'iOS RC validator accepted a mismatched source-policy dSYM hash.' >&2
  exit 1
fi

printf '%s\n' 'iOS retained RC artifact negative controls passed.'
