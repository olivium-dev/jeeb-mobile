#!/usr/bin/env bash

set -euo pipefail

MANIFEST_PATH="${1:-}"
RC_RUN_ID="${RC_RUN_ID:-}"
RC_RUN_ATTEMPT="${RC_RUN_ATTEMPT:-}"
REVIEWED_SHA="${REVIEWED_SHA:-}"
RC_AAB_SHA256="${RC_AAB_SHA256:-}"
RC_PROVENANCE_SHA256="${RC_PROVENANCE_SHA256:-}"
BUILD_NAME="${BUILD_NAME:-}"
BUILD_NUMBER="${BUILD_NUMBER:-}"

fail() {
  printf 'Android E2E evidence manifest rejected: %s\n' "$1" >&2
  exit 1
}

[[ -s "${MANIFEST_PATH}" ]] || fail 'manifest is missing'
[[ "${RC_RUN_ID}" =~ ^[1-9][0-9]*$ ]] || fail 'RC run ID is malformed'
[[ "${RC_RUN_ATTEMPT}" =~ ^[1-9][0-9]*$ ]] || fail 'RC run attempt is malformed'
[[ "${REVIEWED_SHA}" =~ ^[0-9a-f]{40}$ ]] || fail 'reviewed SHA is malformed'
[[ "${RC_AAB_SHA256}" =~ ^[0-9a-f]{64}$ ]] || fail 'AAB SHA is malformed'
[[ "${RC_PROVENANCE_SHA256}" =~ ^[0-9a-f]{64}$ ]] ||
  fail 'provenance SHA is malformed'
[[ "${BUILD_NAME}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail 'build name is malformed'
[[ "${BUILD_NUMBER}" =~ ^[1-9][0-9]{0,9}$ ]] || fail 'build number is malformed'

required_scenarios='["JMS-JHP-001","JMS-JHP-002","JMS-JHP-003"]'
jq -e \
  --arg rc_run "${RC_RUN_ID}" \
  --arg rc_attempt "${RC_RUN_ATTEMPT}" \
  --arg reviewed "${REVIEWED_SHA}" \
  --arg aab "${RC_AAB_SHA256}" \
  --arg provenance "${RC_PROVENANCE_SHA256}" \
  --arg name "${BUILD_NAME}" \
  --arg number "${BUILD_NUMBER}" \
  --argjson required "${required_scenarios}" '
    .schemaVersion == 1
    and .verdict == "PASS"
    and .stage == "pre_distribution_rc"
    and .finalReleaseGo == false
    and .rc.workflowPath == ".github/workflows/trusted-mobile-rc.yml"
    and .rc.runId == $rc_run
    and .rc.runAttempt == $rc_attempt
    and .rc.reviewedSha == $reviewed
    and .rc.android.aabSha256 == $aab
    and .rc.android.provenanceSha256 == $provenance
    and .rc.android.packageName == "com.olivium.jeeb"
    and .rc.android.buildName == $name
    and .rc.android.buildNumber == $number
    and .rc.android.stagingOrigin == "https://app.jeeb.fds-1.com"
    and .rc.android.signerFingerprintReference ==
      "rc-provenance:android.upload_sha256"
    and .devices.physicalCount >= 2
    and (.devices.items | length) == 2
    and ([.devices.items[].alias] | sort) == ["A33", "S24"]
    and all(.devices.items[];
      .physical == true
      and (.identityHash | test("^[0-9a-f]{64}$"))
    )
    and .installSource.kind == "bundletool-derived-from-retained-aab"
    and .installSource.aabSha256 == $aab
    and (.installSource.derivedApkSha256 | test("^[0-9a-f]{64}$"))
    and (.installSource.derivedApkSignerSha256 | test("^[0-9A-F]{64}$"))
    and (.installSource.bundletoolVersion |
      test("^[0-9]+\\.[0-9]+(\\.[0-9]+)?$"))
    and .mocking == false
    and ([.scenarios[] | select(.result == "PASS") | .id] | sort)
      == ($required | sort)
    and ([.scenarios[].id] | sort) == ($required | sort)
    and ([.. | objects | keys[]] | map(ascii_downcase) | map(select(
      test("phone|otp|chat|location|latitude|longitude|password|secret|token|serial|udid")
    )) | length) == 0
  ' "${MANIFEST_PATH}" >/dev/null ||
  fail 'schema, RC binding, device, install, privacy, or JMS PASS contract failed'

printf '%s\n' 'Physical-Android pre-distribution E2E manifest accepted.'
