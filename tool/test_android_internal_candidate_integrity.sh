#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="${REPO_ROOT}/tool/android_internal_candidate_integrity.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "${TMP_DIR}"' EXIT HUP INT TERM

expect_rejected() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    printf 'Integrity helper accepted negative control: %s\n' "${label}" >&2
    exit 1
  fi
}

write_metadata() {
  local path="$1"
  local variant="$2"
  local code="$3"
  mkdir -p "$(dirname "${path}")"
  jq -n --arg variant "${variant}" --argjson code "${code}" '
    {artifactType:{type:"MERGED_MANIFESTS", kind:"Directory"},
      applicationId:"com.olivium.jeeb", variantName:$variant,
      elementType:"File",
      elements:[{versionName:"1.0.0", versionCode:$code}]}
  ' >"${path}"
}

export ANDROID_PACKAGE_NAME=com.olivium.jeeb
export ANDROID_VARIANT_NAME=internalReleaseRelease
export MOBILE_BUILD_NAME=1.0.0
export MOBILE_BUILD_NUMBER=26082601

aab_root="${TMP_DIR}/aab-output"
mkdir -p "${aab_root}"
expect_rejected no-aab bash "${HELPER}" select-aab "${aab_root}"
printf 'candidate' >"${aab_root}/candidate.aab"
[[ "$(bash "${HELPER}" select-aab "${aab_root}")" == \
  "${aab_root}/candidate.aab" ]]
printf 'second' >"${aab_root}/second.aab"
expect_rejected multiple-aab bash "${HELPER}" select-aab "${aab_root}"
rm -f -- "${aab_root}/second.aab"

metadata_root="${TMP_DIR}/internalReleaseRelease"
metadata_output="${TMP_DIR}/retained-output-metadata.json"
mkdir -p "${metadata_root}"
expect_rejected no-metadata bash "${HELPER}" select-metadata \
  "${metadata_root}" "${metadata_output}"
write_metadata "${metadata_root}/one/output-metadata.json" wrongVariant 26082601
expect_rejected wrong-variant bash "${HELPER}" select-metadata \
  "${metadata_root}" "${metadata_output}"
write_metadata "${metadata_root}/one/output-metadata.json" \
  internalReleaseRelease 26082601
jq '.applicationId = "app.jeeb.mobile.dev"' \
  "${metadata_root}/one/output-metadata.json" \
  >"${TMP_DIR}/wrong-application.json"
mv "${TMP_DIR}/wrong-application.json" \
  "${metadata_root}/one/output-metadata.json"
expect_rejected wrong-application bash "${HELPER}" select-metadata \
  "${metadata_root}" "${metadata_output}"
write_metadata "${metadata_root}/one/output-metadata.json" \
  internalReleaseRelease 26082601
jq '.artifactType.type = "APK"' \
  "${metadata_root}/one/output-metadata.json" \
  >"${TMP_DIR}/wrong-artifact.json"
mv "${TMP_DIR}/wrong-artifact.json" \
  "${metadata_root}/one/output-metadata.json"
expect_rejected wrong-artifact bash "${HELPER}" select-metadata \
  "${metadata_root}" "${metadata_output}"
write_metadata "${metadata_root}/one/output-metadata.json" \
  internalReleaseRelease 26082602
expect_rejected wrong-version bash "${HELPER}" select-metadata \
  "${metadata_root}" "${metadata_output}"
printf '{malformed' >"${metadata_root}/one/output-metadata.json"
expect_rejected malformed-metadata bash "${HELPER}" select-metadata \
  "${metadata_root}" "${metadata_output}"
write_metadata "${metadata_root}/one/output-metadata.json" \
  internalReleaseRelease 26082601
bash "${HELPER}" select-metadata "${metadata_root}" "${metadata_output}"
jq -e '.artifactType.type == "MERGED_MANIFESTS"' \
  "${metadata_output}" >/dev/null
write_metadata "${metadata_root}/two/output-metadata.json" \
  internalReleaseRelease 26082601
expect_rejected multiple-metadata bash "${HELPER}" select-metadata \
  "${metadata_root}" "${metadata_output}"

