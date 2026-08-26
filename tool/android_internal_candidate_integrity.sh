#!/usr/bin/env bash

set -euo pipefail

COMMAND="${1:-}"
if [[ $# -gt 0 ]]; then
  shift
fi
TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "${TMP_DIR}"' EXIT HUP INT TERM

fail() {
  printf 'Android internal candidate rejected: %s\n' "$1" >&2
  exit 1
}

normalize_fingerprint() {
  printf '%s' "$1" | tr -d ':' | tr '[:lower:]' '[:upper:]'
}

require_fingerprint() {
  local value="$1"
  local length="$2"
  [[ "${value}" =~ ^[0-9A-F]+$ && ${#value} -eq ${length} ]] ||
    fail 'certificate fingerprint is malformed'
}

extract_fingerprints() {
  local report="$1"
  local sha1_count sha256_count
  sha1_count="$(sed -n 's/^[[:space:]]*SHA1: //p' "${report}" | wc -l |
    tr -d '[:space:]')"
  sha256_count="$(sed -n 's/^[[:space:]]*SHA256: //p' "${report}" | wc -l |
    tr -d '[:space:]')"
  [[ "${sha1_count}" == 1 && "${sha256_count}" == 1 ]] ||
    fail 'certificate must expose exactly one SHA-1 and SHA-256 fingerprint'
  EXTRACTED_SHA1="$(normalize_fingerprint "$(
    sed -n 's/^[[:space:]]*SHA1: //p' "${report}"
  )")"
  EXTRACTED_SHA256="$(normalize_fingerprint "$(
    sed -n 's/^[[:space:]]*SHA256: //p' "${report}"
  )")"
  require_fingerprint "${EXTRACTED_SHA1}" 40
  require_fingerprint "${EXTRACTED_SHA256}" 64
}

extract_aab_signer() {
  local aab="$1"
  local report="${TMP_DIR}/aab-certificate.txt"
  [[ -s "${aab}" ]] || fail 'AAB is missing'
  LC_ALL=C keytool -printcert -jarfile "${aab}" >"${report}" 2>&1 ||
    fail 'AAB signer certificate is unavailable'
  extract_fingerprints "${report}"
}

select_aab() {
  local root="${1:-}"
  local count selected
  [[ -d "${root}" ]] || fail 'AAB output directory is missing'
  count="$(find "${root}" -type f -name '*.aab' | wc -l |
    tr -d '[:space:]')"
  [[ "${count}" == 1 ]] || fail 'expected exactly one AAB candidate'
  selected="$(find "${root}" -type f -name '*.aab' -print -quit)"
  [[ -s "${selected}" ]] || fail 'selected AAB is empty'
  printf '%s\n' "${selected}"
}

select_metadata() {
  local root="${1:-}"
  local destination="${2:-}"
  local count selected
  [[ "$(basename "${root}")" == internalReleaseRelease ]] ||
    fail 'metadata root is not the exact internal-release variant'
  [[ -d "${root}" ]] || fail 'merged-manifest metadata directory is missing'
  [[ -n "${destination}" ]] || fail 'metadata destination is missing'
  [[ "${ANDROID_PACKAGE_NAME:-}" == com.olivium.jeeb ]] ||
    fail 'expected package input is not canonical'
  [[ "${ANDROID_VARIANT_NAME:-}" == internalReleaseRelease ]] ||
    fail 'expected variant input is not internal release'
  [[ "${MOBILE_BUILD_NAME:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
    fail 'expected version name is malformed'
  [[ "${MOBILE_BUILD_NUMBER:-}" =~ ^[1-9][0-9]{0,9}$ ]] ||
    fail 'expected version code is malformed'
  count="$(find "${root}" -type f -name output-metadata.json | wc -l |
    tr -d '[:space:]')"
  [[ "${count}" == 1 ]] || fail 'expected exactly one metadata candidate'
  selected="$(find "${root}" -type f -name output-metadata.json -print -quit)"
  jq -e \
    --arg package "${ANDROID_PACKAGE_NAME:-}" \
    --arg variant "${ANDROID_VARIANT_NAME:-}" \
    --arg name "${MOBILE_BUILD_NAME:-}" \
    --argjson number "${MOBILE_BUILD_NUMBER}" '
      .version == 3
      and .artifactType.type == "MERGED_MANIFESTS"
      and .artifactType.kind == "Directory"
      and .applicationId == $package
      and .variantName == $variant
      and .elementType == "File"
      and (.elements | length) == 1
      and .elements[0].versionName == $name
      and .elements[0].versionCode == $number
    ' "${selected}" >/dev/null ||
    fail 'metadata artifact, package, variant, or version is invalid'
  install -m 0600 "${selected}" "${destination}"
}

verify_signer() {
  local aab="${1:-}"
  local keystore="${2:-}"
  local alias="${3:-}"
  local expected_sha1 expected_sha256 report marker_count
  [[ -s "${keystore}" ]] || fail 'approved keystore is missing'
  [[ -n "${alias}" && -n "${ANDROID_STORE_PASSWORD:-}" ]] ||
    fail 'approved keystore inputs are incomplete'
  expected_sha1="$(normalize_fingerprint "${ANDROID_UPLOAD_CERT_SHA1:-}")"
  expected_sha256="$(normalize_fingerprint "${ANDROID_UPLOAD_CERT_SHA256:-}")"
  require_fingerprint "${expected_sha1}" 40
  require_fingerprint "${expected_sha256}" 64

  command -v openssl >/dev/null 2>&1 ||
    fail 'OpenSSL is required to validate PKCS12 custody'
  report="${TMP_DIR}/pkcs12.txt"
  openssl pkcs12 -in "${keystore}" -passin env:ANDROID_STORE_PASSWORD \
    -noout >"${report}" 2>&1 || fail 'approved keystore is not PKCS12'

  report="${TMP_DIR}/keystore-certificate.txt"
  LC_ALL=C keytool -list -v -storetype PKCS12 -keystore "${keystore}" \
    -storepass:env ANDROID_STORE_PASSWORD -alias "${alias}" \
    >"${report}" 2>&1 || fail 'approved keystore alias is unavailable'
  extract_fingerprints "${report}"
  [[ "${EXTRACTED_SHA1}" == "${expected_sha1}" &&
    "${EXTRACTED_SHA256}" == "${expected_sha256}" ]] ||
    fail 'approved keystore alias fingerprint mismatch'
  local alias_sha1="${EXTRACTED_SHA1}"
  local alias_sha256="${EXTRACTED_SHA256}"

  extract_aab_signer "${aab}"
  [[ "${EXTRACTED_SHA1}" == "${alias_sha1}" &&
    "${EXTRACTED_SHA256}" == "${alias_sha256}" ]] ||
    fail 'AAB signer does not match the approved keystore alias'

  report="${TMP_DIR}/jarsigner.txt"
  LC_ALL=C jarsigner -verify -strict -verbose -certs \
    -storetype PKCS12 -keystore "${keystore}" \
    -storepass:env ANDROID_STORE_PASSWORD \
    "${aab}" "${alias}" >"${report}" 2>&1 ||
    fail 'strict AAB signature verification failed'
  marker_count="$(awk '$0 == "jar verified." {count++} END {print count + 0}' \
    "${report}")"
  [[ "${marker_count}" == 1 ]] ||
    fail 'strict AAB signature verification did not produce one success marker'
  printf 'signer_sha1=%s\n' "${EXTRACTED_SHA1}"
  printf 'signer_sha256=%s\n' "${EXTRACTED_SHA256}"
}

case "${COMMAND}" in
  select-aab)
    select_aab "$@"
    ;;
  select-metadata)
    select_metadata "$@"
    ;;
  extract-signer)
    extract_aab_signer "${1:-}"
    printf 'signer_sha1=%s\n' "${EXTRACTED_SHA1}"
    printf 'signer_sha256=%s\n' "${EXTRACTED_SHA256}"
    ;;
  verify-signer)
    verify_signer "$@"
    ;;
  *)
    fail 'unknown integrity command'
    ;;
esac
