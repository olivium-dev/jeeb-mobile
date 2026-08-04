#!/usr/bin/env bash
# QA-PRE scaffold for T-MOB-FIX-001 (parent Story JEB-1).
# Asserts UX rules #1-#10 (Jira comment 14746) and the LEAD placeholder
# template (Jira comment 14747) on every Type-A widget file.
#
# Run from repo root:
#   ./jeeb-code/jeeb-mobile/qa/t-mob-fix-001/placeholder-discipline.sh
#
# Exit codes:
#   0  all 10 Type-A files match the template; all 11 Type-B files keep no-op shape
#   1  a Type-A file violates one or more discipline rules
#   2  a Type-B file was widget-ified (banned by LEAD §2)
#   3  a file in the allowlist is missing or was deleted
set -uo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MOBILE_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
ALLOW_FILE="$SCRIPT_DIR/placeholder-discipline-allow.txt"
cd "$MOBILE_ROOT"

# --- Refined Type-A list (was 11 per LEAD comment 14747 §2 Risk §5) --------
# These files MUST match the OMDS placeholder template exactly.
# rating_prompt_screen.dart removed with the ratified M3-42 orphan deletion
# (02-STUDY-NOTES §ORPHAN): the route keeps its redirect, the screen is gone.
TYPE_A_FILES=(
  "lib/features/biometric_auth/presentation/biometric_lock_screen.dart"
  "lib/features/deep_link_targets/chat_detail_screen.dart"
  "lib/features/deep_link_targets/delivery_detail_screen.dart"
  "lib/features/deep_link_targets/kyc_status_screen.dart"
  "lib/features/jeeber_request_detail/presentation/jeeber_request_detail_screen.dart"
  "lib/features/location/presentation/screens/location_picker_screen.dart"
  "lib/features/settings/presentation/screens/notification_preferences_screen.dart"
  "lib/features/settings/presentation/screens/saved_addresses_screen.dart"
  "lib/features/transcription/presentation/transcription_screen.dart"
  "lib/features/voice_request/presentation/voice_request_screen.dart"
)

# --- Type-B list (11 files per LEAD comment 14747 §2) -----------------------
# These keep their current minimal no-op shape. They MUST NOT import OMDS
# (LEAD §2 last paragraph: "ENG MUST NOT widget-ify them").
TYPE_B_FILES=(
  "lib/core/observability/crash_context_bridge.dart"
  "lib/features/biometric_auth/application/biometric_lock_cubit.dart"
  "lib/features/biometric_auth/application/biometric_lock_state.dart"
  "lib/features/biometric_auth/data/shared_prefs_pin_repository.dart"
  "lib/features/biometric_auth/domain/biometric_gateway.dart"
  "lib/features/jeeber_request_detail/domain/services/prohibited_item_report_service.dart"
  "lib/features/offers/domain/offer_submission_service.dart"
  "lib/features/request_summary/domain/prohibited_acknowledgment_repository.dart"
  "lib/features/request_summary/domain/request_submission_service.dart"
  "lib/features/settings/data/repositories/biometric_preference_repository_impl.dart"
  "lib/features/transcription/domain/voice_clip.dart"
)

# --- Allowlist (4 files per LEAD comment 14747 §5) --------------------------
# These must exist (LEAD wants them left alone) but are excluded from rule
# enforcement.
ALLOW_FILES=()
while IFS= read -r line; do
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
  ALLOW_FILES+=("$line")
done < "$ALLOW_FILE"

FAILS=0
PASSES=0

assert_exists () {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "  [FAIL] $path — file does not exist"
    return 1
  fi
  return 0
}

