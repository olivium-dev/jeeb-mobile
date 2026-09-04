#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf 'Protected iOS dev Firebase injection failed: %s\n' "$1" >&2
  exit 1
}

[[ $# -gt 0 ]] || fail 'a build or validation command is required'
[[ -n "${IOS_DEV_GOOGLE_SERVICE_INFO_PLIST_B64:-}" ]] ||
  fail 'protected dev plist input is missing'
[[ -n "${IOS_DEV_FIREBASE_EXPECTED_CLIENT_ID:-}" ]] ||
  fail 'protected dev Google Sign-In client identity is missing'
[[ -n "${IOS_DEV_FIREBASE_EXPECTED_REVERSED_CLIENT_ID:-}" ]] ||
  fail 'protected dev reversed Google Sign-In client identity is missing'

export IOS_FIREBASE_VARIANT=dev
export IOS_GOOGLE_SERVICE_INFO_PLIST_B64="${IOS_DEV_GOOGLE_SERVICE_INFO_PLIST_B64}"
export IOS_FIREBASE_EXPECTED_CLIENT_ID="${IOS_DEV_FIREBASE_EXPECTED_CLIENT_ID}"
export IOS_FIREBASE_EXPECTED_REVERSED_CLIENT_ID="${IOS_DEV_FIREBASE_EXPECTED_REVERSED_CLIENT_ID}"
unset IOS_DEV_GOOGLE_SERVICE_INFO_PLIST_B64
unset IOS_DEV_FIREBASE_EXPECTED_CLIENT_ID
unset IOS_DEV_FIREBASE_EXPECTED_REVERSED_CLIENT_ID

exec bash "${REPO_ROOT}/tool/run_with_ios_firebase_config.sh" "$@"
