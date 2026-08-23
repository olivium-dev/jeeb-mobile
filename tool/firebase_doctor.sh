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
firebase_auth         exact    -            -           5.4.2
firebase_messaging    major    15.0.0       16.0.0      -
cloud_firestore       major    5.0.0        6.0.0       -
'

MAIN_GSJ="android/app/google-services.json"
DEV_GSJ="android/app/src/dev/google-services.json"
EXPECTED_PROJECT_NUMBER="1051234312170"
EXPECTED_PROJECT_ID="jeeb-5a293"
EXPECTED_DEV_APP_ID="1:1051234312170:android:146d7f24f109e38523dc93"
MANIFEST="android/app/src/main/AndroidManifest.xml"
LOCK="pubspec.lock"
SPEC="pubspec.yaml"

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
section "1. google-services.json — tracked, identity, no leaks"
# =============================================================================

check_gsj() {
  local f="$1"; local require_dev_client="$2"
  if [ ! -f "$f" ]; then
    fail "$f is missing"
    return
  fi

  if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
    pass "$f is tracked"
  else
    fail "$f exists but is not tracked by git"
  fi

  # --no-index is mandatory: plain check-ignore skips TRACKED paths, which
  # would make this regression check permanently vacuous for these files.
  if git check-ignore -q --no-index "$f" 2>/dev/null; then
    fail "$f is matched by .gitignore (must never be re-ignored, see docs/firebase-invariants.md §2)"
  else
    pass "$f is not gitignored"
  fi

  if [ "$HAVE_JQ" = "no" ]; then
    return
  fi

  local pn pid
  pn="$(jq -r '.project_info.project_number' "$f" 2>/dev/null || echo '')"
  pid="$(jq -r '.project_info.project_id' "$f" 2>/dev/null || echo '')"
  if [ "$pn" = "$EXPECTED_PROJECT_NUMBER" ] && [ "$pid" = "$EXPECTED_PROJECT_ID" ]; then
    pass "$f project identity is $pid / $pn"
  else
    fail "$f project identity is '$pid'/'$pn', expected '$EXPECTED_PROJECT_ID'/'$EXPECTED_PROJECT_NUMBER'"
  fi

  if jq -e '[.client[]?.client_info.android_client_info.package_name] | index("app.jeeb.mobile") != null' "$f" >/dev/null 2>&1; then
    pass "$f carries app.jeeb.mobile client"
  else
    fail "$f is missing the app.jeeb.mobile client"
  fi

  if [ "$require_dev_client" = "yes" ]; then
    if jq -e '[.client[]?.client_info.android_client_info.package_name] | index("app.jeeb.mobile.dev") != null' "$f" >/dev/null 2>&1; then
      pass "$f carries app.jeeb.mobile.dev client"
    else
      fail "$f is missing the app.jeeb.mobile.dev client"
    fi
  fi

  if grep -qi 'alrahmah' "$f"; then
    fail "$f references the FORBIDDEN 'alrahmah' project"
  else
    pass "$f has no 'alrahmah' reference"
  fi

  if grep -q 'private_key' "$f"; then
    fail "$f contains a 'private_key' field — this looks like a leaked service-account key, not a client config"
  else
    pass "$f has no 'private_key' field"
  fi
}

if [ "$HAVE_JQ" = "no" ]; then
  fail "jq is not installed — the google-services.json identity/client checks CANNOT run. Install it (macOS: 'brew install jq', Debian/Ubuntu: 'apt-get install -y jq') and re-run."
fi

check_gsj "$MAIN_GSJ" no
check_gsj "$DEV_GSJ" yes

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

  # Both extensions: a future *.yaml workflow must not slip past this check.
  for wf in .github/workflows/*.yml .github/workflows/*.yaml; do
    [ -f "$wf" ] || continue
    var_val="$(grep -oE "FLUTTER_VERSION:[[:space:]]*'[0-9]+\.[0-9]+\.[0-9]+'" "$wf" 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true)"
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      if printf '%s' "$line" | grep -q 'env.FLUTTER_VERSION'; then
        ver="$var_val"
      else
        ver="$(printf '%s' "$line" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true)"
      fi
      if [ -z "$ver" ]; then
        warn "$wf: found a flutter-version: line but could not resolve a literal version"
        continue
      fi
      if [ "$(semver_cmp "$ver" "$lock_flutter_floor")" -ge 0 ]; then
        pass "$wf pins flutter-version $ver, satisfies the lock floor"
      else
        fail "$wf pins flutter-version $ver, BELOW the lock floor >=$lock_flutter_floor — CI would fail 'pub get' on the SDK constraint"
      fi
    done < <(grep -oE 'flutter-version:.*' "$wf" 2>/dev/null || true)
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
section "8. dev Firebase config validator (protected identity)"
# =============================================================================

if [ -f tool/validate_dev_google_services.sh ]; then
  if DEV_FIREBASE_EXPECTED_PROJECT_NUMBER="$EXPECTED_PROJECT_NUMBER" \
     DEV_FIREBASE_EXPECTED_PROJECT_ID="$EXPECTED_PROJECT_ID" \
     DEV_FIREBASE_EXPECTED_APP_ID="$EXPECTED_DEV_APP_ID" \
     bash tool/validate_dev_google_services.sh "$DEV_GSJ"; then
    pass "validate_dev_google_services.sh"
  else
    warn "validate_dev_google_services.sh did not pass against $DEV_GSJ (see output above)"
  fi
else
  warn "tool/validate_dev_google_services.sh is missing — orphaned validator not wired"
fi

# =============================================================================
section "9. known gaps (informational, non-blocking)"
# =============================================================================

warn "staging flavor (app.jeeb.mobile.staging) has NO Firebase client entry in any google-services.json — latent, never exercised on hardware"
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
