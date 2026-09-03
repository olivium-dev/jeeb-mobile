#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTRACT="${JEEB_FIREBASE_CONTRACT_PATH:-${REPO_ROOT}/contracts/jeeb-firebase-v1.json}"
APPS="${JEEB_FIREBASE_APPS_PATH:-${REPO_ROOT}/contracts/jeeb-mobile-firebase-apps-v1.json}"
EXPECTED_CONTRACT_SHA256='932aa075ff64a3fd3206a25c2ab166513c2aeea391100f07ccfd6063345063c8'

fail() {
  printf 'Jeeb Firebase contract invalid: %s\n' "$1" >&2
  exit 1
}

has_rg=false
if command -v rg >/dev/null 2>&1; then
  has_rg=true
else
  command -v grep >/dev/null 2>&1 || fail 'rg or grep is required'
fi

search_quiet() {
  local pattern="$1"
  shift

  if [[ "${has_rg}" == true ]]; then
    rg -q -- "${pattern}" "$@"
  else
    grep -E -R -q -- "${pattern}" "$@"
  fi
}

command -v jq >/dev/null 2>&1 || fail 'jq is required'
command -v shasum >/dev/null 2>&1 || fail 'shasum is required'
[[ -s "${CONTRACT}" ]] || fail 'contracts/jeeb-firebase-v1.json is missing'
[[ -s "${APPS}" ]] || fail 'mobile app registration contract is missing'

actual_contract_sha256="$(shasum -a 256 "${CONTRACT}" | awk '{print $1}')"
[[ "${actual_contract_sha256}" == "${EXPECTED_CONTRACT_SHA256}" ]] ||
  fail 'canonical contract bytes or SHA-256 drifted'

jq -e '
  keys == [
    "chatEnabled",
    "firestoreDatabaseId",
    "projectId",
    "projectNumber",
    "pushProducer",
    "schemaVersion"
  ]
  and .schemaVersion == 1
  and .projectId == "jeeb-5a293"
  and .projectNumber == "1051234312170"
  and .firestoreDatabaseId == "(default)"
  and .chatEnabled == true
  and .pushProducer == "notification-service"
' "${CONTRACT}" >/dev/null || fail 'canonical project/database/push values drifted'

jq -e '
  keys == ["android", "contract", "environments", "ios", "schemaVersion"]
  and .schemaVersion == 1
  and .contract == "jeeb-firebase-v1"
  and (.android | keys == ["dev", "store"])
  and (.ios | keys == ["dev", "store"])
  and .android.dev == {
    packageName: "app.jeeb.mobile.dev",
    appId: "1:1051234312170:android:146d7f24f109e38523dc93"
  }
  and .android.store == {
    packageName: "com.olivium.jeeb",
    appId: "1:1051234312170:android:85bc801430c9006623dc93"
  }
  and .ios.dev == {
    bundleId: "app.jeeb.jeebMobile.dev",
    appId: "1:1051234312170:ios:30f909a175df7f5b23dc93"
  }
  and .ios.store == {
    bundleId: "com.olivium.jeeb",
    appId: "1:1051234312170:ios:1036d2eaaf63036a23dc93"
  }
  and .environments == {
    dev: {
      androidApp: "dev",
      iosApp: "dev",
      firestoreDatabaseId: "(default)"
    },
    staging: {
      androidApp: "store",
      iosApp: "store",
      firestoreDatabaseId: "(default)"
    },
    production: {
      androidApp: "store",
      iosApp: "store",
      firestoreDatabaseId: "(default)"
    }
  }
' "${APPS}" >/dev/null || fail 'mobile Firebase app/environment identities drifted'

jq -e '.projects.default == "jeeb-5a293"' \
  "${REPO_ROOT}/.firebaserc" >/dev/null || fail '.firebaserc default project drifted'

search_quiet 'applicationId "app\.jeeb\.mobile\.dev"' \
  "${REPO_ROOT}/android/app/build.gradle" || fail 'Android dev package drifted'
search_quiet 'applicationId "com\.olivium\.jeeb"' \
  "${REPO_ROOT}/android/app/build.gradle" || fail 'Android store package drifted'
search_quiet 'PRODUCT_BUNDLE_IDENTIFIER = app\.jeeb\.jeebMobile\.dev;' \
  "${REPO_ROOT}/ios/Runner.xcodeproj/project.pbxproj" || fail 'iOS dev bundle drifted'
search_quiet 'PRODUCT_BUNDLE_IDENTIFIER = com\.olivium\.jeeb;' \
  "${REPO_ROOT}/ios/Runner.xcodeproj/project.pbxproj" || fail 'iOS store bundle drifted'

if search_quiet 'EXCLUDED_SOURCE_FILE_NAMES = "GoogleService-Info\.plist"' \
  "${REPO_ROOT}/ios/Runner.xcodeproj/project.pbxproj"; then
  fail 'an iOS build configuration excludes Firebase'
fi

if search_quiet 'FirebaseFirestore\.instanceFor|databaseId[[:space:]]*:' \
  "${REPO_ROOT}/lib"; then
  fail 'mobile code selects a named Firestore database'
fi

if search_quiet 'DEV_FIREBASE_EXPECTED_PROJECT_(ID|NUMBER)|FIREBASE_EXPECTED_APP_ID' \
  "${REPO_ROOT}/.github/workflows" \
  "${REPO_ROOT}/tool/run_with_android_firebase_config.sh" \
  "${REPO_ROOT}/tool/run_with_dev_firebase_config.sh" \
  "${REPO_ROOT}/tool/run_with_ios_firebase_config.sh" \
  "${REPO_ROOT}/tool/validate_android_google_services.sh" \
  "${REPO_ROOT}/tool/validate_dev_google_services.sh"; then
  fail 'expected Firebase project/app identity is secret-controlled instead of contract-controlled'
fi

printf '%s\n' 'Jeeb mobile Firebase contract is canonical for dev, staging, and production.'
