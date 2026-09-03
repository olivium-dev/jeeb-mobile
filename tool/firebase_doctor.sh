#!/usr/bin/env bash
# Static (offline) validator for the whole Firebase chain — see
# docs/firebase-invariants.md. Requires `jq`. Run: bash tool/firebase_doctor.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# ─── Dependency envelope (edit ONLY this table; see docs/firebase-invariants.md §3) ───
# package             | kind   | lower(>=)  | upper(<)  | exact
ENVELOPE_TABLE='
firebase_core         range    3.13.1       3.15.0      -
firebase_auth         exact    -            -           5.6.0
firebase_messaging    major    15.0.0       16.0.0      -
cloud_firestore       major    5.0.0        6.0.0       -
'

MAIN_GSJ="android/app/google-services.json"
DEV_GSJ="android/app/src/dev/google-services.json"
IOS_PLIST="ios/Runner/GoogleService-Info.plist"
CONTRACT="contracts/jeeb-firebase-v1.json"
MANIFEST="android/app/src/main/AndroidManifest.xml"
LOCK="pubspec.lock"
FIRESTORE_SEAM="lib/core/firebase/jeeb_firestore.dart"

# Native identities this repo is allowed to ship. `com.olivium.jeeb` is the
# canonical store id; `app.jeeb.mobile[.dev]` are the local build flavors.
ALLOWED_PACKAGES="com.olivium.jeeb app.jeeb.mobile app.jeeb.mobile.dev"

# CI is the only place the transient-injection regime can be asserted: a local
# checkout legitimately holds a config while `flutter build` runs.
IS_CI=no
if [ "${CI:-}" = "true" ] || [ -n "${GITHUB_ACTIONS:-}" ]; then IS_CI=yes; fi

FAILS=0
WARNS=0

# jq is NOT preinstalled on macOS; without it every identity check below would
# emit a wall of misleading empty-value FAILs instead of one actionable line.
HAVE_JQ=yes
command -v jq >/dev/null 2>&1 || HAVE_JQ=no

pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; FAILS=$((FAILS + 1)); }
warn() { printf 'WARN: %s\n' "$1" >&2; WARNS=$((WARNS + 1)); }
section() { printf '\n== %s ==\n' "$1"; }

# ---- small semver compare: prints -1/0/1 for $1 vs $2, dash-suffix-safe ----
semver_cmp() {
  local a="${1%%-*}" b="${2%%-*}"
  a="${a%%+*}"; b="${b%%+*}"
  local amaj amin apat bmaj bmin bpat
  IFS='.' read -r amaj amin apat <<EOF
$a
EOF
  IFS='.' read -r bmaj bmin bpat <<EOF
$b
EOF
  amaj="${amaj:-0}"; amin="${amin:-0}"; apat="${apat:-0}"
  bmaj="${bmaj:-0}"; bmin="${bmin:-0}"; bpat="${bpat:-0}"
  if [ "$amaj" -ne "$bmaj" ]; then [ "$amaj" -gt "$bmaj" ] && echo 1 || echo -1; return; fi
  if [ "$amin" -ne "$bmin" ]; then [ "$amin" -gt "$bmin" ] && echo 1 || echo -1; return; fi
  if [ "$apat" -ne "$bpat" ]; then [ "$apat" -gt "$bpat" ] && echo 1 || echo -1; return; fi
  echo 0
}

# ---- resolved version of a top-level pubspec.lock package -----------------
lock_version() {
  local pkg="$1"
  awk -v pkg="$pkg" '
    $0 == "  " pkg ":" { inblock = 1; next }
    inblock && /^  [A-Za-z0-9_]+:$/ { inblock = 0 }
    inblock && /^[[:space:]]*version:[[:space:]]*/ {
      gsub(/^[[:space:]]*version:[[:space:]]*"?|"?[[:space:]]*$/, "")
      print; exit
    }
  ' "$LOCK"
}

# =============================================================================
section "0. jq preflight"
# =============================================================================

if [ "$HAVE_JQ" = "no" ]; then
  fail "jq is not installed — the google-services.json identity/client checks CANNOT run. Install it (macOS: 'brew install jq', Debian/Ubuntu: 'apt-get install -y jq') and re-run."
else
  pass "jq is available"
fi

# =============================================================================
section "1. native Firebase configs — protected injection boundary"
# =============================================================================

