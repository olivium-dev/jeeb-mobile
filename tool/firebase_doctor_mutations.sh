#!/usr/bin/env bash
# Proves every OUTCOME guard in tool/firebase_doctor.sh actually turns red.
# Each case mutates one value in a scratch copy of the repo, asserts the doctor
# fails with the expected message, and restores. Run: bash tool/firebase_doctor_mutations.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

command -v jq >/dev/null 2>&1 || { echo "jq is required"; exit 1; }

CONTRACT="contracts/jeeb-firebase-v1.json"
DEV_GSJ="android/app/src/dev/google-services.json"
SEAM="lib/core/firebase/jeeb_firestore.dart"
FIREBASERC=".firebaserc"

PASSES=0
FAILURES=0
RESTORE=()

restore_all() {
  for entry in ${RESTORE[@]+"${RESTORE[@]}"}; do
    local path="${entry%%|*}" backup="${entry#*|}"
    if [ "$backup" = "ABSENT" ]; then rm -f "$path"; else mv -f "$backup" "$path"; fi
  done
  RESTORE=()
}
trap restore_all EXIT

stash() {
  local path="$1"
  if [ -e "$path" ]; then
    local backup; backup="$(mktemp)"
    cp "$path" "$backup"
    RESTORE+=("$path|$backup")
  else
    RESTORE+=("$path|ABSENT")
  fi
}

# Runs the doctor and asserts it FAILS carrying $2.
expect_fail() {
  local label="$1" needle="$2" out rc
  set +e
  out="$(bash tool/firebase_doctor.sh 2>&1)"; rc=$?
  set -e
  if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -Fq "$needle"; then
    printf 'MUTATION PROVEN: %s\n' "$label"
    PASSES=$((PASSES + 1))
  else
    printf 'MUTATION NOT CAUGHT: %s (exit %d, expected message %s)\n' \
      "$label" "$rc" "$needle" >&2
    FAILURES=$((FAILURES + 1))
  fi
  restore_all
}

# Baseline: the unmutated tree must be green, or nothing below means anything.
if ! bash tool/firebase_doctor.sh >/dev/null 2>&1; then
  echo "BASELINE IS RED — fix the doctor before proving mutations" >&2
  bash tool/firebase_doctor.sh || true
  exit 1
fi
echo "BASELINE: doctor is green"

# A dev config whose identity is not the contract's.
write_dev_config() {
  local project_id="$1" project_number="$2" package="$3"
  mkdir -p "$(dirname "$DEV_GSJ")"
  cat > "$DEV_GSJ" <<JSON
{
  "project_info": {
    "project_number": "$project_number",
    "project_id": "$project_id",
    "storage_bucket": "$project_id.appspot.com"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:$project_number:android:abcdef0123456789",
        "android_client_info": { "package_name": "$package" }
      },
      "oauth_client": [],
      "api_key": [ { "current_key": "AIzaAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" } ],
      "services": {}
    }
  ],
  "configuration_version": "1"
}
JSON
}

stash "$DEV_GSJ"
write_dev_config "alrahmah-d7a33" "1051234312170" "app.jeeb.mobile.dev"
expect_fail "wrong project_id in a config on disk" \
  "project_id is 'alrahmah-d7a33'"

stash "$DEV_GSJ"
write_dev_config "jeeb-5a293" "999999999999" "app.jeeb.mobile.dev"
expect_fail "wrong project_number in a config on disk" \
  "project_number is '999999999999'"

stash "$DEV_GSJ"
write_dev_config "jeeb-5a293" "1051234312170" "com.example.other"
expect_fail "foreign package_name in a config on disk" \
  "unknown package_name 'com.example.other'"

stash "$DEV_GSJ"
write_dev_config "jeeb-5a293" "1051234312170" "com.olivium.jeeb"
expect_fail "dev config with no app.jeeb.mobile.dev client" \
  "has no client for 'app.jeeb.mobile.dev'"

