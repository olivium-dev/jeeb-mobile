#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "${TMP_DIR}"' EXIT HUP INT TERM

export ANDROID_PACKAGE_NAME=com.olivium.jeeb
export MOBILE_BUILD_NAME=1.0.0
export MOBILE_BUILD_NUMBER=26082601
export REVIEWED_SHA=1111111111111111111111111111111111111111
export SOURCE_RUN_ID=123456
export SOURCE_RUN_ATTEMPT=2
export SOURCE_WORKFLOW_REF='olivium-dev/jeeb-mobile/.github/workflows/trusted-android-internal-devtool-rc.yml@refs/heads/main'
export JEEB_DEVTOOL_BUILD=true
export JEEB_SUPER_LOGIN_ENABLED=false
export JEEB_CLARITY_ENABLED=false
export JEEB_CLARITY_PRIVACY_APPROVED=false
export JEEB_RELEASE_PROFILE=release

aab_path="${TMP_DIR}/jeeb-internal.aab"
metadata_path="${TMP_DIR}/output-metadata.json"
provenance_path="${TMP_DIR}/provenance.json"
mapping_path="${TMP_DIR}/mapping.txt"
mkdir -p "${TMP_DIR}/aab/base/manifest"
printf '%s\n' \
  'com.olivium.jeeb com.olivium.jeeb.MainActivity' \
  'com.olivium.jeeb.DevToolLauncher android.intent.action.MAIN' \
  'android.intent.category.LAUNCHER' \
  >"${TMP_DIR}/aab/base/manifest/AndroidManifest.xml"
(
  cd "${TMP_DIR}/aab"
  zip -qr "${aab_path}" base
)

store_password='artifact-validator-test-password'
keystore="${TMP_DIR}/validator.p12"
keytool -genkeypair -noprompt -storetype PKCS12 -keystore "${keystore}" \
  -storepass "${store_password}" -keypass "${store_password}" \
  -alias validator -keyalg RSA -keysize 2048 -validity 3650 \
  -dname 'CN=Validator, OU=CI, O=Jeeb, C=LB' >/dev/null 2>&1
jarsigner -keystore "${keystore}" -storepass "${store_password}" \
  -keypass "${store_password}" "${aab_path}" validator >/dev/null 2>&1
signer_result="$(bash \
  "${REPO_ROOT}/tool/android_internal_candidate_integrity.sh" \
  extract-signer "${aab_path}")"
signer_sha1="$(sed -n 's/^signer_sha1=//p' <<<"${signer_result}")"
signer_sha256="$(sed -n 's/^signer_sha256=//p' <<<"${signer_result}")"

jq -n \
  --arg package "${ANDROID_PACKAGE_NAME}" \
  --arg name "${MOBILE_BUILD_NAME}" \
  --argjson number "${MOBILE_BUILD_NUMBER}" '
    {version:3,
      artifactType:{type:"MERGED_MANIFESTS", kind:"Directory"},
      applicationId: $package, variantName: "internalReleaseRelease",
      elementType:"File",
      elements: [{versionName: $name, versionCode: $number}]}
  ' >"${metadata_path}"

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d ' ' -f1
  else
    shasum -a 256 "$1" | cut -d ' ' -f1
  fi
}