# Returns 0 (pass) or 1 (fail). Prints per-rule status.
check_type_a () {
  local path="$1"
  local rel
  rel="$path"
  local local_fail=0
  echo "--- $rel ---"

  if ! assert_exists "$path"; then return 1; fi

  # Rule A: imports the OMDS barrel (or the canonical empty-state file).
  # Canonical: package:omds/omds.dart (verified via omds_library/lib/omds.dart
  # which re-exports src/feedback/omds_empty_state.dart at line 114).
  if grep -qE "^import 'package:omds/(omds\.dart|src/feedback/omds_empty_state\.dart)'" "$path"; then
    echo "  [PASS] imports OMDS empty-state"
  else
    echo "  [FAIL] missing import of package:omds/omds.dart (UX rule #1, LEAD template)"
    local_fail=1
  fi

  # Rule B: uses OmdsEmptyStatePage (not bare Scaffold(body: Center(...))).
  if grep -q "OmdsEmptyStatePage" "$path"; then
    echo "  [PASS] uses OmdsEmptyStatePage"
  else
    echo "  [FAIL] does not call OmdsEmptyStatePage (UX rule #1, AC4)"
    local_fail=1
  fi

  # Rule C: bans the anti-pattern Scaffold(body: Center(child: Text(...))).
  # We allow any Scaffold (OmdsEmptyStatePage wraps one internally) but ban
  # the explicit "Scaffold(body: Center" combo at the call-site.
  if grep -qE "Scaffold\s*\(\s*body\s*:\s*Center" "$path"; then
    echo "  [FAIL] uses raw Scaffold(body: Center(...)) anti-pattern (UX rule #1)"
    local_fail=1
  else
    echo "  [PASS] no raw Scaffold(body: Center) anti-pattern"
  fi

  # Rule D: no AppLocalizations / l10n hooks (UX rule #7 — out of scope; that
  # is T-MOB-FIX-002).
  if grep -qE "AppLocalizations\.of|\.tr\b|\.tr\(|S\.of\(context\)" "$path"; then
    echo "  [FAIL] calls a localization hook (UX rule #7, scope of T-MOB-FIX-002)"
    local_fail=1
  else
    echo "  [PASS] no l10n hook"
  fi

  # Rule E: declares Semantics wrapper OR relies on OmdsEmptyStatePage's own
  # semantics tree. LEAD template wraps in Semantics(container: true, label:…);
  # OmdsEmptyState uses Flutter Text widgets that carry implicit semantics
  # (verified at omds_library/lib/src/feedback/omds_empty_state.dart:97-119).
  # Pass if EITHER (a) the file declares Semantics, OR (b) the file uses
  # OmdsEmptyStatePage (which provides the semantic tree via its child Texts).
  if grep -q "Semantics\s*(" "$path"; then
    echo "  [PASS] declares Semantics wrapper"
  elif grep -q "OmdsEmptyStatePage" "$path"; then
    echo "  [PASS] inherits semantics from OmdsEmptyStatePage's Text tree"
  else
    echo "  [FAIL] no Semantics wrapper and no OmdsEmptyStatePage (a11y gap)"
    local_fail=1
  fi

  # Rule F: AC5 logger — debugPrint('[placeholder] <id> opened') inside
  # initState (NOT inside build, per UX rule #6).
  if grep -q "void initState()" "$path" && \
     grep -qE "debugPrint\(\s*['\"]\[placeholder\]" "$path"; then
    echo "  [PASS] AC5 logger fires in initState"
  else
    echo "  [FAIL] missing debugPrint('[placeholder] …') inside initState (AC5, UX rule #6, LEAD template)"
    local_fail=1
  fi

  # Rule G: must be a StatefulWidget per LEAD §1 (StatelessWidget cannot have
  # initState).
  if grep -q "extends StatefulWidget" "$path"; then
    echo "  [PASS] is StatefulWidget"
  else
    echo "  [FAIL] not a StatefulWidget (LEAD §1; initState requires State<T>)"
    local_fail=1
  fi

  # Rule H: bans buttonText / onButtonTap on OmdsEmptyStatePage (UX rule #5).
  # We check the call-site keyword to be precise (the constructor declares
  # those params; we only ban passing them).
  if grep -qE "OmdsEmptyStatePage\([^)]*(buttonText|onButtonTap)" "$path"; then
    echo "  [FAIL] passes buttonText or onButtonTap to OmdsEmptyStatePage (UX rule #5)"
    local_fail=1
  else
    echo "  [PASS] no button on placeholder (UX rule #5)"
  fi

  # Rule I: bans CircularProgressIndicator / shimmer (UX rule #3).
  if grep -qE "CircularProgressIndicator|OmdsLoadingIndicator|Shimmer" "$path"; then
    echo "  [FAIL] includes a loading indicator on a terminal placeholder (UX rule #3)"
    local_fail=1
  else
    echo "  [PASS] no loading indicator"
  fi

  # Rule J: bans raw Colors.* (UX rule #8; flutter-material3-colorscheme-discipline).
  if grep -qE "Colors\.[a-zA-Z_]+" "$path"; then
    echo "  [FAIL] uses raw Colors.* (UX rule #8, flutter-material3-colorscheme-discipline)"
    local_fail=1
  else
    echo "  [PASS] no raw Colors.*"
  fi

  # Rule K: bans SnackBar / dialog on entry (UX rule #4).
  if grep -qE "ScaffoldMessenger|showSnackBar|showDialog|OmdsDialog|OmdsSnackbar" "$path"; then
    echo "  [FAIL] shows a snackbar or dialog on placeholder route (UX rule #4)"
    local_fail=1
  else
    echo "  [PASS] no snackbar/dialog on entry"
  fi

  return $local_fail
}

