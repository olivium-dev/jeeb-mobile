#!/usr/bin/env bash
# firebase_core resolution gate.
#
# firebase_core 3.15.0 ships a pigeon channel signature that does not match the
# Android plugin shipped alongside it: FirebaseApp initialisation silently
# no-ops, so push registration and Firestore chat die with no error. The app
# therefore pins `firebase_core: ">=3.13.1 <3.15.0"` in pubspec.yaml.
#
# pubspec.lock is gitignored, so the pin is only ever enforced at resolve time
# and each machine resolves its own. This gate re-checks the RESOLVED version
# after `flutter pub get` in CI, and also verifies the pubspec.yaml constraint
# itself has not been widened.
#
# Run locally (after `flutter pub get`):
#   bash tool/check_firebase_core_pin.sh
#
# Wire into CI (.github/workflows/<workflow>.yml), after `flutter pub get`:
#   - name: firebase_core pin gate
#     run: bash tool/check_firebase_core_pin.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK="$REPO_ROOT/pubspec.lock"
SPEC="$REPO_ROOT/pubspec.yaml"

MIN='3.13.1'  # inclusive
MAX='3.15.0'  # exclusive

fail() {
  echo "::error::$*" >&2
  echo "FAIL: $*" >&2
  exit 1
}

[ -f "$SPEC" ] || fail "pubspec.yaml not found at $SPEC"
[ -f "$LOCK" ] || fail "pubspec.lock not found at $LOCK — run 'flutter pub get' before this gate."

# --- 1. the declared constraint must still be the exact intended window ------
declared="$(awk '/^[[:space:]]*firebase_core:[[:space:]]*/ {print; exit}' "$SPEC" | sed 's/^[[:space:]]*firebase_core:[[:space:]]*//; s/[[:space:]]*$//; s/^"//; s/"$//')"
expected=">=$MIN <$MAX"
if [ "$declared" != "$expected" ]; then
  fail "pubspec.yaml declares firebase_core: '$declared' but the pin must stay '$expected' (firebase_core 3.15.0 breaks the Android pigeon channel: no push registration, no Firestore chat, silently)."
fi

# --- 2. the resolved version must sit inside the window ---------------------
resolved="$(awk '
  /^  firebase_core:$/ { inblock = 1; next }
  inblock && /^  [a-z0-9_]+:$/ { inblock = 0 }
  inblock && /^[[:space:]]*version:[[:space:]]*/ {
    gsub(/^[[:space:]]*version:[[:space:]]*"?|"?[[:space:]]*$/, "")
    print; exit
  }
' "$LOCK")"

[ -n "$resolved" ] || fail "could not read a resolved firebase_core version out of pubspec.lock"

# Numeric semver compare; strips any -prerelease / +build suffix.
core="${resolved%%-*}"; core="${core%%+*}"
IFS='.' read -r r_maj r_min r_pat <<EOF
$core
EOF
r_pat="${r_pat:-0}"

in_range() {
  local bmaj bmin bpat
  IFS='.' read -r bmaj bmin bpat <<EOF
$1
EOF
  # prints -1 / 0 / 1 for resolved vs $1
  if   [ "$r_maj" -ne "$bmaj" ]; then [ "$r_maj" -gt "$bmaj" ] && echo 1 || echo -1
  elif [ "$r_min" -ne "$bmin" ]; then [ "$r_min" -gt "$bmin" ] && echo 1 || echo -1
  elif [ "$r_pat" -ne "$bpat" ]; then [ "$r_pat" -gt "$bpat" ] && echo 1 || echo -1
  else echo 0
  fi
}

[ "$(in_range "$MIN")" -ge 0 ] || fail "firebase_core resolved to $resolved, below the >=$MIN floor."
[ "$(in_range "$MAX")" -lt 0 ] || fail "firebase_core resolved to $resolved, at or above the <$MAX ceiling. 3.15.0+ breaks the Android pigeon channel: FirebaseApp init silently no-ops, killing push registration and Firestore chat."

echo "OK: firebase_core resolved $resolved, inside >=$MIN <$MAX (pubspec.yaml declares '$declared')."
