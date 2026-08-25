#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
INFO_PLIST="${TMP_DIR}/Info.plist"
trap 'rm -rf -- "${TMP_DIR}"' EXIT HUP INT TERM

# shellcheck source=tool/inspect_signed_ios_release.sh
source "${REPO_ROOT}/tool/inspect_signed_ios_release.sh"

plutil -create xml1 "${INFO_PLIST}"
/usr/libexec/PlistBuddy -c 'Add :CFBundleShortVersionString string 7.8.9' \
  "${INFO_PLIST}"
/usr/libexec/PlistBuddy -c 'Add :CFBundleVersion string 987654' \
  "${INFO_PLIST}"

validate_ios_versions "${INFO_PLIST}" '7.8.9' '987654'

if validate_ios_versions "${INFO_PLIST}" '7.8.8' '987654' \
  >/dev/null 2>&1; then
  printf '%s\n' 'Version inspector accepted a mismatched nondefault build name.' >&2
  exit 1
fi
if validate_ios_versions "${INFO_PLIST}" '7.8.9' '987653' \
  >/dev/null 2>&1; then
  printf '%s\n' 'Version inspector accepted a mismatched nondefault build number.' >&2
  exit 1
fi
if validate_ios_versions "${INFO_PLIST}" '' '987654' >/dev/null 2>&1; then
  printf '%s\n' 'Version inspector accepted a missing build name.' >&2
  exit 1
fi
for invalid_build_name in '1.4' '1.4.0.1' 'release'; do
  if validate_ios_versions "${INFO_PLIST}" \
    "${invalid_build_name}" '987654' >/dev/null 2>&1; then
    printf 'Version inspector accepted malformed build name: %s\n' \
      "${invalid_build_name}" >&2
    exit 1
  fi
done
if validate_ios_versions "${INFO_PLIST}" '7.8.9' '' >/dev/null 2>&1; then
  printf '%s\n' 'Version inspector accepted a missing build number.' >&2
  exit 1
fi

printf '%s\n' 'Signed iOS inspector accepted and enforced nondefault versions.'