stash "$CONTRACT"
jq '.firestoreDatabaseId = "jeeb-staging-chat"' "$CONTRACT" > "$CONTRACT.tmp"
mv "$CONTRACT.tmp" "$CONTRACT"
expect_fail "Firestore database id drifts from the contract" \
  "but contracts/jeeb-firebase-v1.json pins 'jeeb-staging-chat'"

stash "$CONTRACT"
jq '.projectId = "jeeb-staging"' "$CONTRACT" > "$CONTRACT.tmp"
mv "$CONTRACT.tmp" "$CONTRACT"
expect_fail ".firebaserc no longer matches the contracted project" \
  "expected exactly 'jeeb-staging'"

stash "$CONTRACT"
rm -f "$CONTRACT"
expect_fail "the contract file goes missing" \
  "contracts/jeeb-firebase-v1.json is missing"

stash "$SEAM"
sed -i.bak "s/defaultValue: '(default)'/defaultValue: 'chat-staging'/" "$SEAM"
rm -f "$SEAM.bak"
expect_fail "the Firestore seam default drifts off the contract" \
  "defaults to 'chat-staging'"

stash "$SEAM"
rm -f "$SEAM"
expect_fail "the Firestore seam is deleted" \
  "lib/core/firebase/jeeb_firestore.dart is missing"

stash lib/core/diagnostics/chat_diagnostics.dart
printf '\n// FirebaseFirestore.instance bypass\nvoid _x() { FirebaseFirestore.instance; }\n' \
  >> lib/core/diagnostics/chat_diagnostics.dart
expect_fail "a call site bypasses the Firestore seam" \
  "bypass lib/core/firebase/jeeb_firestore.dart"

stash "$FIREBASERC"
printf '{"projects":{"default":"alrahmah-d7a33"}}\n' > "$FIREBASERC"
expect_fail "the Firebase CLI project pin is retargeted" \
  "default project is 'alrahmah-d7a33'"

stash pubspec.lock
python3 - <<'PY'
import re
lines = open('pubspec.lock').read().split('\n')
for i, line in enumerate(lines):
    if line == '  firebase_core:':
        for j in range(i, i + 12):
            if lines[j].startswith('    version:'):
                lines[j] = '    version: "3.15.0"'
                break
        break
open('pubspec.lock', 'w').write('\n'.join(lines))
PY
expect_fail "firebase_core drifts into the pigeon-poison range" \
  "outside the required [3.13.1, 3.15.0) envelope"

# CI-only regime check: a config on disk must fail under CI and only warn locally.
stash "$DEV_GSJ"
write_dev_config "jeeb-5a293" "1051234312170" "app.jeeb.mobile.dev"
if bash tool/firebase_doctor.sh >/dev/null 2>&1; then
  echo "MUTATION PROVEN: a valid config on disk is a local WARN, not a FAIL"
  PASSES=$((PASSES + 1))
else
  echo "MUTATION NOT CAUGHT: a valid config on disk must not fail locally" >&2
  FAILURES=$((FAILURES + 1))
fi
set +e
ci_out="$(CI=true bash tool/firebase_doctor.sh 2>&1)"
set -e
restore_all
ci_caught=1
printf '%s' "$ci_out" \
  | grep -Fq "exists outside an active protected wrapper invocation" && ci_caught=0
if [ "$ci_caught" -eq 0 ]; then
  echo "MUTATION PROVEN: the same config on disk FAILS under CI=true"
  PASSES=$((PASSES + 1))
else
  echo "MUTATION NOT CAUGHT: CI=true must still fail on a config left on disk" >&2
  FAILURES=$((FAILURES + 1))
fi

printf '\n%d proven, %d not caught\n' "$PASSES" "$FAILURES"
[ "$FAILURES" -eq 0 ] || exit 1
echo "FIREBASE DOCTOR MUTATIONS: PASS"
