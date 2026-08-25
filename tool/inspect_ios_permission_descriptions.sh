#!/usr/bin/env bash

set -euo pipefail

PLIST_PATH="${1:-}"
ARTIFACT_LABEL="${2:-iOS artifact}"

fail() {
  printf '%s permission inspection failed: %s\n' "${ARTIFACT_LABEL}" "$1" >&2
  exit 1
}

[[ -n "${PLIST_PATH}" && -s "${PLIST_PATH}" ]] || fail 'Info.plist is missing'

python3 - "${PLIST_PATH}" "${ARTIFACT_LABEL}" <<'PY'
import plistlib
import sys

path, label = sys.argv[1:]
required_keys = (
    "NSMicrophoneUsageDescription",
    "NSCameraUsageDescription",
    "NSPhotoLibraryUsageDescription",
)

try:
    with open(path, "rb") as handle:
        plist = plistlib.load(handle)
except (OSError, plistlib.InvalidFileException) as error:
    raise SystemExit(f"{label} permission inspection failed: invalid Info.plist: {error}")

for key in required_keys:
    value = plist.get(key)
    if not isinstance(value, str) or not value.strip():
        raise SystemExit(
            f"{label} permission inspection failed: {key} is missing or blank"
        )

print(f"{label} permission descriptions passed.")
PY
