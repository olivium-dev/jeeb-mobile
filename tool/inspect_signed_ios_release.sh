#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf 'Signed iOS release inspection failed: %s\n' "$1" >&2
  return 1
}

validate_ios_versions() {
  local info_path="$1"
  local expected_build_name="$2"
  local expected_build_number="$3"
  local bundle_version
  local short_version

  [[ -s "${info_path}" ]] || {
    fail 'compiled Info.plist is missing'
    return 1
  }
  [[ "${expected_build_name}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    fail 'IOS_BUILD_NAME is missing or malformed'
    return 1
  }
  [[ "${expected_build_number}" =~ ^[1-9][0-9]{0,17}$ ]] || {
    fail 'IOS_BUILD_NUMBER is missing or malformed'
    return 1
  }

  bundle_version="$(/usr/libexec/PlistBuddy -c \
    'Print :CFBundleVersion' "${info_path}")"
  short_version="$(/usr/libexec/PlistBuddy -c \
    'Print :CFBundleShortVersionString' "${info_path}")"
  [[ "${bundle_version}" == "${expected_build_number}" ]] || {
    fail 'build number drifted'
    return 1
  }
  [[ "${short_version}" == "${expected_build_name}" ]] || {
    fail 'build name drifted'
    return 1
  }
}

main() {
  local ipa_path="${1:-}"
  local firebase_config="${2:-}"
  local maps_key_file="${3:-}"
  local expected_gateway_url="${4:-}"
  local expected_build_name="${IOS_BUILD_NAME:-}"
  local expected_build_number="${IOS_BUILD_NUMBER:-}"
  local tmp_dir
  local app_path
  local signed_entitlements
  local application_identifier
  local aps_environment
  local embedded_profile
  local profile_plist
  local profile_app_identifier
  local info_path

  umask 077
  tmp_dir="$(mktemp -d)"
  cleanup() {
    rm -rf -- "${tmp_dir}"
  }
  trap cleanup EXIT HUP INT TERM

  [[ -s "${ipa_path}" ]] || fail 'IPA is missing'
  [[ -s "${firebase_config}" ]] || fail 'Firebase evidence is missing'
  [[ -s "${maps_key_file}" ]] || fail 'Maps evidence is missing'
  [[ -n "${expected_gateway_url}" ]] || fail 'expected gateway URL is missing'
  [[ -n "${expected_build_name}" ]] || fail 'IOS_BUILD_NAME must be explicit'
  [[ -n "${expected_build_number}" ]] || fail 'IOS_BUILD_NUMBER must be explicit'

  ditto -x -k "${ipa_path}" "${tmp_dir}"
  app_path="$(find "${tmp_dir}/Payload" -maxdepth 1 -type d \
    -name '*.app' -print -quit)"
  [[ -n "${app_path}" ]] || fail 'IPA payload app is missing'

  codesign --verify --deep --strict "${app_path}" >/dev/null 2>&1 ||
    fail 'code signature verification failed'

  signed_entitlements="${tmp_dir}/signed-entitlements.plist"
  codesign -d --entitlements :- "${app_path}" \
    >"${signed_entitlements}" 2>/dev/null
  [[ -s "${signed_entitlements}" ]] || fail 'signed entitlements are missing'

  application_identifier="$(/usr/libexec/PlistBuddy -c \
    'Print :application-identifier' "${signed_entitlements}")"
  aps_environment="$(/usr/libexec/PlistBuddy -c \
    'Print :aps-environment' "${signed_entitlements}")"
  [[ "${application_identifier}" == K5RDQ8J7AN.com.olivium.jeeb ]] ||
    fail 'signed application identifier drifted'
  [[ "${aps_environment}" == production ]] ||
    fail 'signed APNs environment is not production'
  /usr/libexec/PlistBuddy -c \
    'Print :com.apple.developer.associated-domains' \
    "${signed_entitlements}" 2>/dev/null |
    grep -Fq 'applinks:app.jeeb.fds-1.com' ||
    fail 'signed associated domain is missing'

  embedded_profile="${app_path}/embedded.mobileprovision"
  [[ -s "${embedded_profile}" ]] ||
    fail 'embedded provisioning profile is missing'
  profile_plist="${tmp_dir}/profile.plist"
  security cms -D -i "${embedded_profile}" >"${profile_plist}" 2>/dev/null
  profile_app_identifier="$(/usr/libexec/PlistBuddy -c \
    'Print :Entitlements:application-identifier' "${profile_plist}")"
  [[ "${profile_app_identifier}" == K5RDQ8J7AN.com.olivium.jeeb ]] ||
    fail 'provisioning profile application identifier drifted'

  bash "${REPO_ROOT}/tool/inspect_unsigned_ios_release.sh" \
    "${app_path}" "${firebase_config}" "${maps_key_file}" \
    "${expected_gateway_url}" >/dev/null

  info_path="${app_path}/Info.plist"
  validate_ios_versions \
    "${info_path}" "${expected_build_name}" "${expected_build_number}"

  printf '%s\n' \
    'Signed iOS identity, entitlements, versions, Firebase, Maps, and endpoint contracts passed.'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
