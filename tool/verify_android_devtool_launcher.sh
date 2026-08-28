#!/usr/bin/env bash
#
# Physical-device contract for the two launchers in ONE normal dev APK.
#
# Usage:
#   tool/verify_android_devtool_launcher.sh SERIAL APK [EVIDENCE_DIR]
#
# The serial and APK are mandatory. The script installs once with replacement,
# preserves app data, injects no route or intent extras, and targets every adb
# command at that serial. It cold-starts both activities twice and uses Maestro
# semantic selectors to prove the normal activity stays in the product while
# the legacy launcher shows the Jeeber Dev Tool.
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "usage: $0 SERIAL APK [EVIDENCE_DIR]" >&2
  exit 64
fi

SERIAL="$1"
APK="$2"
EVIDENCE_DIR="${3:-build/devtool-launcher-contract/$(date -u +%Y%m%dT%H%M%SZ)}"
APP_ID="${APP_ID:-app.jeeb.mobile.dev}"
ADB="${ADB:-${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb}"
MAESTRO="${MAESTRO:-$HOME/.maestro/bin/maestro}"
APKANALYZER="${APKANALYZER:-${ANDROID_HOME:-$HOME/Library/Android/sdk}/cmdline-tools/latest/bin/apkanalyzer}"
PRODUCT_COMPONENT="${APP_ID}/com.olivium.jeeb.MainActivity"
DEVTOOL_COMPONENT="${APP_ID}/com.olivium.jeeb.LegacyDevToolLauncher"
CONTRACT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.maestro/contracts/devtool-launcher"

fail() {
  echo "[devtool-launcher-contract] ERROR: $*" >&2
  exit 1
}

[[ -n "${SERIAL}" && "${SERIAL}" != *[[:space:]]* ]] \
  || fail "SERIAL must be one explicit adb serial without whitespace."
[[ -f "${APK}" ]] || fail "APK does not exist: ${APK}"
[[ -x "${ADB}" ]] || fail "adb is not executable: ${ADB}"
[[ -x "${MAESTRO}" ]] || fail "Maestro is not executable: ${MAESTRO}"
[[ -x "${APKANALYZER}" ]] || fail "apkanalyzer is not executable: ${APKANALYZER}"
[[ -f "${CONTRACT_DIR}/product.yaml" ]] || fail "product flow is missing"
[[ -f "${CONTRACT_DIR}/devtool.yaml" ]] || fail "Dev Tool flow is missing"

[[ "$("${ADB}" -s "${SERIAL}" get-state 2>/dev/null)" == "device" ]] \
  || fail "${SERIAL} is not an attached, authorized adb device."

APK_APP_ID="$("${APKANALYZER}" manifest application-id "${APK}")"
[[ "${APK_APP_ID}" == "${APP_ID}" ]] \
  || fail "APK application id is '${APK_APP_ID}', expected '${APP_ID}'."

MANIFEST="$("${APKANALYZER}" manifest print "${APK}")"
[[ "${MANIFEST}" == *"com.olivium.jeeb.MainActivity"* ]] \
  || fail "APK is missing MainActivity."
[[ "${MANIFEST}" == *"com.olivium.jeeb.LegacyDevToolLauncher"* ]] \
  || fail "APK is missing LegacyDevToolLauncher; build with jeeb.devtool=true."

mkdir -p "${EVIDENCE_DIR}"
printf '%s\n' "serial=${SERIAL}" "apk=${APK}" "app_id=${APP_ID}" \
  >"${EVIDENCE_DIR}/contract-inputs.txt"
printf '%s\n' \
  "activity=com.olivium.jeeb.MainActivity" \
  "activity=com.olivium.jeeb.LegacyDevToolLauncher" \
  >"${EVIDENCE_DIR}/verified-activities.txt"

"${ADB}" -s "${SERIAL}" install -r -d "${APK}" \
  >"${EVIDENCE_DIR}/install.txt"

foreground_activity() {
  "${ADB}" -s "${SERIAL}" shell dumpsys activity activities \
    | awk '/mResumedActivity|topResumedActivity/ { print }'
}

wait_for_foreground() {
  local expected="$1"
  local evidence_file="$2"
  local foreground=""
  local attempt
  for attempt in {1..30}; do
    foreground="$(foreground_activity)"
    if [[ "${foreground}" == *"${expected}"* ]]; then
      printf '%s\n' "${foreground}" >"${evidence_file}"
      return 0
    fi
    sleep 1
  done
  printf '%s\n' "${foreground}" >"${evidence_file}"
  fail "foreground activity did not become ${expected}"
}

run_maestro() {
  local phase="$1"
  local flow="$2"
  mkdir -p "${EVIDENCE_DIR}/${phase}-debug" \
    "${EVIDENCE_DIR}/${phase}-screenshots"
  "${MAESTRO}" --device "${SERIAL}" test \
    -e "APP_ID=${APP_ID}" \
    --debug-output "${EVIDENCE_DIR}/${phase}-debug" \
    --test-output-dir "${EVIDENCE_DIR}/${phase}-screenshots" \
    --format JUNIT \
    --output "${EVIDENCE_DIR}/${phase}.xml" \
    "${CONTRACT_DIR}/${flow}"
}

cold_start_and_assert() {
  local phase="$1"
  local component="$2"
  local flow="$3"
  "${ADB}" -s "${SERIAL}" shell am force-stop "${APP_ID}"
  "${ADB}" -s "${SERIAL}" shell am start -W -n "${component}" \
    >"${EVIDENCE_DIR}/${phase}-start.txt"
  run_maestro "${phase}" "${flow}"
  wait_for_foreground "${component}" \
    "${EVIDENCE_DIR}/${phase}-foreground.txt"
}

cold_start_and_assert "01-product" "${PRODUCT_COMPONENT}" "product.yaml"
cold_start_and_assert "02-devtool" "${DEVTOOL_COMPONENT}" "devtool.yaml"
cold_start_and_assert "03-product-repeat" "${PRODUCT_COMPONENT}" "product.yaml"
cold_start_and_assert "04-devtool-repeat" "${DEVTOOL_COMPONENT}" "devtool.yaml"

echo "[devtool-launcher-contract] PASS evidence=${EVIDENCE_DIR}"
