#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSPECTOR="${REPO_ROOT}/tool/inspect_ios_permission_descriptions.sh"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf -- "${TMP_DIR}"
}
trap cleanup EXIT HUP INT TERM

write_fixture() {
  python3 - "$1" "$2" "$3" <<'PY'
import plistlib
import sys

path, omitted, blank = sys.argv[1:]
keys = (
    "NSMicrophoneUsageDescription",
    "NSCameraUsageDescription",
    "NSPhotoLibraryUsageDescription",
)
values = {key: f"Purpose for {key}" for key in keys if key != omitted}
if blank:
    values[blank] = "   "
with open(path, "wb") as handle:
    plistlib.dump(values, handle)
PY
}

expect_failure() {
  if bash "${INSPECTOR}" "$1" 'negative fixture' >/dev/null 2>&1; then
    printf 'Permission inspector accepted invalid fixture: %s\n' "$2" >&2
    exit 1
  fi
}

complete="${TMP_DIR}/complete.plist"
write_fixture "${complete}" '' ''
bash "${INSPECTOR}" "${complete}" 'positive fixture' >/dev/null

for key in \
  NSMicrophoneUsageDescription \
  NSCameraUsageDescription \
  NSPhotoLibraryUsageDescription; do
  missing="${TMP_DIR}/missing-${key}.plist"
  blank="${TMP_DIR}/blank-${key}.plist"
  write_fixture "${missing}" "${key}" ''
  write_fixture "${blank}" '' "${key}"
  expect_failure "${missing}" "missing ${key}"
  expect_failure "${blank}" "blank ${key}"
done

printf '%s\n' 'iOS permission-description positive and negative contracts passed.'
