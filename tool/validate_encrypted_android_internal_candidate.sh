#!/usr/bin/env bash

set -euo pipefail

CIPHERTEXT_PATH="${1:-}"
RECIPIENT_CERTIFICATE_PATH="${2:-}"
PRIVATE_KEY_PATH="${3:-}"
OUTPUT_DIRECTORY="${4:-}"
TOOL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "${TMP_DIR}"' EXIT HUP INT TERM

fail() {
  printf 'Encrypted Android internal candidate rejected: %s\n' "$1" >&2
  exit 1
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d ' ' -f1
  else
    shasum -a 256 "$1" | cut -d ' ' -f1
  fi
}

[[ -f "${CIPHERTEXT_PATH}" && ! -L "${CIPHERTEXT_PATH}" &&
  -s "${CIPHERTEXT_PATH}" ]] || fail 'ciphertext is unavailable'
[[ -n "${OUTPUT_DIRECTORY}" && ! -e "${OUTPUT_DIRECTORY}" ]] ||
  fail 'private output directory is invalid or already exists'

inner_archive="${TMP_DIR}/candidate.zip"
bash "${TOOL_DIR}/android_internal_candidate_custody.sh" decrypt \
  "${CIPHERTEXT_PATH}" "${inner_archive}" \
  "${RECIPIENT_CERTIFICATE_PATH}" "${PRIVATE_KEY_PATH}"
python3 "${TOOL_DIR}/android_internal_candidate_custody.py" extract-inner \
  --archive "${inner_archive}" --output-dir "${OUTPUT_DIRECTORY}"

aab="${OUTPUT_DIRECTORY}/candidate.aab"
metadata="${OUTPUT_DIRECTORY}/output-metadata.json"
mapping="${OUTPUT_DIRECTORY}/mapping.txt"
provenance="${OUTPUT_DIRECTORY}/provenance.json"
bash "${TOOL_DIR}/validate_android_internal_devtool_artifact.sh" \
  "${aab}" "${provenance}" "${metadata}" >/dev/null

candidate_cms_sha="$(sha256_file "${CIPHERTEXT_PATH}")"
aab_sha="$(sha256_file "${aab}")"
metadata_sha="$(sha256_file "${metadata}")"
mapping_sha="$(sha256_file "${mapping}")"
provenance_sha="$(sha256_file "${provenance}")"
jq -e --arg mapping "${mapping_sha}" \
  '.mapping_sha256 == $mapping' "${provenance}" >/dev/null ||
  fail 'mapping hash does not match reviewed provenance'

printf 'candidate_cms_sha256=%s\n' "${candidate_cms_sha}"
printf 'aab_sha256=%s\n' "${aab_sha}"
printf 'metadata_sha256=%s\n' "${metadata_sha}"
printf 'provenance_sha256=%s\n' "${provenance_sha}"
printf 'mapping_sha256=%s\n' "${mapping_sha}"