aab_sha="$(sha256_file "${aab_path}")"
metadata_sha="$(sha256_file "${metadata_path}")"
printf '%s\n' 'mapping fixture' >"${mapping_path}"
mapping_sha="$(sha256_file "${mapping_path}")"
jq -n \
  --arg aab "${aab_sha}" \
  --arg metadata "${metadata_sha}" \
  --arg mapping "${mapping_sha}" \
  --arg name "${MOBILE_BUILD_NAME}" \
  --arg number "${MOBILE_BUILD_NUMBER}" \
  --arg reviewed "${REVIEWED_SHA}" \
  --arg source_run "${SOURCE_RUN_ID}" \
  --arg source_attempt "${SOURCE_RUN_ATTEMPT}" \
  --arg workflow_ref "${SOURCE_WORKFLOW_REF}" \
  --arg signer_sha1 "${signer_sha1}" \
  --arg signer_sha256 "${signer_sha256}" '
    {platform:"android", package_name:"com.olivium.jeeb",
      native_id:"com.olivium.jeeb", flavor:"internalRelease",
      build_profile:"release", release_profile:true, runtime:"staging",
      version_name:$name, version_code:$number, build_name:$name,
      build_number:$number, artifact_sha256:$aab, metadata_sha256:$metadata,
      metadata_kind:"gradle-merged-manifest-v3", mapping_sha256:$mapping,
      signer_sha1:$signer_sha1, signer_sha256:$signer_sha256,
      reviewed_sha:$reviewed, source_run_id:$source_run,
      source_run_attempt:$source_attempt, source_head_sha:$reviewed,
      source_workflow_path:
        ".github/workflows/trusted-android-internal-devtool-rc.yml",
      source_workflow_ref:$workflow_ref,
      source_repository:"olivium-dev/jeeb-mobile",
      source_event:"workflow_dispatch", source_ref:"refs/heads/main",
      gateway_origin:"https://app.jeeb.fds-1.com",
      realtime_socket:"wss://app.jeeb.fds-1.com/socket/websocket",
      devtool:true, super_login:false, clarity_enabled:false,
      clarity_privacy_approved:false, retained:true, store_uploaded:false}
  ' >"${provenance_path}"

validator="${REPO_ROOT}/tool/validate_android_internal_devtool_artifact.sh"
bash "${validator}" "${aab_path}" "${provenance_path}" "${metadata_path}" \
  >/dev/null

openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
  -subj '/CN=Jeeb encrypted validator test' \
  -keyout "${TMP_DIR}/custody.key.pem" \
  -out "${TMP_DIR}/custody.cert.pem" >/dev/null 2>&1
python3 "${REPO_ROOT}/tool/android_internal_candidate_custody.py" pack-inner \
  --aab "${aab_path}" --metadata "${metadata_path}" \
  --mapping "${mapping_path}" --provenance "${provenance_path}" \
  --output "${TMP_DIR}/candidate.zip"
bash "${REPO_ROOT}/tool/android_internal_candidate_custody.sh" encrypt \
  "${TMP_DIR}/candidate.zip" "${TMP_DIR}/candidate.cms" \
  "${TMP_DIR}/custody.cert.pem"
encrypted_validation="$({
  bash "${REPO_ROOT}/tool/validate_encrypted_android_internal_candidate.sh" \
    "${TMP_DIR}/candidate.cms" "${TMP_DIR}/custody.cert.pem" \
    "${TMP_DIR}/custody.key.pem" "${TMP_DIR}/encrypted-output"
} 2>"${TMP_DIR}/encrypted-validation.log")"
[[ "$(sed -n 's/^aab_sha256=//p' <<<"${encrypted_validation}")" == \
  "${aab_sha}" ]]
unset encrypted_validation

printf '%s\n' 'changed mapping fixture' >"${TMP_DIR}/wrong-mapping.txt"
python3 "${REPO_ROOT}/tool/android_internal_candidate_custody.py" pack-inner \
  --aab "${aab_path}" --metadata "${metadata_path}" \
  --mapping "${TMP_DIR}/wrong-mapping.txt" --provenance "${provenance_path}" \
  --output "${TMP_DIR}/wrong-mapping.zip"
bash "${REPO_ROOT}/tool/android_internal_candidate_custody.sh" encrypt \
  "${TMP_DIR}/wrong-mapping.zip" "${TMP_DIR}/wrong-mapping.cms" \
  "${TMP_DIR}/custody.cert.pem"