check_protected_config() {
  local f="$1"
  if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
    fail "$f is tracked; native provider config must be injected at build time"
  else
    pass "$f is untracked"
  fi

  # --no-index is mandatory: it also evaluates an accidentally tracked path.
  if git check-ignore -q --no-index "$f" 2>/dev/null; then
    pass "$f is protected by .gitignore"
  else
    fail "$f is not ignored; a transient protected injection could be committed"
  fi

  # Regime check, NOT an outcome check: the only tree in which this FAILs is a
  # tree that can build an APK, so locally it warns and CI alone enforces it.
  if [ -e "$f" ]; then
    if [ "$IS_CI" = "yes" ]; then
      fail "$f is on disk in CI; it must exist only for the duration of a tool/run_with_*_firebase_config.sh command, so a wrapper's cleanup did not run"
    else
      warn "$f is on disk; inject it only through tool/run_with_*_firebase_config.sh (CI fails on this, a local build needs the file)"
    fi
  else
    pass "$f is absent after wrapper cleanup"
  fi
}

# =============================================================================
section "1a. cross-repo Firebase contract"
# =============================================================================

CONTRACT_PROJECT_ID=""
CONTRACT_PROJECT_NUMBER=""
CONTRACT_DATABASE_ID=""

if [ ! -f "$CONTRACT" ]; then
  fail "$CONTRACT is missing — the machine-readable Firebase identity every repo pins"
elif [ "$HAVE_JQ" = "yes" ]; then
  CONTRACT_PROJECT_ID="$(jq -r '.projectId // empty' "$CONTRACT" 2>/dev/null || echo '')"
  CONTRACT_PROJECT_NUMBER="$(jq -r '.projectNumber // empty' "$CONTRACT" 2>/dev/null || echo '')"
  CONTRACT_DATABASE_ID="$(jq -r '.firestoreDatabaseId // empty' "$CONTRACT" 2>/dev/null || echo '')"
  if [ -z "$CONTRACT_PROJECT_ID" ] || [ -z "$CONTRACT_PROJECT_NUMBER" ] || [ -z "$CONTRACT_DATABASE_ID" ]; then
    fail "$CONTRACT does not declare projectId, projectNumber and firestoreDatabaseId"
  else
    pass "$CONTRACT declares $CONTRACT_PROJECT_ID / $CONTRACT_PROJECT_NUMBER / $CONTRACT_DATABASE_ID"
  fi
fi

EXPECTED_PROJECT_ID="${CONTRACT_PROJECT_ID:-jeeb-5a293}"

# ---- OUTCOME check: whatever config is on disk must BE the contract ----------
check_config_identity() {
  local f="$1" required_package="$2"
  [ -e "$f" ] || return 0
  if [ "$HAVE_JQ" = "no" ] || [ -z "$CONTRACT_PROJECT_ID" ]; then return 0; fi

  local pid pnum
  pid="$(jq -r '.project_info.project_id // empty' "$f" 2>/dev/null || echo '')"
  pnum="$(jq -r '.project_info.project_number // empty' "$f" 2>/dev/null || echo '')"

  if [ "$pid" = "$CONTRACT_PROJECT_ID" ]; then
    pass "$f project_id is $CONTRACT_PROJECT_ID"
  else
    fail "$f project_id is '$pid', but $CONTRACT pins '$CONTRACT_PROJECT_ID'"
  fi

  if [ "$pnum" = "$CONTRACT_PROJECT_NUMBER" ]; then
    pass "$f project_number is $CONTRACT_PROJECT_NUMBER"
  else
    fail "$f project_number is '$pnum', but $CONTRACT pins '$CONTRACT_PROJECT_NUMBER'"
  fi

  local packages pkg
  packages="$(jq -r '.client[]?.client_info.android_client_info.package_name // empty' "$f" 2>/dev/null || echo '')"
  if [ -z "$packages" ]; then
    fail "$f declares no android client package_name"
    return 0
  fi
  while IFS= read -r pkg; do
    [ -n "$pkg" ] || continue
    case " $ALLOWED_PACKAGES " in
      *" $pkg "*) ;;
      *) fail "$f carries an unknown package_name '$pkg' (allowed: $ALLOWED_PACKAGES)" ;;
    esac
  done <<EOF
$packages
EOF
  if printf '%s\n' "$packages" | grep -qx "$required_package"; then
    pass "$f carries the $required_package client"
  else
    fail "$f has no client for '$required_package' — the Google Services plugin would pick another app"
  fi
}

