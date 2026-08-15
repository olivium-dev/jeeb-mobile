#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT
mkdir -p "${TMP_DIR}/bin"

cat >"${TMP_DIR}/bin/curl" <<'SH'
#!/usr/bin/env bash
echo "  /health -> HTTP 200"
SH

cat >"${TMP_DIR}/bin/flutter" <<'SH'
#!/usr/bin/env bash
touch "${FCM_TEST_TMP}/flutter-called"
exit 0
SH

chmod 700 "${TMP_DIR}/bin/curl" "${TMP_DIR}/bin/flutter"

set +e
OUTPUT="$({
  cd "${REPO_ROOT}"
  PATH="${TMP_DIR}/bin:${PATH}" FCM_TEST_TMP="${TMP_DIR}" \
    bash tool/run_msi_dual.sh
} 2>&1)"
STATUS=$?
set -e

if [[ ${STATUS} -eq 0 ]]; then
  echo "not ok - MSI launcher accepted a missing/invalid dev Firebase config" >&2
  exit 1
fi

if [[ -f "${TMP_DIR}/flutter-called" ]]; then
  echo "not ok - MSI launcher reached flutter build before rejecting dev Firebase config" >&2
  exit 1
fi

if [[ "${OUTPUT}" != *"Dev Firebase config preflight failed"* ]]; then
  echo "not ok - MSI launcher failure did not identify the redacted Firebase preflight" >&2
  exit 1
fi

echo "ok - MSI launcher rejects invalid dev Firebase config before build"