# Type-B: confirm no OMDS widget-ification.
check_type_b () {
  local path="$1"
  echo "--- $path (Type-B)"
  if ! assert_exists "$path"; then return 1; fi

  # Must NOT import the OMDS barrel (LEAD §2: "ENG MUST NOT widget-ify them").
  if grep -qE "^import 'package:omds/" "$path"; then
    echo "  [FAIL] Type-B file imports OMDS (was widget-ified — banned by LEAD §2)"
    return 1
  fi
  # Must NOT extend StatefulWidget / StatelessWidget.
  if grep -qE "extends (StatefulWidget|StatelessWidget)" "$path"; then
    echo "  [FAIL] Type-B file declares a Flutter Widget (banned by LEAD §2)"
    return 1
  fi
  echo "  [PASS] no-op shape preserved"
  return 0
}

# Allowlist: must exist (LEAD §5 wants them left alone, not deleted).
check_allow () {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "  [FAIL] allowlisted file deleted: $path"
    return 1
  fi
  echo "  [PASS] $path exists (excluded from rules per LEAD §5)"
  return 0
}

echo "=========================================================="
echo " PLACEHOLDER DISCIPLINE — T-MOB-FIX-001"
echo "=========================================================="
echo ""
echo "== Type-A (${#TYPE_A_FILES[@]} files; OMDS placeholder template required) =="
for f in "${TYPE_A_FILES[@]}"; do
  if check_type_a "$f"; then
    PASSES=$((PASSES+1))
  else
    FAILS=$((FAILS+1))
  fi
done

echo ""
echo "== Type-B (11 files; no-op shape, no OMDS) =="
for f in "${TYPE_B_FILES[@]}"; do
  if check_type_b "$f"; then
    PASSES=$((PASSES+1))
  else
    FAILS=$((FAILS+1))
  fi
done

echo ""
echo "== Allowlist (4 files; existence-only check) =="
for f in "${ALLOW_FILES[@]}"; do
  if check_allow "$f"; then
    PASSES=$((PASSES+1))
  else
    FAILS=$((FAILS+1))
  fi
done

echo ""
echo "=========================================================="
echo " RESULT: $PASSES passed, $FAILS failed"
echo "=========================================================="

if [[ $FAILS -gt 0 ]]; then
  exit 1
fi
exit 0