check_ios_identity() {
  [ -e "$IOS_PLIST" ] || return 0
  [ -n "$CONTRACT_PROJECT_ID" ] || return 0
  local raw
  raw="$(tr -d ' \t' < "$IOS_PLIST")"
  if printf '%s' "$raw" | grep -q "<string>${CONTRACT_PROJECT_ID}</string>"; then
    pass "$IOS_PLIST names $CONTRACT_PROJECT_ID"
  else
    fail "$IOS_PLIST does not name the contract project '$CONTRACT_PROJECT_ID'"
  fi
  if printf '%s' "$raw" | grep -q "<string>${CONTRACT_PROJECT_NUMBER}</string>"; then
    pass "$IOS_PLIST names GCM sender $CONTRACT_PROJECT_NUMBER"
  else
    fail "$IOS_PLIST does not name the contract project number '$CONTRACT_PROJECT_NUMBER'"
  fi
}

# Any config on disk that names the forbidden tenant is an outage, not a warning.
check_no_foreign_tenant() {
  local f="$1"
  [ -e "$f" ] || return 0
  if grep -qi 'alrahmah' "$f"; then
    fail "$f references alrahmah — a cross-tenant Firebase config must never reach a Jeeb build"
  else
    pass "$f is free of alrahmah references"
  fi
}

check_protected_config "$MAIN_GSJ"
check_protected_config "$DEV_GSJ"
check_protected_config "$IOS_PLIST"

# Whatever is on disk, whichever flavor, must BE the contracted project.
check_config_identity "$MAIN_GSJ" "com.olivium.jeeb"
check_config_identity "$DEV_GSJ" "app.jeeb.mobile.dev"
check_ios_identity
for tenant_scoped in "$MAIN_GSJ" "$DEV_GSJ" "$IOS_PLIST"; do
  check_no_foreign_tenant "$tenant_scoped"
done

# =============================================================================
section "1b. Firestore database id seam matches the contract"
# =============================================================================

if [ ! -f "$FIRESTORE_SEAM" ]; then
  fail "$FIRESTORE_SEAM is missing — the app would fall back to an implicit '(default)' with no contract binding"
elif [ -z "$CONTRACT_DATABASE_ID" ]; then
  warn "contract database id unavailable; skipped the seam comparison"
else
  seam_default="$(sed -n "s/.*defaultValue: '\\(.*\\)',.*/\\1/p" "$FIRESTORE_SEAM" | head -1)"
  if [ "$seam_default" = "$CONTRACT_DATABASE_ID" ]; then
    pass "$FIRESTORE_SEAM defaults to $CONTRACT_DATABASE_ID"
  else
    fail "$FIRESTORE_SEAM defaults to '$seam_default', but $CONTRACT pins '$CONTRACT_DATABASE_ID'"
  fi
fi

# Nothing may reach Firestore outside the seam, or a database-id change is
# silently invisible to that call site (the 2026-08-19 chat-service gap).
firestore_bypass="$(grep -rn 'FirebaseFirestore\.instance' lib 2>/dev/null \
  | grep -v "^$FIRESTORE_SEAM:" \
  | grep -vE '^[^:]+:[0-9]+:[[:space:]]*(//|\*)' \
  | cut -d: -f1 | sort -u || true)"
if [ -z "$firestore_bypass" ]; then
  pass "every Firestore instance in lib/ resolves through $FIRESTORE_SEAM"
else
  fail "these files bypass $FIRESTORE_SEAM and pin the implicit default database: $(printf '%s' "$firestore_bypass" | tr '\n' ' ')"
fi

# .firebaserc pins the CLI/flutterfire default project — without it a stray
# 'flutterfire configure' can rewrite every config to another visible project.
FIREBASERC=".firebaserc"
if [ ! -f "$FIREBASERC" ]; then
  fail "$FIREBASERC is missing — the Firebase CLI has no pinned project, so 'flutterfire configure' can silently retarget every config (docs/firebase-invariants.md §1)"
else
  if git ls-files --error-unmatch "$FIREBASERC" >/dev/null 2>&1; then
    pass "$FIREBASERC is tracked"
  else
    fail "$FIREBASERC exists but is not tracked by git"
  fi

  if [ "$HAVE_JQ" = "yes" ]; then
    rc_default="$(jq -r '.projects.default // empty' "$FIREBASERC" 2>/dev/null || echo '')"
    if [ "$rc_default" = "$EXPECTED_PROJECT_ID" ]; then
      pass "$FIREBASERC default project is $EXPECTED_PROJECT_ID"
    else
      fail "$FIREBASERC default project is '$rc_default', expected exactly '$EXPECTED_PROJECT_ID'"
    fi
  fi
