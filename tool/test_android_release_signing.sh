#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GRADLEW="${REPO_ROOT}/android/gradlew"
TMP_DIR="$(mktemp -d)"
MISSING_PROPERTIES="${TMP_DIR}/missing-key.properties"
SYNTHETIC_PROPERTIES="${TMP_DIR}/synthetic-key.properties"
SYNTHETIC_KEYSTORE="${TMP_DIR}/synthetic-release.p12"
SYNTHETIC_PASSWORD="contract-only-password"
MISMATCHED_FINGERPRINT="$(printf '0%.0s' {1..64})"
SYNTHETIC_MAPS_KEY="AIza$(printf 'A%.0s' {1..35})"

cleanup() {
  rm -rf -- "${TMP_DIR}"
}
trap cleanup EXIT HUP INT TERM

fail() {
  printf 'Android release signing contract failed: %s\n' "$1" >&2
  exit 1
}

assert_no_release_artifact() {
  local artifact
  artifact="$(
    find "${REPO_ROOT}/build/app/outputs" -type f \
      \( -name '*production-release*.apk' -o \
         -name '*production-release*.aab' -o \
         -path '*/productionRelease/*.apk' -o \
         -path '*/productionRelease/*.aab' \) \
      -print -quit 2>/dev/null || true
  )"
  [[ -z "${artifact}" ]] || fail 'a production APK or AAB exists'
}

expect_gradle_failure() {
  local label="$1"
  local expected_message="$2"
  shift 2
  local log_path="${TMP_DIR}/${label}.log"
  if (cd "${REPO_ROOT}/android" && \
    "${GRADLEW}" "$@" -PMAPS_API_KEY="${SYNTHETIC_MAPS_KEY}" \
      >"${log_path}" 2>&1); then
    fail 'a negative Gradle invocation unexpectedly succeeded'
  fi
  grep -Fq "${expected_message}" "${log_path}" ||
    fail 'a negative Gradle invocation failed outside the signing gate'
  assert_no_release_artifact
}

assert_no_release_artifact
expect_gradle_failure missing-assemble \
  'Production release signing is unavailable.' \
  :app:assembleProductionRelease \
  -Pjeeb.releaseSigningPropertiesFile="${MISSING_PROPERTIES}"
expect_gradle_failure missing-bundle \
  'Production release signing is unavailable.' \
  :app:bundleProductionRelease \
  -Pjeeb.releaseSigningPropertiesFile="${MISSING_PROPERTIES}"

export JEEB_SYNTHETIC_KEYSTORE_PASSWORD="${SYNTHETIC_PASSWORD}"
keytool -genkeypair -noprompt -storetype PKCS12 \
  -keystore "${SYNTHETIC_KEYSTORE}" \
  -storepass:env JEEB_SYNTHETIC_KEYSTORE_PASSWORD \
  -keypass:env JEEB_SYNTHETIC_KEYSTORE_PASSWORD \
  -alias syntheticrelease -keyalg RSA -keysize 2048 -validity 1 \
  -dname 'CN=Contract Test,OU=CI,O=Jeeb,L=Test,ST=Test,C=NL' \
  >/dev/null 2>&1
unset JEEB_SYNTHETIC_KEYSTORE_PASSWORD

printf '%s\n' \
  'keyAlias=syntheticrelease' \
  "keyPassword=${SYNTHETIC_PASSWORD}" \
  "storeFile=${SYNTHETIC_KEYSTORE}" \
  "storePassword=${SYNTHETIC_PASSWORD}" \
  >"${SYNTHETIC_PROPERTIES}"
chmod 0600 "${SYNTHETIC_PROPERTIES}"

expect_gradle_failure missing-fingerprint \
  'Protected production signing certificate fingerprint is missing or malformed.' \
  :app:verifyProductionReleaseSigning \
  -Pjeeb.releaseSigningPropertiesFile="${SYNTHETIC_PROPERTIES}"
expect_gradle_failure mismatched-fingerprint \
  'Production release signing certificate does not match the protected fingerprint.' \
  :app:verifyProductionReleaseSigning \
  -Pjeeb.releaseSigningPropertiesFile="${SYNTHETIC_PROPERTIES}" \
  -Pjeeb.releaseSigningCertificateSha256="${MISMATCHED_FINGERPRINT}"

printf '%s\n' \
  'Android release signing negatives passed; no production APK or AAB exists.'
