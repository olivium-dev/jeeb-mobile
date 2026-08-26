#!/usr/bin/env bash

set -euo pipefail

COMMAND="${1:-}"
if [[ $# -gt 0 ]]; then
  shift
fi
OPENSSL_BIN="${OPENSSL_BIN:-openssl}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "${TMP_DIR}"' EXIT HUP INT TERM

fail() {
  printf 'Android candidate custody rejected: %s\n' "$1" >&2
  exit 1
}

require_regular_file() {
  [[ -f "$1" && ! -L "$1" && -s "$1" ]] || fail "$2 is unavailable"
}

validate_recipient() {
  local certificate="$1"
  local report="${TMP_DIR}/recipient.txt"
  require_regular_file "${certificate}" 'reviewed recipient certificate'
  LC_ALL=C "${OPENSSL_BIN}" x509 -in "${certificate}" -noout \
    -checkend 2592000 >"${TMP_DIR}/checkend.txt" 2>&1 ||
    fail 'reviewed recipient certificate is invalid or near expiry'
  LC_ALL=C "${OPENSSL_BIN}" x509 -in "${certificate}" -noout -text \
    >"${report}" 2>&1 || fail 'reviewed recipient certificate is invalid'
  grep -Eq 'Public Key Algorithm: (rsaEncryption|rsa)' "${report}" ||
    fail 'reviewed recipient key is not RSA'
  local bits
  bits="$(sed -n 's/.*Public-Key: (\([0-9][0-9]*\) bit).*/\1/p' "${report}")"
  [[ "${bits}" =~ ^[0-9]+$ ]] || fail 'recipient RSA size is unavailable'
  (( bits == 4096 )) || fail 'recipient RSA key is not exactly 4096 bits'
  if grep -aEq 'BEGIN .*PRIVATE KEY' "${certificate}"; then
    fail 'reviewed recipient material contains a private key'
  fi
}

validate_profile() {
  local ciphertext="$1"
  local report="${TMP_DIR}/cms-profile.txt"
  local recipient_count ktri_count
  require_regular_file "${ciphertext}" 'ciphertext candidate'
  LC_ALL=C "${OPENSSL_BIN}" cms -cmsout -inform DER -in "${ciphertext}" \
    -print >"${report}" 2>&1 || fail 'ciphertext CMS structure is invalid'
  [[ "$(grep -Ec 'contentType: id-smime-ct-authEnvelopedData' "${report}")" == 1 ]] ||
    fail 'ciphertext is not one authenticated envelope'
  recipient_count="$(awk \
    '/^      d\.(ktri|kari|kekri|pwri|ori|other):/ {count++}
      END {print count + 0}' "${report}")"
  ktri_count="$(awk '/^      d\.ktri:/ {count++}
    END {print count + 0}' "${report}")"
  [[ "${recipient_count}" == 1 && "${ktri_count}" == 1 ]] ||
    fail 'ciphertext must contain exactly one total recipient and it must be RSA key transport'
  [[ "$(grep -Ec 'algorithm: rsaesOaep' "${report}")" == 1 ]] ||
    fail 'ciphertext key transport is not RSA-OAEP'
  [[ "$(grep -Ec 'OBJECT[[:space:]]*:sha256' "${report}")" == 2 ]] ||
    fail 'ciphertext OAEP hash and MGF are not SHA-256'
  [[ "$(grep -Ec 'OBJECT[[:space:]]*:mgf1' "${report}")" == 1 ]] ||
    fail 'ciphertext OAEP MGF is not MGF1'
  [[ "$(grep -Ec 'algorithm: aes-256-gcm' "${report}")" == 1 ]] ||
    fail 'ciphertext content encryption is not AES-256-GCM'
}

encrypt_candidate() {
  local plaintext="${1:-}"
  local ciphertext="${2:-}"
  local certificate="${3:-}"
  require_regular_file "${plaintext}" 'private candidate archive'
  [[ -n "${ciphertext}" && ! -e "${ciphertext}" ]] ||
    fail 'ciphertext output is invalid or already exists'
  validate_recipient "${certificate}"
  local encrypted="${TMP_DIR}/candidate.cms"
  LC_ALL=C "${OPENSSL_BIN}" cms -encrypt -binary \
    -in "${plaintext}" -out "${encrypted}" -outform DER \
    -aes-256-gcm -recip "${certificate}" \
    -keyopt rsa_padding_mode:oaep \
    -keyopt rsa_oaep_md:sha256 \
    -keyopt rsa_mgf1_md:sha256 \
    >"${TMP_DIR}/encrypt.txt" 2>&1 || fail 'candidate encryption failed'
  validate_profile "${encrypted}"
  install -m 0600 "${encrypted}" "${ciphertext}"
}

decrypt_candidate() {
  local ciphertext="${1:-}"
  local plaintext="${2:-}"
  local certificate="${3:-}"
  local private_key="${4:-}"
  [[ -n "${plaintext}" && ! -e "${plaintext}" ]] ||
    fail 'plaintext output is invalid or already exists'
  validate_recipient "${certificate}"
  require_regular_file "${private_key}" 'private decryption key'
  validate_profile "${ciphertext}"
  "${OPENSSL_BIN}" x509 -in "${certificate}" -pubkey -noout |
    "${OPENSSL_BIN}" pkey -pubin -outform DER \
      >"${TMP_DIR}/certificate-public.der" 2>"${TMP_DIR}/certificate-public.txt" ||
    fail 'recipient public key extraction failed'
  "${OPENSSL_BIN}" pkey -in "${private_key}" -pubout -outform DER \
    >"${TMP_DIR}/private-public.der" 2>"${TMP_DIR}/private-public.txt" ||
    fail 'private decryption key is invalid'
  cmp -s "${TMP_DIR}/certificate-public.der" "${TMP_DIR}/private-public.der" ||
    fail 'private decryption key does not match reviewed recipient'
  local decrypted="${TMP_DIR}/candidate.zip"
  LC_ALL=C "${OPENSSL_BIN}" cms -decrypt -binary -inform DER \
    -in "${ciphertext}" -out "${decrypted}" \
    -recip "${certificate}" -inkey "${private_key}" \
    >"${TMP_DIR}/decrypt.txt" 2>&1 || fail 'authenticated decryption failed'
  [[ -s "${decrypted}" ]] || fail 'authenticated plaintext is empty'
  install -m 0600 "${decrypted}" "${plaintext}"
}

case "${COMMAND}" in
  encrypt)
    encrypt_candidate "$@"
    ;;
  decrypt)
    decrypt_candidate "$@"
    ;;
  inspect)
    validate_profile "${1:-}"
    ;;
  *)
    fail 'unknown custody command'
    ;;
esac
