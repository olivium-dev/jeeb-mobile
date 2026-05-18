#!/usr/bin/env bash
# QA-PRE scaffold for T-MOB-FIX-003 — DI signature consistency check.
#
# Asserts that `configureDependencies` is declared and called with the same
# two required named parameters across the codebase. This catches the exact
# class of drift that produced JEB-3 (call site advanced, declaration didn't).
#
# Rules:
#   R1  Exactly one declaration of `configureDependencies` in lib/core/di/.
#   R2  Declaration takes both `required SharedPreferences sharedPreferences`
#       AND `required CrashReporter crashReporter` (named, required).
#   R3  Every production call site under lib/ passes BOTH `sharedPreferences:`
#       and `crashReporter:` named args.
#   R4  No call site passes positional args (would silently break the signature).
#   R5  SharedPreferences + CrashReporter MUST be registered before any
#       lazy singleton that consumes them (registration order: per LEAD pin).
#
# Run from repo root:
#   ./jeeb-code/jeeb-mobile/qa/t-mob-fix-003/di-signature-check.sh
#
# Exit codes:
#   0  all rules pass
#   1  R1 violation (zero or multiple declarations)
#   2  R2 violation (declaration missing one or both required named params)
#   3  R3 violation (a call site missing one of the named args)
#   4  R4 violation (positional-style call site detected)
#   5  R5 violation (lazy registration that depends on prefs/crash precedes singletons)
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MOBILE_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
ARTIFACT_DIR="${MOBILE_ROOT}/qa/t-mob-fix-003/_artifacts"
mkdir -p "$ARTIFACT_DIR"

cd "$MOBILE_ROOT"
DI_FILE="lib/core/di/injection_container.dart"
REPORT="$ARTIFACT_DIR/di-signature-check.log"
: > "$REPORT"

log() { echo "$@" | tee -a "$REPORT"; }

log "==> DI signature consistency check"
log "    Repo: $MOBILE_ROOT"
log "    DI file: $DI_FILE"
log ""

# ----- R1: exactly one declaration -----
DECL_COUNT=$(grep -rnE '^void configureDependencies\(' lib/ 2>/dev/null | wc -l | tr -d ' ')
log "[R1] declarations of 'void configureDependencies(' under lib/: $DECL_COUNT"
if [ "$DECL_COUNT" -ne 1 ]; then
  log "FAIL [R1]: expected exactly 1 declaration, found $DECL_COUNT."
  grep -rnE '^void configureDependencies\(' lib/ 2>/dev/null | tee -a "$REPORT"
  exit 1
fi

# ----- R2: declaration has both required named params -----
log ""
log "[R2] verifying declaration signature in $DI_FILE"
if [ ! -f "$DI_FILE" ]; then
  log "FAIL [R2]: $DI_FILE does not exist."
  exit 2
fi

