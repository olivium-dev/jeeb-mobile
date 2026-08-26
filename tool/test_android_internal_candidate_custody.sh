#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CUSTODY="${REPO_ROOT}/tool/android_internal_candidate_custody.sh"
ARCHIVE="${REPO_ROOT}/tool/android_internal_candidate_custody.py"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "${TMP_DIR}"' EXIT HUP INT TERM

expect_rejected() {
  local label="$1"
  shift
  if "$@" >"${TMP_DIR}/${label}.log" 2>&1; then
    printf 'Custody negative control was accepted: %s\n' "${label}" >&2
    exit 1
  fi
  if grep -aFq 'CUSTODY-PLAINTEXT-SENTINEL' "${TMP_DIR}/${label}.log"; then
    printf 'Custody failure leaked plaintext: %s\n' "${label}" >&2
    exit 1
  fi
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d ' ' -f1
  else
    shasum -a 256 "$1" | cut -d ' ' -f1
  fi
}

for identity in approved wrong; do
  openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
    -subj "/CN=Jeeb ${identity} custody test" \
    -keyout "${TMP_DIR}/${identity}.key.pem" \
    -out "${TMP_DIR}/${identity}.cert.pem" >/dev/null 2>&1
done
openssl req -x509 -newkey rsa:3072 -sha256 -days 3650 -nodes \
  -subj '/CN=Jeeb undersized custody test' \
  -keyout "${TMP_DIR}/undersized.key.pem" \
  -out "${TMP_DIR}/undersized.cert.pem" >/dev/null 2>&1
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 \
  -sha256 -days 3650 -nodes -subj '/CN=Jeeb extra EC recipient test' \
  -keyout "${TMP_DIR}/extra-ec.key.pem" \
  -out "${TMP_DIR}/extra-ec.cert.pem" >/dev/null 2>&1

printf '%s\n' 'CUSTODY-PLAINTEXT-SENTINEL signed-aab' \
  >"${TMP_DIR}/candidate.aab"
printf '%s\n' '{"version":3}' >"${TMP_DIR}/output-metadata.json"
printf '%s\n' 'mapping body' >"${TMP_DIR}/mapping.txt"
printf '%s\n' '{"reviewed_sha":"1111111111111111111111111111111111111111"}' \
  >"${TMP_DIR}/provenance.json"

python3 "${ARCHIVE}" pack-inner \
  --aab "${TMP_DIR}/candidate.aab" \
  --metadata "${TMP_DIR}/output-metadata.json" \
  --mapping "${TMP_DIR}/mapping.txt" \
  --provenance "${TMP_DIR}/provenance.json" \
  --output "${TMP_DIR}/candidate.zip"

encrypt_log="$({
  bash "${CUSTODY}" encrypt "${TMP_DIR}/candidate.zip" \
    "${TMP_DIR}/candidate.cms" "${TMP_DIR}/approved.cert.pem"
} 2>&1)"
[[ -z "${encrypt_log}" ]]
bash "${CUSTODY}" inspect "${TMP_DIR}/candidate.cms"
decrypt_log="$({
  bash "${CUSTODY}" decrypt "${TMP_DIR}/candidate.cms" \
    "${TMP_DIR}/decrypted.zip" "${TMP_DIR}/approved.cert.pem" \
    "${TMP_DIR}/approved.key.pem"
} 2>&1)"
[[ -z "${decrypt_log}" ]]
python3 "${ARCHIVE}" extract-inner --archive "${TMP_DIR}/decrypted.zip" \
  --output-dir "${TMP_DIR}/decrypted"
[[ "$(sha256_file "${TMP_DIR}/candidate.aab")" == \
  "$(sha256_file "${TMP_DIR}/decrypted/candidate.aab")" ]]
cmp "${TMP_DIR}/output-metadata.json" \
  "${TMP_DIR}/decrypted/output-metadata.json"
cmp "${TMP_DIR}/mapping.txt" "${TMP_DIR}/decrypted/mapping.txt"
cmp "${TMP_DIR}/provenance.json" "${TMP_DIR}/decrypted/provenance.json"

expect_rejected missing-key bash "${CUSTODY}" decrypt \
  "${TMP_DIR}/candidate.cms" "${TMP_DIR}/missing-key.zip" \
  "${TMP_DIR}/approved.cert.pem" "${TMP_DIR}/absent.key.pem"
