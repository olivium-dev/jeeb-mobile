#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_PATH="${1:-${REPO_ROOT}/android/app/src/dev/google-services.json}"
REQUIRED_PACKAGE="app.jeeb.mobile.dev"
CONTRACT="${REPO_ROOT}/contracts/jeeb-firebase-v1.json"
APPS="${REPO_ROOT}/contracts/jeeb-mobile-firebase-apps-v1.json"

fail() {
  printf 'Dev Firebase config invalid: %s\n' "$1" >&2
  exit 1
}

if [[ ! -s "${CONFIG_PATH}" ]]; then
  fail 'config file is missing or empty; inject the protected dev config'
fi

if ! command -v jq >/dev/null 2>&1; then
  fail 'jq is required for structural validation'
fi

bash "${REPO_ROOT}/tool/validate_jeeb_firebase_contract.sh" >/dev/null
EXPECTED_PROJECT_NUMBER="$(jq -r '.projectNumber' "${CONTRACT}")"
EXPECTED_PROJECT_ID="$(jq -r '.projectId' "${CONTRACT}")"
EXPECTED_APP_ID="$(jq -r '.android.dev.appId' "${APPS}")"

if ! jq -e 'type == "object"' "${CONFIG_PATH}" >/dev/null 2>&1; then
  fail 'config is not valid JSON'
fi

if ! jq -e --arg package "${REQUIRED_PACKAGE}" '
  .client | type == "array"
  and ([
    .[]?
    | select(.client_info.android_client_info.package_name == $package)
  ] | length == 1)
' "${CONFIG_PATH}" >/dev/null 2>&1; then
  fail 'exactly one client must match the required dev package'
fi

if jq -e --arg package "${REQUIRED_PACKAGE}" '
  def is_sentinel:
    type == "string"
    and (
      ascii_downcase
      | test(
          "^(todo|dummy|placeholder|changeme|replace([_ -]?me)?|not[_ -]?real)([_ -].*)?$"
        )
        or test(
          "^aizasy(todo|dummy|placeholder|changeme|replace|notreal)[0-9a-z_-]*$"
        )
    );
  [
    .project_info.project_number,
    .project_info.project_id,
      .project_info.storage_bucket,
    (
      .client
      | map(select(.client_info.android_client_info.package_name == $package))
      | .[0].client_info.mobilesdk_app_id
    ),
    (
      .client
      | map(select(.client_info.android_client_info.package_name == $package))
      | .[0].api_key[]?.current_key
    )
  ]
  | any(.[]; is_sentinel)
' "${CONFIG_PATH}" >/dev/null 2>&1; then
  fail 'config contains dummy or placeholder values'
fi

if ! jq -e --arg package "${REQUIRED_PACKAGE}" '
  .project_info as $project
  | (.client
      | map(select(
          .client_info.android_client_info.package_name == $package
        ))
      | .[0]) as $dev
  | ($project.project_number | type == "string"
      and test("^[1-9][0-9]{5,}$"))
  and ($project.project_id | type == "string"
      and test("^[a-z][a-z0-9-]{4,28}[a-z0-9]$"))
  and ($project.storage_bucket | type == "string" and length > 0)
  and (.configuration_version == "1")
  and ($dev.client_info.mobilesdk_app_id | type == "string")
  and ($dev.api_key | type == "array" and length > 0)
  and ($dev.api_key[0].current_key | type == "string")
' "${CONFIG_PATH}" >/dev/null 2>&1; then
  fail 'required Firebase fields are missing or malformed'
fi

if ! jq -e --arg package "${REQUIRED_PACKAGE}" '
  .project_info.project_number as $project_number
  | (.client
      | map(select(
          .client_info.android_client_info.package_name == $package
        ))
      | .[0]) as $dev
  | ($dev.client_info.mobilesdk_app_id
      | test("^1:" + $project_number + ":android:[0-9a-fA-F]{16,64}$"))
  and ($dev.api_key[0].current_key | test("^AIza[0-9A-Za-z_-]{35}$"))
' "${CONFIG_PATH}" >/dev/null 2>&1; then
  fail 'Firebase app id or API key has an invalid shape'
fi

if ! jq -e \
  --arg package "${REQUIRED_PACKAGE}" \
  --arg project_number "${EXPECTED_PROJECT_NUMBER}" \
  --arg project_id "${EXPECTED_PROJECT_ID}" \
  --arg app_id "${EXPECTED_APP_ID}" '
  (.client
    | map(select(
        .client_info.android_client_info.package_name == $package
      ))
    | .[0]) as $dev
  | .project_info.project_number == $project_number
  and .project_info.project_id == $project_id
  and $dev.client_info.mobilesdk_app_id == $app_id
' "${CONFIG_PATH}" >/dev/null 2>&1; then
  fail 'config does not match the committed canonical Firebase identity'
fi

printf '%s\n' \
  'Dev Firebase config matches the committed canonical identity; this does not verify live FCM viability.'
