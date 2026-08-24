#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$(mktemp -d)"
CONFIG_PATH="${WORK_DIR}/google-services.json"
trap 'rm -rf -- "${WORK_DIR}"' EXIT HUP INT TERM

cat >"${CONFIG_PATH}" <<'JSON'
{
  "project_info": {
    "project_number": "1051234312170",
    "project_id": "jeeb-5a293",
    "storage_bucket": "jeeb-5a293.appspot.com"
  },
  "client": [{
    "client_info": {
      "mobilesdk_app_id": "1:1051234312170:android:0123456789abcdef",
      "android_client_info": {"package_name": "com.olivium.jeeb"}
    },
    "oauth_client": [{
      "client_id": "1051234312170-synthetic.apps.googleusercontent.com",
      "client_type": 1,
      "android_info": {
        "package_name": "com.olivium.jeeb",
        "certificate_hash": "77485A6B9FAA39A7F7A3A2A7E7F8070CB44F430D"
      }
    }],
    "api_key": [{"current_key": "x"}],
    "services": {}
  }],
  "configuration_version": "1"
}
JSON
SYNTHETIC_FIREBASE_KEY='AIza'
SYNTHETIC_FIREBASE_KEY+='01234567890123456789012345678901234'
jq --arg key "${SYNTHETIC_FIREBASE_KEY}" \
  '.client[0].api_key[0].current_key = $key' \
  "${CONFIG_PATH}" >"${CONFIG_PATH}.next"
mv "${CONFIG_PATH}.next" "${CONFIG_PATH}"
chmod 0600 "${CONFIG_PATH}"

export ANDROID_FIREBASE_EXPECTED_APP_ID='1:1051234312170:android:0123456789abcdef'
export ANDROID_FIREBASE_EXPECTED_SHA1='77:48:5A:6B:9F:AA:39:A7:F7:A3:A2:A7:E7:F8:07:0C:B4:4F:43:0D'
bash "${REPO_ROOT}/tool/validate_android_google_services.sh" "${CONFIG_PATH}"

wrong_path="${WORK_DIR}/wrong.json"
jq '.client[0].client_info.android_client_info.package_name = "wrong.example"' \
  "${CONFIG_PATH}" >"${wrong_path}"
chmod 0600 "${wrong_path}"
if bash "${REPO_ROOT}/tool/validate_android_google_services.sh" "${wrong_path}" \
  >/dev/null 2>&1; then
  printf '%s\n' 'validator accepted the wrong package identity' >&2
  exit 1
fi

printf '%s\n' 'Android Firebase injection contracts passed.'