expect_rejected wrong-key bash "${CUSTODY}" decrypt \
  "${TMP_DIR}/candidate.cms" "${TMP_DIR}/wrong-key.zip" \
  "${TMP_DIR}/approved.cert.pem" "${TMP_DIR}/wrong.key.pem"
expect_rejected undersized-recipient bash "${CUSTODY}" encrypt \
  "${TMP_DIR}/candidate.zip" "${TMP_DIR}/undersized.cms" \
  "${TMP_DIR}/undersized.cert.pem"

bash "${CUSTODY}" encrypt "${TMP_DIR}/candidate.zip" \
  "${TMP_DIR}/wrong-recipient.cms" "${TMP_DIR}/wrong.cert.pem"
expect_rejected wrong-recipient bash "${CUSTODY}" decrypt \
  "${TMP_DIR}/wrong-recipient.cms" "${TMP_DIR}/wrong-recipient.zip" \
  "${TMP_DIR}/approved.cert.pem" "${TMP_DIR}/approved.key.pem"

python3 - "${TMP_DIR}/candidate.cms" "${TMP_DIR}/bitflip.cms" <<'PY'
from pathlib import Path
import sys

source = bytearray(Path(sys.argv[1]).read_bytes())
source[-1] ^= 1
Path(sys.argv[2]).write_bytes(source)
PY
expect_rejected authenticated-bitflip bash "${CUSTODY}" decrypt \
  "${TMP_DIR}/bitflip.cms" "${TMP_DIR}/bitflip.zip" \
  "${TMP_DIR}/approved.cert.pem" "${TMP_DIR}/approved.key.pem"

printf '%s\n' 'not a CMS object' >"${TMP_DIR}/not-cms.bin"
expect_rejected non-cms bash "${CUSTODY}" inspect "${TMP_DIR}/not-cms.bin"
openssl cms -encrypt -binary -in "${TMP_DIR}/candidate.zip" \
  -out "${TMP_DIR}/cbc.cms" -outform DER -aes256 \
  -recip "${TMP_DIR}/approved.cert.pem" >/dev/null 2>&1
expect_rejected non-auth-envelope bash "${CUSTODY}" inspect \
  "${TMP_DIR}/cbc.cms"
openssl cms -encrypt -binary -in "${TMP_DIR}/candidate.zip" \
  -out "${TMP_DIR}/aes128-gcm.cms" -outform DER -aes-128-gcm \
  -recip "${TMP_DIR}/approved.cert.pem" \
  -keyopt rsa_padding_mode:oaep -keyopt rsa_oaep_md:sha256 \
  -keyopt rsa_mgf1_md:sha256 >/dev/null 2>&1
expect_rejected wrong-content-cipher bash "${CUSTODY}" inspect \
  "${TMP_DIR}/aes128-gcm.cms"
openssl cms -encrypt -binary -in "${TMP_DIR}/candidate.zip" \
  -out "${TMP_DIR}/pkcs1-gcm.cms" -outform DER -aes-256-gcm \
  -recip "${TMP_DIR}/approved.cert.pem" >/dev/null 2>&1
expect_rejected wrong-key-transport bash "${CUSTODY}" inspect \
  "${TMP_DIR}/pkcs1-gcm.cms"
openssl cms -encrypt -binary -in "${TMP_DIR}/candidate.zip" \
  -out "${TMP_DIR}/oaep-sha1.cms" -outform DER -aes-256-gcm \
  -recip "${TMP_DIR}/approved.cert.pem" \
  -keyopt rsa_padding_mode:oaep >/dev/null 2>&1
expect_rejected wrong-oaep-digest bash "${CUSTODY}" inspect \
  "${TMP_DIR}/oaep-sha1.cms"
openssl cms -encrypt -binary -in "${TMP_DIR}/candidate.zip" \
  -out "${TMP_DIR}/mgf1-sha1.cms" -outform DER -aes-256-gcm \
  -recip "${TMP_DIR}/approved.cert.pem" \
  -keyopt rsa_padding_mode:oaep -keyopt rsa_oaep_md:sha256 \
  -keyopt rsa_mgf1_md:sha1 >/dev/null 2>&1