if bash "${REPO_ROOT}/tool/validate_encrypted_android_internal_candidate.sh" \
  "${TMP_DIR}/wrong-mapping.cms" "${TMP_DIR}/custody.cert.pem" \
  "${TMP_DIR}/custody.key.pem" "${TMP_DIR}/wrong-mapping-output" \
  >/dev/null 2>&1; then
  printf '%s\n' 'Encrypted validator accepted mismatched mapping bytes.' >&2
  exit 1
fi

assert_rejected_provenance() {
  local filter="$1"
  local label="$2"
  local candidate="${TMP_DIR}/${label}.json"
  jq "${filter}" "${provenance_path}" >"${candidate}"
  if bash "${validator}" "${aab_path}" "${candidate}" "${metadata_path}" \
    >/dev/null 2>&1; then
    printf 'Validator accepted negative provenance: %s\n' "${label}" >&2
    exit 1
  fi
}

assert_rejected_provenance '.artifact_sha256 = ("a" * 64)' wrong-aab
assert_rejected_provenance '.package_name = "app.jeeb.mobile.dev"' wrong-package
assert_rejected_provenance '.version_name = "1.0.1"' wrong-version-name
assert_rejected_provenance '.version_code = "26082602"' wrong-version-code
assert_rejected_provenance '.build_profile = "debug"' wrong-profile
assert_rejected_provenance '.devtool = false' wrong-devtool
assert_rejected_provenance '.super_login = true' wrong-super-login
assert_rejected_provenance '.clarity_enabled = true' wrong-clarity
assert_rejected_provenance '.reviewed_sha = ("2" * 40)' wrong-reviewed-sha
assert_rejected_provenance '.source_run_id = "654321"' wrong-run
assert_rejected_provenance '.source_run_attempt = "9"' wrong-run-attempt
assert_rejected_provenance '.source_workflow_ref = "refs/heads/main"' wrong-workflow
assert_rejected_provenance '.signer_sha1 = ("0" * 40)' wrong-signer-sha1
assert_rejected_provenance '.signer_sha256 = ("0" * 64)' wrong-signer-sha256
assert_rejected_provenance '.metadata_kind = "bundle-output"' wrong-metadata-kind

printf '%s\n' '{malformed' >"${TMP_DIR}/malformed.json"
if bash "${validator}" "${aab_path}" "${TMP_DIR}/malformed.json" \
  "${metadata_path}" >/dev/null 2>&1; then
  printf '%s\n' 'Validator accepted malformed provenance JSON.' >&2
  exit 1
fi

jq '.elements[0].versionCode = 26082602' "${metadata_path}" \
  >"${TMP_DIR}/wrong-metadata.json"
if bash "${validator}" "${aab_path}" "${provenance_path}" \
  "${TMP_DIR}/wrong-metadata.json" >/dev/null 2>&1; then
  printf '%s\n' 'Validator accepted mismatched Gradle metadata.' >&2
  exit 1
fi

cp "${aab_path}" "${TMP_DIR}/wrong.aab"
printf '%s' 'changed' >>"${TMP_DIR}/wrong.aab"
if bash "${validator}" "${TMP_DIR}/wrong.aab" "${provenance_path}" \
  "${metadata_path}" >/dev/null 2>&1; then
  printf '%s\n' 'Validator accepted mismatched AAB bytes.' >&2
  exit 1
fi

if REVIEWED_SHA=3333333333333333333333333333333333333333 \
  bash "${validator}" "${aab_path}" "${provenance_path}" \
    "${metadata_path}" >/dev/null 2>&1; then
  printf '%s\n' 'Validator accepted mismatched reviewed SHA environment.' >&2
  exit 1
fi
if SOURCE_RUN_ID=999999 \
  bash "${validator}" "${aab_path}" "${provenance_path}" \
    "${metadata_path}" >/dev/null 2>&1; then
  printf '%s\n' 'Validator accepted mismatched source run environment.' >&2
  exit 1
fi

printf '%s\n' 'Android internal Dev Tool artifact negative controls passed.'
