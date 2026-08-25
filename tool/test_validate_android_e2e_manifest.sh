#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "${TMP_DIR}"' EXIT HUP INT TERM

export RC_RUN_ID=123456
export RC_RUN_ATTEMPT=2
export REVIEWED_SHA=1111111111111111111111111111111111111111
export RC_AAB_SHA256=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
export RC_PROVENANCE_SHA256=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
export BUILD_NAME=1.4.0
export BUILD_NUMBER=26082501
manifest="${TMP_DIR}/manifest.json"

jq -n \
  --arg rc_run "${RC_RUN_ID}" \
  --arg rc_attempt "${RC_RUN_ATTEMPT}" \
  --arg reviewed "${REVIEWED_SHA}" \
  --arg aab "${RC_AAB_SHA256}" \
  --arg provenance "${RC_PROVENANCE_SHA256}" '
    {
      schemaVersion: 1,
      verdict: "PASS",
      stage: "pre_distribution_rc",
      finalReleaseGo: false,
      rc: {
        workflowPath: ".github/workflows/trusted-mobile-rc.yml",
        runId: $rc_run,
        runAttempt: $rc_attempt,
        reviewedSha: $reviewed,
        android: {
          aabSha256: $aab,
          provenanceSha256: $provenance,
          packageName: "com.olivium.jeeb",
          buildName: "1.4.0",
          buildNumber: "26082501",
          stagingOrigin: "https://app.jeeb.fds-1.com",
          signerFingerprintReference: "rc-provenance:android.upload_sha256"
        }
      },
      devices: {
        physicalCount: 2,
        items: [
          {alias: "S24", identityHash: ("1" * 64), physical: true},
          {alias: "A33", identityHash: ("2" * 64), physical: true}
        ]
      },
      installSource: {
        kind: "bundletool-derived-from-retained-aab",
        aabSha256: $aab,
        derivedApkSha256: ("c" * 64),
        derivedApkSignerSha256: ("D" * 64),
        bundletoolVersion: "1.18.1"
      },
      mocking: false,
      scenarios: [
        {id: "JMS-JHP-001", result: "PASS"},
        {id: "JMS-JHP-002", result: "PASS"},
        {id: "JMS-JHP-003", result: "PASS"}
      ]
    }
  ' >"${manifest}"

validator="${REPO_ROOT}/tool/validate_android_e2e_manifest.sh"
bash "${validator}" "${manifest}" >/dev/null

assert_rejected() {
  local filter="$1"
  local label="$2"
  local candidate="${TMP_DIR}/${label}.json"
  jq "${filter}" "${manifest}" >"${candidate}"
  if bash "${validator}" "${candidate}" >/dev/null 2>&1; then
    printf 'Manifest validator accepted negative control: %s\n' "${label}" >&2
    exit 1
  fi
}

assert_rejected '.rc.android.aabSha256 = ("9" * 64)' wrong-aab
assert_rejected '.devices.items[0].physical = false' emulator-device
assert_rejected '.devices.physicalCount = 1' one-device
assert_rejected '.scenarios[2].result = "FAIL"' failed-jms
assert_rejected '.stage = "final_release"' wrong-stage
assert_rejected '.phoneNumber = "+000000000"' sensitive-field
assert_rejected '.installSource.aabSha256 = ("8" * 64)' sideload-drift

for invalid_build_name in '1.4' '1.4.0.1' '' 'release'; do
  if BUILD_NAME="${invalid_build_name}" bash "${validator}" "${manifest}" \
    >/dev/null 2>&1; then
    printf 'Manifest validator accepted malformed build name: %s\n' \
      "${invalid_build_name}" >&2
    exit 1
  fi
done

printf '%s\n' 'Android E2E manifest negative controls passed.'
