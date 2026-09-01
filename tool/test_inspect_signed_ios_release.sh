#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
INFO_PLIST="${TMP_DIR}/Info.plist"
ENTITLEMENTS_PLIST="${TMP_DIR}/entitlements.plist"
PROFILE_PLIST="${TMP_DIR}/profile.plist"
trap 'rm -rf -- "${TMP_DIR}"' EXIT HUP INT TERM

# shellcheck source=tool/inspect_signed_ios_release.sh
source "${REPO_ROOT}/tool/inspect_signed_ios_release.sh"

plutil -create xml1 "${INFO_PLIST}"
/usr/libexec/PlistBuddy -c 'Add :CFBundleShortVersionString string 7.8.9' \
  "${INFO_PLIST}"
/usr/libexec/PlistBuddy -c 'Add :CFBundleVersion string 987654' \
  "${INFO_PLIST}"

validate_ios_versions "${INFO_PLIST}" '7.8.9' '987654'

plutil -create xml1 "${ENTITLEMENTS_PLIST}"
/usr/libexec/PlistBuddy -c \
  'Add :com.apple.developer.applesignin array' "${ENTITLEMENTS_PLIST}"
/usr/libexec/PlistBuddy -c \
  'Add :com.apple.developer.applesignin:0 string Default' \
  "${ENTITLEMENTS_PLIST}"
validate_apple_signin_entitlement "${ENTITLEMENTS_PLIST}" 'test evidence'

plutil -create xml1 "${PROFILE_PLIST}"
/usr/libexec/PlistBuddy -c 'Add :Entitlements dict' "${PROFILE_PLIST}"
/usr/libexec/PlistBuddy -c \
  'Add :Entitlements:com.apple.developer.applesignin array' "${PROFILE_PLIST}"
/usr/libexec/PlistBuddy -c \
  'Add :Entitlements:com.apple.developer.applesignin:0 string Default' \
  "${PROFILE_PLIST}"
validate_apple_signin_entitlement \
  "${PROFILE_PLIST}" 'profile test evidence' \
  ':Entitlements:com.apple.developer.applesignin'

/usr/libexec/PlistBuddy -c \
  'Set :com.apple.developer.applesignin:0 Secondary' "${ENTITLEMENTS_PLIST}"
if validate_apple_signin_entitlement \
  "${ENTITLEMENTS_PLIST}" 'test evidence' >/dev/null 2>&1; then
  printf '%s\n' 'Apple Sign-In inspector accepted a non-Default value.' >&2
  exit 1
fi
/usr/libexec/PlistBuddy -c \
  'Set :com.apple.developer.applesignin:0 Default' "${ENTITLEMENTS_PLIST}"
/usr/libexec/PlistBuddy -c \
  'Add :com.apple.developer.applesignin:1 string Unexpected' \
  "${ENTITLEMENTS_PLIST}"
if validate_apple_signin_entitlement \
  "${ENTITLEMENTS_PLIST}" 'test evidence' >/dev/null 2>&1; then
  printf '%s\n' 'Apple Sign-In inspector accepted an extra value.' >&2
  exit 1
fi

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

inspection_failure="$({
  IOS_BUILD_NAME='7.8.9' IOS_BUILD_NUMBER='987654' \
    bash "${REPO_ROOT}/tool/inspect_signed_ios_release.sh"
} 2>&1 || true)"
grep -Fq 'IPA is missing' <<<"${inspection_failure}"
if grep -Fq 'unbound variable' <<<"${inspection_failure}"; then
  printf '%s\n' 'Signed iOS inspector cleanup referenced expired local state.' >&2
  exit 1
fi

printf '%s\n' 'Signed iOS inspector accepted and enforced nondefault versions.'
