#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-${REPO_ROOT}/build/ios/iphonesimulator/Runner.app}"
APP_DELEGATE="${JEEB_IOS_APP_DELEGATE_PATH:-${REPO_ROOT}/ios/Runner/AppDelegate.swift}"
CONTRACT="${REPO_ROOT}/contracts/jeeb-firebase-v1.json"
APPS="${REPO_ROOT}/contracts/jeeb-mobile-firebase-apps-v1.json"

fail() {
  printf 'iOS dev Firebase artifact invalid: %s\n' "$1" >&2
  exit 1
}

command -v jq >/dev/null 2>&1 || fail 'jq is required'
command -v python3 >/dev/null 2>&1 || fail 'python3 is required'
bash "${REPO_ROOT}/tool/validate_jeeb_firebase_contract.sh" >/dev/null

INFO_PLIST="${APP_PATH}/Info.plist"
FIREBASE_PLIST="${APP_PATH}/GoogleService-Info.plist"
[[ -d "${APP_PATH}" ]] || fail 'Runner.app is missing'
[[ -s "${INFO_PLIST}" ]] || fail 'bundled Info.plist is missing'
[[ -s "${FIREBASE_PLIST}" ]] || fail 'bundled GoogleService-Info.plist is missing'
[[ -s "${APP_DELEGATE}" ]] || fail 'AppDelegate source is missing'

EXPECTED_PROJECT_ID="$(jq -er '.projectId' "${CONTRACT}")"
EXPECTED_PROJECT_NUMBER="$(jq -er '.projectNumber' "${CONTRACT}")"
EXPECTED_BUNDLE_ID="$(jq -er '.ios.dev.bundleId' "${APPS}")"
EXPECTED_APP_ID="$(jq -er '.ios.dev.appId' "${APPS}")"

python3 - \
  "${INFO_PLIST}" \
  "${FIREBASE_PLIST}" \
  "${APP_DELEGATE}" \
  "${EXPECTED_PROJECT_ID}" \
  "${EXPECTED_PROJECT_NUMBER}" \
  "${EXPECTED_BUNDLE_ID}" \
  "${EXPECTED_APP_ID}" <<'PY'
import plistlib
import re
import sys
from pathlib import Path

info_path, firebase_path, delegate_path = map(Path, sys.argv[1:4])
project_id, project_number, bundle_id, app_id = sys.argv[4:8]

with info_path.open("rb") as handle:
    info = plistlib.load(handle)
with firebase_path.open("rb") as handle:
    firebase = plistlib.load(handle)

expected = {
    "PROJECT_ID": project_id,
    "GCM_SENDER_ID": project_number,
    "BUNDLE_ID": bundle_id,
    "GOOGLE_APP_ID": app_id,
}
for key, value in expected.items():
    if firebase.get(key) != value:
        raise SystemExit(
            f"iOS dev Firebase artifact invalid: bundled {key} drifted"
        )
if firebase.get("IS_GCM_ENABLED") is not True:
    raise SystemExit("iOS dev Firebase artifact invalid: bundled FCM is disabled")
if info.get("CFBundleIdentifier") != bundle_id:
    raise SystemExit("iOS dev Firebase artifact invalid: built bundle id drifted")

maps_key = info.get("GMSApiKey", "")
if not re.fullmatch(r"AIza[0-9A-Za-z_-]{35}", maps_key):
    raise SystemExit("iOS dev Firebase artifact invalid: Maps key was not resolved")
reversed_client_id = firebase.get("REVERSED_CLIENT_ID", "")
schemes = {
    scheme
    for entry in info.get("CFBundleURLTypes", [])
    for scheme in entry.get("CFBundleURLSchemes", [])
}
if not reversed_client_id or reversed_client_id not in schemes:
    raise SystemExit(
        "iOS dev Firebase artifact invalid: Google Sign-In scheme was not resolved"
    )
if "jeeb-dev" not in schemes:
    raise SystemExit("iOS dev Firebase artifact invalid: dev URL scheme is missing")

source = delegate_path.read_text(encoding="utf-8")
method_start = source.find("didFinishLaunchingWithOptions")
method_end = source.find("return super.application", method_start)
if method_start < 0 or method_end < 0:
    raise SystemExit(
        "iOS dev Firebase artifact invalid: AppDelegate launch method is missing"
    )
method = source[method_start:method_end]
firebase_init = method.find("FirebaseApp.configure()")
maps_init = method.find("GMSServices.provideAPIKey")
dev_branch = method.find("#if JEEB_DEV")
if firebase_init < 0 or maps_init < 0:
    raise SystemExit(
        "iOS dev Firebase artifact invalid: native Firebase/Maps init is missing"
    )
if dev_branch >= 0 and (firebase_init > dev_branch or maps_init > dev_branch):
    raise SystemExit(
        "iOS dev Firebase artifact invalid: native init is conditional on non-dev"
    )
PY

printf '%s\n' \
  'iOS dev artifact bundles the canonical Firebase app and initializes it for dev.'