expect_rejected wrong-mgf-digest bash "${CUSTODY}" inspect \
  "${TMP_DIR}/mgf1-sha1.cms"
openssl cms -encrypt -binary -in "${TMP_DIR}/candidate.zip" \
  -out "${TMP_DIR}/mixed-recipients.cms" -outform DER -aes-256-gcm \
  -recip "${TMP_DIR}/approved.cert.pem" \
  -keyopt rsa_padding_mode:oaep -keyopt rsa_oaep_md:sha256 \
  -keyopt rsa_mgf1_md:sha256 -recip "${TMP_DIR}/extra-ec.cert.pem" \
  >/dev/null 2>&1
expect_rejected mixed-rsa-ec-recipients bash "${CUSTODY}" inspect \
  "${TMP_DIR}/mixed-recipients.cms"

python3 - "${TMP_DIR}/candidate.cms" "${TMP_DIR}" <<'PY'
from pathlib import Path
import stat
import sys
import warnings
import zipfile

cms = Path(sys.argv[1]).read_bytes()
root = Path(sys.argv[2])
warnings.simplefilter("ignore", UserWarning)

def info(name: str) -> zipfile.ZipInfo:
    result = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0))
    result.compress_type = zipfile.ZIP_STORED
    result.create_system = 3
    result.external_attr = (stat.S_IFREG | 0o600) << 16
    return result

for kind in ("zero", "extra", "duplicate", "traversal", "absolute"):
    with zipfile.ZipFile(root / f"outer-{kind}.zip", "w") as archive:
        if kind != "zero":
            archive.writestr(info("candidate.cms"), cms)
        if kind == "extra":
            archive.writestr(info("extra.txt"), b"extra")
        elif kind == "duplicate":
            archive.writestr(info("candidate.cms"), cms)
        elif kind == "traversal":
            archive.writestr(info("../candidate.cms"), cms)
        elif kind == "absolute":
            archive.writestr(info("/candidate.cms"), cms)

valid = root / "candidate.zip"
for kind in ("missing", "extra", "duplicate", "traversal", "absolute"):
    if kind == "missing":
        with zipfile.ZipFile(root / "inner-missing.zip", "w") as archive:
            for name in ("candidate.aab", "output-metadata.json", "mapping.txt"):
                archive.writestr(info(name), b"fixture")
        continue
    target = root / f"inner-{kind}.zip"
    target.write_bytes(valid.read_bytes())
    with zipfile.ZipFile(target, "a") as archive:
        if kind == "extra":
            archive.writestr(info("extra.txt"), b"extra")
        elif kind == "duplicate":
            archive.writestr(info("candidate.aab"), b"duplicate")
        elif kind == "traversal":
            archive.writestr(info("../candidate.aab"), b"traversal")
        else:
            archive.writestr(info("/candidate.aab"), b"absolute")
PY

for kind in zero extra duplicate traversal absolute; do
  expect_rejected "outer-${kind}" python3 "${ARCHIVE}" extract-artifact \
    --archive "${TMP_DIR}/outer-${kind}.zip" \
    --output "${TMP_DIR}/outer-${kind}.cms"
done
for kind in missing extra duplicate traversal absolute; do
  expect_rejected "inner-${kind}" python3 "${ARCHIVE}" extract-inner \
    --archive "${TMP_DIR}/inner-${kind}.zip" \
    --output-dir "${TMP_DIR}/inner-${kind}"
done

python3 - "${TMP_DIR}/candidate.cms" "${TMP_DIR}/outer-valid.zip" <<'PY'
from pathlib import Path
import sys
import zipfile

with zipfile.ZipFile(sys.argv[2], "w", zipfile.ZIP_DEFLATED) as archive:
    archive.writestr("candidate.cms", Path(sys.argv[1]).read_bytes())
PY
python3 "${ARCHIVE}" extract-artifact \
  --archive "${TMP_DIR}/outer-valid.zip" \
  --output "${TMP_DIR}/outer-extracted.cms"
cmp "${TMP_DIR}/candidate.cms" "${TMP_DIR}/outer-extracted.cms"

printf '%s\n' \
  'Android internal candidate encrypted-custody controls passed.'