fi

# =============================================================================
section "2. Templates present with TODO_ sentinels"
# =============================================================================

for t in \
  "android/app/google-services.json.template" \
  "android/app/src/dev/google-services.json.template" \
  "ios/Runner/GoogleService-Info.plist.template"; do
  if [ ! -f "$t" ]; then
    fail "$t is missing"
  elif grep -q 'TODO_' "$t"; then
    pass "$t present with TODO_ sentinels"
  else
    fail "$t is present but has no TODO_ sentinel (looks like a real config, not a template)"
  fi
done

# =============================================================================
section "3. pubspec.yaml firebase_core pin"
# =============================================================================

if [ -f tool/check_firebase_core_pin.sh ]; then
  if bash tool/check_firebase_core_pin.sh; then
    pass "check_firebase_core_pin.sh"
  else
    fail "check_firebase_core_pin.sh reported a problem (see above)"
  fi
else
  fail "tool/check_firebase_core_pin.sh is missing"
fi

# =============================================================================
section "4. pubspec.lock tracked + firebase family inside envelope"
# =============================================================================

if [ ! -f "$LOCK" ]; then
  fail "$LOCK is missing — run 'flutter pub get'"
else
  if git ls-files --error-unmatch "$LOCK" >/dev/null 2>&1; then
    pass "$LOCK is tracked"
  else
    fail "$LOCK exists but is not tracked by git (see docs/firebase-invariants.md §2 — must be committed, not gitignored)"
  fi

  if git check-ignore -q --no-index "$LOCK" 2>/dev/null; then
    fail "$LOCK is matched by .gitignore — re-ignoring the lock is exactly how firebase_core drifted into the 3.15.x pigeon-poison range on one machine (docs/firebase-invariants.md §3)"
  else
    pass "$LOCK is not gitignored"
  fi

  while read -r pkg kind lower upper exact; do
    [ -n "$pkg" ] || continue
    resolved="$(lock_version "$pkg" || true)"
    if [ -z "$resolved" ]; then
      fail "$pkg has no resolved version in $LOCK"
      continue
    fi
    case "$kind" in
      exact)
        if [ "$resolved" = "$exact" ]; then
          pass "$pkg resolved $resolved == $exact"
        else
          fail "$pkg resolved $resolved, expected exactly $exact"
        fi
        ;;
      range | major)
        if [ "$(semver_cmp "$resolved" "$lower")" -ge 0 ] && [ "$(semver_cmp "$resolved" "$upper")" -lt 0 ]; then
          pass "$pkg resolved $resolved, inside [$lower, $upper)"
        else
          fail "$pkg resolved $resolved, outside the required [$lower, $upper) envelope"
        fi
        ;;
    esac
  done <<EOF
$ENVELOPE_TABLE
EOF
fi

# =============================================================================
section "5. lock SDK floor vs CI + local Flutter"
# =============================================================================

