#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATOR="${REPO_ROOT}/tool/validate_dev_google_services.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

PASS_COUNT=0
EXPECTED_PROJECT_NUMBER="123456789012"
EXPECTED_PROJECT_ID="jeeb-dev-test"
EXPECTED_APP_ID="1:123456789012:android:0123456789abcdef0123456789abcdef"

run_validator() {
  DEV_FIREBASE_EXPECTED_PROJECT_NUMBER="${EXPECTED_PROJECT_NUMBER}" \
    DEV_FIREBASE_EXPECTED_PROJECT_ID="${EXPECTED_PROJECT_ID}" \
    DEV_FIREBASE_EXPECTED_APP_ID="${EXPECTED_APP_ID}" \
    bash "${VALIDATOR}" "$1"
}

write_valid_fixture() {
  local output_path="$1"
  cat >"${output_path}" <<'JSON'
{
  "project_info": {
    "project_number": "123456789012",
    "project_id": "jeeb-dev-test",
    "storage_bucket": "jeeb-dev-test.firebasestorage.app"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:123456789012:android:0123456789abcdef0123456789abcdef",
        "android_client_info": {
          "package_name": "app.jeeb.mobile.dev"
        }
      },
      "oauth_client": [],
      "api_key": [
        {
          "current_key": "AIzaSy0123456789abcdefghijklmnopqrstuvw"
        }
      ],
      "services": {}
    }
  ],
  "configuration_version": "1"
}
JSON
}

expect_pass() {
  local label="$1"
  local config_path="$2"
  local output
  if ! output="$(run_validator "${config_path}" 2>&1)"; then
    echo "not ok - ${label}: validator rejected a structurally valid fixture" >&2
    echo "${output}" >&2
    exit 1
  fi
  if [[ "${output}" != *"does not verify live FCM viability"* ]]; then
    echo "not ok - ${label}: success message overclaims structural validation" >&2
    echo "${output}" >&2
    exit 1
  fi
  PASS_COUNT=$((PASS_COUNT + 1))
  echo "ok - ${label}"
}

expect_fail() {
  local label="$1"
  local config_path="$2"
  local expected_message="$3"
  shift 3
  local forbidden_value
  local output
  if output="$(run_validator "${config_path}" 2>&1)"; then
    echo "not ok - ${label}: validator unexpectedly passed" >&2
    exit 1
  fi
  if [[ "${output}" != *"${expected_message}"* ]]; then
    echo "not ok - ${label}: expected a redacted '${expected_message}' error" >&2
    echo "${output}" >&2
    exit 1
  fi
  for forbidden_value in "$@"; do
    if [[ -n "${forbidden_value}" && "${output}" == *"${forbidden_value}"* ]]; then
      echo "not ok - ${label}: validator leaked a config value" >&2
      exit 1
    fi
  done
  PASS_COUNT=$((PASS_COUNT + 1))
  echo "ok - ${label}"
}

VALID_CONFIG="${TMP_DIR}/valid.json"
write_valid_fixture "${VALID_CONFIG}"

expect_pass "valid-shaped dev fixture" "${VALID_CONFIG}"
expect_fail "missing file" "${TMP_DIR}/missing.json" "config file is missing"

if OUTPUT="$(
  DEV_FIREBASE_EXPECTED_PROJECT_NUMBER='' \
    DEV_FIREBASE_EXPECTED_PROJECT_ID='' \
    DEV_FIREBASE_EXPECTED_APP_ID='' \
    bash "${VALIDATOR}" "${VALID_CONFIG}" 2>&1
)"; then
  echo "not ok - missing protected expected identity inputs: validator passed" >&2
  exit 1
fi
if [[ "${OUTPUT}" != *"protected expected Firebase identity inputs are missing"* ]]; then
  echo "not ok - missing protected expected identity inputs: wrong error" >&2
  exit 1
fi
PASS_COUNT=$((PASS_COUNT + 1))
echo "ok - missing protected expected identity inputs"

MALFORMED_CONFIG="${TMP_DIR}/malformed.json"
SENSITIVE_SENTINEL="SENSITIVE_SENTINEL_MUST_NOT_APPEAR"
printf '{"project_info":"%s"' "${SENSITIVE_SENTINEL}" >"${MALFORMED_CONFIG}"
expect_fail \
  "malformed JSON" \
  "${MALFORMED_CONFIG}" \
  "config is not valid JSON" \
  "${SENSITIVE_SENTINEL}"

MISSING_FIELD_CONFIG="${TMP_DIR}/missing-field.json"
jq 'del(.client[0].api_key)' "${VALID_CONFIG}" >"${MISSING_FIELD_CONFIG}"
expect_fail \
  "missing required field" \
  "${MISSING_FIELD_CONFIG}" \
  "required Firebase fields are missing"

DUMMY_CONFIG="${TMP_DIR}/dummy.json"
jq '.client[0].api_key[0].current_key = "AIzaSyDUMMY000000000000000000000000000"' \
  "${VALID_CONFIG}" >"${DUMMY_CONFIG}"
expect_fail "dummy value" "${DUMMY_CONFIG}" "dummy or placeholder values"

PLACEHOLDER_CONFIG="${TMP_DIR}/placeholder.json"
jq '.project_info.project_id = "TODO_PROJECT_ID"' \
  "${VALID_CONFIG}" >"${PLACEHOLDER_CONFIG}"
expect_fail \
  "placeholder value" \
  "${PLACEHOLDER_CONFIG}" \
  "dummy or placeholder values"
expect_fail \
  "committed safe template" \
  "${REPO_ROOT}/android/app/src/dev/google-services.json.template" \
  "dummy or placeholder values"

