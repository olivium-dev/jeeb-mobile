#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATOR="${REPO_ROOT}/tool/validate_jeeb_firebase_contract.sh"
CANONICAL_CONTRACT="${REPO_ROOT}/contracts/jeeb-firebase-v1.json"
CANONICAL_APPS="${REPO_ROOT}/contracts/jeeb-mobile-firebase-apps-v1.json"
TMP_DIR="$(mktemp -d)"
VALIDATOR_TEST_PATH="${VALIDATOR_TEST_PATH:-${PATH}}"

cleanup() {
  rm -rf -- "${TMP_DIR}"
}
trap cleanup EXIT HUP INT TERM

run_validator() {
  PATH="${VALIDATOR_TEST_PATH}" bash "${VALIDATOR}"
}

expect_contract_failure() {
  local label="$1"
  local filter="$2"
  local candidate="${TMP_DIR}/${label}.json"
  jq "${filter}" "${CANONICAL_CONTRACT}" >"${candidate}"
  if JEEB_FIREBASE_CONTRACT_PATH="${candidate}" \
    JEEB_FIREBASE_APPS_PATH="${CANONICAL_APPS}" \
    run_validator >/dev/null 2>&1; then
    printf 'Expected contract rejection: %s\n' "${label}" >&2
    exit 1
  fi
}

expect_apps_failure() {
  local label="$1"
  local filter="$2"
  local candidate="${TMP_DIR}/${label}.json"
  jq "${filter}" "${CANONICAL_APPS}" >"${candidate}"
  if JEEB_FIREBASE_CONTRACT_PATH="${CANONICAL_CONTRACT}" \
    JEEB_FIREBASE_APPS_PATH="${candidate}" \
    run_validator >/dev/null 2>&1; then
    printf 'Expected app registration rejection: %s\n' "${label}" >&2
    exit 1
  fi
}

expect_contract_file_failure() {
  local label="$1"
  local candidate="$2"
  if JEEB_FIREBASE_CONTRACT_PATH="${candidate}" \
    JEEB_FIREBASE_APPS_PATH="${CANONICAL_APPS}" \
    run_validator >/dev/null 2>&1; then
    printf 'Expected contract byte rejection: %s\n' "${label}" >&2
    exit 1
  fi
}

without_rg_path() {
  local bin_dir="${TMP_DIR}/without-rg-bin"
  mkdir -p "${bin_dir}"

  local tool tool_path
  for tool in bash dirname grep jq shasum awk; do
    tool_path="$(command -v "${tool}")"
    ln -sf "${tool_path}" "${bin_dir}/${tool}"
  done

  printf '%s\n' "${bin_dir}"
}

broken_grep_path() {
  local bin_dir="${TMP_DIR}/broken-grep-bin"
  mkdir -p "${bin_dir}"

  local tool tool_path bash_path
  for tool in bash dirname jq shasum awk; do
    tool_path="$(command -v "${tool}")"
    ln -sf "${tool_path}" "${bin_dir}/${tool}"
  done
  bash_path="$(command -v bash)"
  printf '#!%s\nexit 2\n' "${bash_path}" >"${bin_dir}/grep"
  chmod +x "${bin_dir}/grep"

  printf '%s\n' "${bin_dir}"
}

run_validator >/dev/null
if VALIDATOR_TEST_PATH="$(broken_grep_path)" run_validator >/dev/null 2>&1; then
  printf 'Expected contract rejection when the source scanner errors\n' >&2
  exit 1
fi
reformatted_contract="${TMP_DIR}/reformatted.json"
jq -c . "${CANONICAL_CONTRACT}" >"${reformatted_contract}"
expect_contract_file_failure reformatted-contract "${reformatted_contract}"

duplicate_key_contract="${TMP_DIR}/duplicate-key.json"
awk 'NR == 3 { print "  \"projectId\": \"jeeb-5a293\"," } { print }' \
  "${CANONICAL_CONTRACT}" >"${duplicate_key_contract}"
expect_contract_file_failure duplicate-key-contract "${duplicate_key_contract}"

expect_contract_failure wrong-project '.projectId = "wrong-project"'
expect_contract_failure wrong-number '.projectNumber = "999999999999"'
expect_contract_failure named-database '.firestoreDatabaseId = "staging"'
expect_contract_failure chat-disabled '.chatEnabled = false'
expect_contract_failure wrong-producer '.pushProducer = "gateway"'
expect_contract_failure wrong-version '.schemaVersion = 2'
expect_apps_failure wrong-ios-dev-app '.ios.dev.appId = "1:1051234312170:ios:aaaaaaaaaaaaaaaa"'
expect_apps_failure named-dev-database '.environments.dev.firestoreDatabaseId = "staging"'
expect_apps_failure wrong-staging-app '.environments.staging.iosApp = "dev"'
expect_apps_failure extra-app-key '.ios.dev.unreviewed = true'

if [[ "${JEEB_FIREBASE_NO_RG_REENTRY:-false}" != true ]]; then
  JEEB_FIREBASE_NO_RG_REENTRY=true \
    VALIDATOR_TEST_PATH="$(without_rg_path)" \
    bash "$0" >/dev/null
fi

printf '%s\n' 'Jeeb Firebase contract negative controls passed.'