lock_flutter_floor="$(awk '
  /^sdks:$/ { insdks = 1; next }
  insdks && /^[[:space:]]*flutter:[[:space:]]*/ {
    gsub(/^[[:space:]]*flutter:[[:space:]]*"?>=?/, "")
    gsub(/"?[[:space:]]*$/, "")
    print; exit
  }
' "$LOCK" 2>/dev/null || true)"

if [ -z "$lock_flutter_floor" ]; then
  fail "could not read the flutter floor out of ${LOCK}'s sdks: block"
else
  pass "$LOCK sdks: flutter floor is >=$lock_flutter_floor"

  if command -v flutter >/dev/null 2>&1; then
    local_flutter="$(flutter --version 2>/dev/null | awk '/^Flutter /{print $2; exit}' || true)"
    if [ -n "$local_flutter" ] && [ "$(semver_cmp "$local_flutter" "$lock_flutter_floor")" -ge 0 ]; then
      pass "local flutter $local_flutter satisfies the lock floor"
    elif [ -n "$local_flutter" ]; then
      fail "local flutter $local_flutter is BELOW the lock floor >=$lock_flutter_floor — 'flutter pub get' will fail on the SDK constraint alone"
    else
      warn "could not parse a version out of 'flutter --version'"
    fi
  else
    warn "no 'flutter' on PATH — skipped the local-toolchain floor check"
  fi

  fvm_version="$(python3 - .fvmrc <<'PY' 2>/dev/null || true
import json
import re
import sys

with open(sys.argv[1], encoding='utf-8') as handle:
    version = json.load(handle).get('flutter', '')
if isinstance(version, str) and re.fullmatch(r'\d+\.\d+\.\d+', version):
    print(version)
PY
)"
  if [ -z "$fvm_version" ]; then
    fail '.fvmrc does not declare a valid Flutter version'
  elif [ "$(semver_cmp "$fvm_version" "$lock_flutter_floor")" -ge 0 ]; then
    pass ".fvmrc pins Flutter $fvm_version, satisfies the lock floor"
  else
    fail ".fvmrc Flutter $fvm_version is BELOW the lock floor >=$lock_flutter_floor"
  fi

  setup_action='.github/actions/setup-flutter/action.yml'
  # Match the literal GitHub expression rather than expanding it in this shell.
  # shellcheck disable=SC2016
  if ! grep -Fq 'flutter-version: ${{ steps.fvm.outputs.version }}' \
    "$setup_action" 2>/dev/null; then
    fail "$setup_action does not consume the validated .fvmrc output"
  fi

  # Both extensions: any workflow invoking Flutter must use the repository setup
  # action and must not reintroduce a literal or workflow-level version.
  for wf in .github/workflows/*.yml .github/workflows/*.yaml; do
    [ -f "$wf" ] || continue
    if grep -Eq '(^|[[:space:]])(flutter|dart)[[:space:]]+(pub|get|test|build|run|analyze)' \
      "$wf"; then
      if grep -Fq 'uses: ./.github/actions/setup-flutter' "$wf"; then
        pass "$wf consumes Flutter from .fvmrc"
      else
        fail "$wf invokes Flutter/Dart without the .fvmrc setup action"
      fi
    fi
    if grep -Eq 'FLUTTER_VERSION:|flutter-version:[[:space:]]*[0-9]' "$wf"; then
      fail "$wf duplicates the Flutter version instead of consuming .fvmrc"
    fi
  done
fi

# =============================================================================
section "6. no stray firebase-debug.log / dead firebase_options.dart"
# =============================================================================

if [ -f "firebase-debug.log" ] || git ls-files --error-unmatch "firebase-debug.log" >/dev/null 2>&1; then
  fail "firebase-debug.log is present on disk or tracked — Firebase CLI emulator junk, must not ship"
else
  pass "no firebase-debug.log"
fi

if [ -f "lib/core/firebase/firebase_options.dart" ]; then
  fail "lib/core/firebase/firebase_options.dart exists — dead placeholder with zero references, must stay deleted"
else
  pass "lib/core/firebase/firebase_options.dart is absent"
fi

# =============================================================================
section "7. AndroidManifest push wiring"
# =============================================================================

if [ ! -f "$MANIFEST" ]; then
  fail "$MANIFEST is missing"
else
  if grep -q 'android.permission.POST_NOTIFICATIONS' "$MANIFEST"; then
    pass "POST_NOTIFICATIONS declared"
  else
    fail "POST_NOTIFICATIONS permission missing from $MANIFEST"
  fi

  if grep -q 'com.google.firebase.messaging.default_notification_channel_id' "$MANIFEST" \
    && grep -A1 'com.google.firebase.messaging.default_notification_channel_id' "$MANIFEST" | grep -q 'jeeb_default'; then
    pass "jeeb_default default channel metadata intact"
  else
    fail "jeeb_default default_notification_channel_id metadata missing/changed in $MANIFEST"
  fi
fi

# =============================================================================
section "8. protected Firebase validators and wrappers"
# =============================================================================

for protected_tool in \
  tool/validate_android_google_services.sh \
  tool/validate_dev_google_services.sh \
  tool/run_with_android_firebase_config.sh \
  tool/run_with_dev_firebase_config.sh \
  tool/run_with_ios_firebase_config.sh; do
  if [ -f "$protected_tool" ]; then
    pass "$protected_tool is present"
  else
    fail "$protected_tool is missing"
  fi
done

# =============================================================================
section "9. known gaps (informational, non-blocking)"
# =============================================================================

warn "staging and production share canonical package com.olivium.jeeb; store-delivered Firebase behavior remains a live acceptance gate"
warn "iOS dev configs (Release-dev/Debug-dev/Profile-dev) exclude GoogleService-Info.plist by design — iOS dev builds ship with no Firebase"

# =============================================================================
section "Summary"
# =============================================================================

printf '%d failure(s), %d warning(s)\n' "$FAILS" "$WARNS"
if [ "$FAILS" -gt 0 ]; then
  echo "FIREBASE DOCTOR: FAIL"
  exit 1
fi
echo "FIREBASE DOCTOR: PASS"