LEGITIMATE_MARKER_TEXT_CONFIG="${TMP_DIR}/legitimate-marker-text.json"
jq '.metadata.note = "example placeholder migration documentation"' \
  "${VALID_CONFIG}" >"${LEGITIMATE_MARKER_TEXT_CONFIG}"
expect_pass \
  "legitimate marker words outside identity fields" \
  "${LEGITIMATE_MARKER_TEXT_CONFIG}"

LEGITIMATE_PROJECT_ID_CONFIG="${TMP_DIR}/legitimate-project-id.json"
jq '
  .project_info.project_id = "jeeb-placeholder-dev"
  | .project_info.storage_bucket = "jeeb-placeholder-dev.firebasestorage.app"
' "${VALID_CONFIG}" >"${LEGITIMATE_PROJECT_ID_CONFIG}"
EXPECTED_PROJECT_ID="jeeb-placeholder-dev" expect_pass \
  "legitimate placeholder substring in expected project id" \
  "${LEGITIMATE_PROJECT_ID_CONFIG}"

IDENTITY_MISMATCH_CONFIG="${TMP_DIR}/identity-mismatch.json"
jq '.project_info.project_id = "jeeb-other-valid-dev"' \
  "${VALID_CONFIG}" >"${IDENTITY_MISMATCH_CONFIG}"
expect_fail \
  "protected expected identity mismatch" \
  "${IDENTITY_MISMATCH_CONFIG}" \
  "does not match the protected expected Firebase identity"

WRONG_PACKAGE_CONFIG="${TMP_DIR}/wrong-package.json"
jq '.client[0].client_info.android_client_info.package_name = "app.other.mobile.dev"' \
  "${VALID_CONFIG}" >"${WRONG_PACKAGE_CONFIG}"
expect_fail \
  "wrong package" \
  "${WRONG_PACKAGE_CONFIG}" \
  "exactly one client must match the required dev package"

PROD_ONLY_CONFIG="${TMP_DIR}/prod-only.json"
jq '.client[0].client_info.android_client_info.package_name = "app.jeeb.mobile"' \
  "${VALID_CONFIG}" >"${PROD_ONLY_CONFIG}"
expect_fail \
  "production-only config" \
  "${PROD_ONLY_CONFIG}" \
  "exactly one client must match the required dev package"

WRONG_APP_ID="1:123456789012:android:fedcba9876543210fedcba9876543210"
WRONG_API_KEY="AIzaSyzyxwvutsrqponmlkjihgfedcba987654321"
VALID_API_KEY="AIzaSy0123456789abcdefghijklmnopqrstuvw"
DUPLICATE_CLIENT_MESSAGE="exactly one client must match the required dev package"

DUPLICATE_WRONG_FIRST_CONFIG="${TMP_DIR}/duplicate-wrong-first.json"
jq --arg app_id "${WRONG_APP_ID}" --arg api_key "${WRONG_API_KEY}" '
  .client = (
    (.client[0]
      | .client_info.mobilesdk_app_id = $app_id
      | .api_key[0].current_key = $api_key) as $wrong
    | [$wrong, .client[0]]
  )
' "${VALID_CONFIG}" >"${DUPLICATE_WRONG_FIRST_CONFIG}"
expect_fail \
  "duplicate dev clients, wrong first and correct second" \
  "${DUPLICATE_WRONG_FIRST_CONFIG}" \
  "${DUPLICATE_CLIENT_MESSAGE}" \
  "${WRONG_APP_ID}" \
  "${WRONG_API_KEY}" \
  "${EXPECTED_APP_ID}" \
  "${VALID_API_KEY}" \
  "${EXPECTED_PROJECT_NUMBER}" \
  "${EXPECTED_PROJECT_ID}" \
  "app.jeeb.mobile.dev"

DUPLICATE_CORRECT_FIRST_CONFIG="${TMP_DIR}/duplicate-correct-first.json"
jq --arg app_id "${WRONG_APP_ID}" --arg api_key "${WRONG_API_KEY}" '
  .client = (
    (.client[0]
      | .client_info.mobilesdk_app_id = $app_id
      | .api_key[0].current_key = $api_key) as $wrong
    | [.client[0], $wrong]
  )
' "${VALID_CONFIG}" >"${DUPLICATE_CORRECT_FIRST_CONFIG}"
expect_fail \
  "duplicate dev clients, correct first and wrong second" \
  "${DUPLICATE_CORRECT_FIRST_CONFIG}" \
  "${DUPLICATE_CLIENT_MESSAGE}" \
  "${WRONG_APP_ID}" \
  "${WRONG_API_KEY}" \
  "${EXPECTED_APP_ID}" \
  "${VALID_API_KEY}" \
  "${EXPECTED_PROJECT_NUMBER}" \
  "${EXPECTED_PROJECT_ID}" \
  "app.jeeb.mobile.dev"

DUPLICATE_BOTH_CORRECT_CONFIG="${TMP_DIR}/duplicate-both-correct.json"
jq '.client += [.client[0]]' \
  "${VALID_CONFIG}" >"${DUPLICATE_BOTH_CORRECT_CONFIG}"
expect_fail \
  "duplicate dev clients, both correct" \
  "${DUPLICATE_BOTH_CORRECT_CONFIG}" \
  "${DUPLICATE_CLIENT_MESSAGE}" \
  "${EXPECTED_APP_ID}" \
  "${VALID_API_KEY}" \
  "${EXPECTED_PROJECT_NUMBER}" \
  "${EXPECTED_PROJECT_ID}" \
  "app.jeeb.mobile.dev"

echo "${PASS_COUNT} validator checks passed"