# Grab the declaration block (from `void configureDependencies(` until the
# matching `)`).
DECL_BLOCK=$(awk '
  /^void configureDependencies\(/ { capture=1 }
  capture { print; if ($0 ~ /\)/ && !/configureDependencies\(/) { capture=0 } }
' "$DI_FILE")

log "--- declaration block ---"
log "$DECL_BLOCK"
log "--- end ---"

if ! grep -qE 'required SharedPreferences sharedPreferences' <<< "$DECL_BLOCK"; then
  log "FAIL [R2]: declaration missing 'required SharedPreferences sharedPreferences'."
  exit 2
fi
if ! grep -qE 'required CrashReporter crashReporter' <<< "$DECL_BLOCK"; then
  log "FAIL [R2]: declaration missing 'required CrashReporter crashReporter'."
  exit 2
fi
log "[R2] OK — declaration carries both required named params."

# ----- R3 + R4: every call site under lib/ matches the signature -----
log ""
log "[R3+R4] scanning call sites under lib/ (excluding the DI file itself)"
CALL_SITES=$(grep -rnE 'configureDependencies\s*\(' lib/ 2>/dev/null \
  | grep -v "^$DI_FILE:" \
  | grep -v ':[[:space:]]*//[[:space:]]*' || true)
log "$CALL_SITES"

if [ -z "$CALL_SITES" ]; then
  log "WARN [R3]: no production call sites found under lib/ (excluding DI file)."
  log "           Expected at least one (Bootstrap.minimal). Continuing — out-of-tree caller suspected."
fi

# For each call site, grab the surrounding 5 lines and check both named args.
echo "$CALL_SITES" | while IFS= read -r hit; do
  [ -z "$hit" ] && continue
  file="${hit%%:*}"
  rest="${hit#*:}"
  line="${rest%%:*}"
  start=$((line))
  end=$((line + 5))
  block=$(sed -n "${start},${end}p" "$file")

  log ""
  log "  call site: $file:$line"
  log "$block" | sed 's/^/    /' | tee -a "$REPORT" >/dev/null

  # R4: detect positional-style first-arg (anything other than `sharedPreferences:`)
  first_arg=$(echo "$block" | grep -oE 'configureDependencies\s*\(\s*[A-Za-z_][A-Za-z0-9_]*' | head -1 | sed -E 's/.*\(\s*//')
  if [ -n "$first_arg" ] && [ "$first_arg" != "sharedPreferences" ] && [ "$first_arg" != "" ]; then
    # Check whether the next char is `:` (named) or not (positional)
    # The block contains the call open-paren; look for the named-arg colon.
    if ! echo "$block" | grep -qE 'configureDependencies\s*\(\s*$|configureDependencies\([[:space:]]*\)|sharedPreferences:'; then
      log "FAIL [R4]: positional-style invocation detected at $file:$line."
      exit 4
    fi
  fi

  # R3: both named args must appear in the block
  if ! echo "$block" | grep -qE 'sharedPreferences:'; then
    log "FAIL [R3]: call site at $file:$line missing 'sharedPreferences:' named arg."
    exit 3
  fi
  if ! echo "$block" | grep -qE 'crashReporter:'; then
    log "FAIL [R3]: call site at $file:$line missing 'crashReporter:' named arg."
    exit 3
  fi
done

log "[R3+R4] OK — all production call sites pass both required named args."

# ----- R5: registration order — singletons before lazy singletons that depend on them -----
log ""
log "[R5] registration order check in $DI_FILE"
SP_LINE=$(grep -nE 'registerSingleton<SharedPreferences>' "$DI_FILE" | head -1 | cut -d: -f1 || true)
CR_LINE=$(grep -nE 'registerSingleton<CrashReporter>'    "$DI_FILE" | head -1 | cut -d: -f1 || true)
DIO_LINE=$(grep -nE 'registerLazySingleton<Dio>'         "$DI_FILE" | head -1 | cut -d: -f1 || true)
log "    SharedPreferences singleton @ line: ${SP_LINE:-<missing>}"
log "    CrashReporter     singleton @ line: ${CR_LINE:-<missing>}"
log "    Dio          lazy singleton @ line: ${DIO_LINE:-<missing>}"
if [ -z "$SP_LINE" ] || [ -z "$CR_LINE" ]; then
  log "FAIL [R5]: SharedPreferences and/or CrashReporter singletons not registered."
  exit 5
fi
if [ -n "$DIO_LINE" ]; then
  if [ "$DIO_LINE" -lt "$SP_LINE" ] || [ "$DIO_LINE" -lt "$CR_LINE" ]; then
    log "FAIL [R5]: Dio lazy singleton is registered before SharedPreferences/CrashReporter."
    log "           LEAD pin requires runtime singletons first."
    exit 5
  fi
fi
log "[R5] OK — registration order is correct."

log ""
log "============================================================"
log " DI SIGNATURE CHECK PASSED — R1..R5 green."
log " Artifact: $REPORT"
log "============================================================"