store_password='candidate-integrity-test-password'
export ANDROID_STORE_PASSWORD="${store_password}"
alias_one=approved
alias_two=other
keystore_one="${TMP_DIR}/approved.p12"
keystore_two="${TMP_DIR}/other.p12"
for pair in "${keystore_one}:${alias_one}:Approved" \
  "${keystore_two}:${alias_two}:Other"; do
  IFS=: read -r keystore alias common_name <<<"${pair}"
  keytool -genkeypair -noprompt -storetype PKCS12 -keystore "${keystore}" \
    -storepass "${store_password}" -keypass "${store_password}" \
    -alias "${alias}" -keyalg RSA -keysize 2048 -validity 3650 \
    -dname "CN=${common_name}, OU=CI, O=Jeeb, C=LB" >/dev/null 2>&1
done

mkdir -p "${TMP_DIR}/archive/base/manifest"
printf 'com.olivium.jeeb DevToolLauncher\n' \
  >"${TMP_DIR}/archive/base/manifest/AndroidManifest.xml"
unsigned_aab="${TMP_DIR}/unsigned.aab"
(
  cd "${TMP_DIR}/archive"
  zip -qr "${unsigned_aab}" base
)
signed_aab="${TMP_DIR}/signed.aab"
cp "${unsigned_aab}" "${signed_aab}"
jarsigner -keystore "${keystore_one}" -storepass "${store_password}" \
  -keypass "${store_password}" "${signed_aab}" "${alias_one}" \
  >/dev/null 2>&1

fingerprints="$(bash "${HELPER}" extract-signer "${signed_aab}")"
export ANDROID_UPLOAD_CERT_SHA1="$(sed -n 's/^signer_sha1=//p' \
  <<<"${fingerprints}")"
export ANDROID_UPLOAD_CERT_SHA256="$(sed -n 's/^signer_sha256=//p' \
  <<<"${fingerprints}")"
verification="$(bash "${HELPER}" verify-signer "${signed_aab}" \
  "${keystore_one}" "${alias_one}")"
[[ "$(grep -c '^signer_sha' <<<"${verification}")" == 2 ]]

expect_rejected unsigned-aab bash "${HELPER}" verify-signer \
  "${unsigned_aab}" "${keystore_one}" "${alias_one}"
approved_sha1="${ANDROID_UPLOAD_CERT_SHA1}"
export ANDROID_UPLOAD_CERT_SHA1="$(printf '0%.0s' {1..40})"
expect_rejected wrong-sha1 bash "${HELPER}" verify-signer \
  "${signed_aab}" "${keystore_one}" "${alias_one}"
export ANDROID_UPLOAD_CERT_SHA1="${approved_sha1}"
approved_sha256="${ANDROID_UPLOAD_CERT_SHA256}"
export ANDROID_UPLOAD_CERT_SHA256="$(printf '0%.0s' {1..64})"
expect_rejected wrong-sha256 bash "${HELPER}" verify-signer \
  "${signed_aab}" "${keystore_one}" "${alias_one}"
export ANDROID_UPLOAD_CERT_SHA256="${approved_sha256}"

unsigned_entry_aab="${TMP_DIR}/unsigned-entry.aab"
cp "${signed_aab}" "${unsigned_entry_aab}"
printf 'unsigned\n' >"${TMP_DIR}/unsigned.txt"
(
  cd "${TMP_DIR}"
  zip -q "${unsigned_entry_aab}" unsigned.txt
)
expect_rejected unsigned-entry bash "${HELPER}" verify-signer \
  "${unsigned_entry_aab}" "${keystore_one}" "${alias_one}"

multiple_signer_aab="${TMP_DIR}/multiple-signer.aab"
cp "${signed_aab}" "${multiple_signer_aab}"
jarsigner -keystore "${keystore_two}" -storepass "${store_password}" \
  -keypass "${store_password}" "${multiple_signer_aab}" "${alias_two}" \
  >/dev/null 2>&1
expect_rejected multiple-signer bash "${HELPER}" verify-signer \
  "${multiple_signer_aab}" "${keystore_one}" "${alias_one}"
expect_rejected wrong-keystore-alias bash "${HELPER}" verify-signer \
  "${signed_aab}" "${keystore_two}" "${alias_two}"

printf '%s\n' \
  'Android internal candidate metadata and strict signer controls passed.'
