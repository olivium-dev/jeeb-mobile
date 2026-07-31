#!/usr/bin/env bash
# MB1 test pack — one verdict PER MEMBER ITEM.
#
# Why not just `flutter test`: a pack that goes red as one lump cannot tell a
# verifier which member item broke, and GATE.md §8 ("revert that one commit and
# re-land it") has nothing to act on. Each row below is its own invocation.
#
#   tool/mb1/run-pack.sh              # the suite/static rows
#   tool/mb1/run-pack.sh --with-apk   # + the W1.4 APK compile (slow, ~10 min)
#
# Exit codes:  0 = every scored row PASS and nothing BLOCKED
#              1 = at least one scored row FAILED
#              2 = every scored row PASS but a row is BLOCKED
#
# Exit 2 is deliberate and it is NOT a pass. GATE.md §4: a BLOCKED verdict counts
# as FAIL for the purpose of closing a gate. R1 is BLOCKED by construction here —
# the writer and the test author run no device round — so this pack CANNOT
# self-close, which is the point.
set -uo pipefail

cd "$(dirname "$0")/../.." || exit 1
ROOT="$(pwd)"
WITH_APK=0
[[ "${1:-}" == "--with-apk" ]] && WITH_APK=1

pass=0; fail=0; blocked=0; failed_items=()

row() { printf '%-8s %-9s %-9s %s\n' "$1" "$2" "$3" "$4"; }

run_item() {
  local id="$1" cls="$2" title="$3"; shift 3
  local files=("$@")
  local out
  out="$(flutter test "${files[@]}" -r compact 2>&1)"
  local rc=$?
  local counted
  counted="$(printf '%s' "$out" | grep -oE '\+[0-9]+' | tail -1)"
  if [[ $rc -eq 0 ]]; then
    pass=$((pass+1)); row "$id" "PASS" "$cls" "$title  [${counted:-?} cases]"
  else
    fail=$((fail+1)); failed_items+=("$id"); row "$id" "FAIL" "$cls" "$title"
    printf '%s\n' "$out" | grep -E '^\s+(Expected|Actual|Which|.*\[E\])' | head -12 | sed 's/^/           | /'
  fi
}

echo "MB1 pack @ $(git rev-parse --short HEAD)  (base $(git rev-parse --short origin/main))"
echo "ITEM     VERDICT   CLASS     WHAT"
echo "-------- --------- --------- --------------------------------------------"

run_item W1.1  static "courier marker wire + SSE teardown" \
  test/features/live_tracking/sse_teardown_grep_receipt_test.dart

run_item W1.1b suite  "the tracking_screen_open / tracking_position instrument" \
  test/features/live_tracking/tracking_diag_instrument_test.dart

run_item W1.1c suite  "rework of the two KEPT test files" \
  test/mb1/mb1_w1_1c_kept_tests_test.dart \
  test/features/live_tracking/live_tracking_push_driven_test.dart \
  test/features/live_tracking/tracking_live_position_overlay_test.dart \
  test/features/live_tracking/live_tracking_lifecycle_test.dart

run_item W1.2  suite  "FCM re-registration on login / user-switch" \
  test/mb1/mb1_w1_2_fcm_reregistration_test.dart \
  test/device_token_registrar_login_test.dart \
  test/session_login_reregister_wiring_test.dart

run_item W4.1  suite  "gallery pick reaches the REAL DI picker" \
  test/mb1/mb1_w4_1_gallery_pick_test.dart \
  test/features/chat/chat_picker_binding_test.dart

run_item DOC   static "doc residuals, repo-wide over EVERY tracked file" \
  test/mb1/mb1_doc_residual_receipts_test.dart

run_item OWN2  suite  "owner ruling #2 — MSI is the FIRST DevTool preset" \
  test/devtool/dev_server_url_presets_test.dart

run_item W1.4  build  "every dart-define on the build line has a live consumer" \
  test/mb1/mb1_w1_4_build_line_test.dart

if [[ $WITH_APK -eq 1 ]]; then
  sha="$(git rev-parse HEAD)"
  if flutter build apk --debug --flavor dev \
       --dart-define=JEEB_MOCK_BASE_URL=http://127.0.0.1:9000 \
       --dart-define=JEEB_DEVTOOL_ENABLED=true \
       --dart-define=JEEB_BUILD_SHA="$sha" >/dev/null 2>&1; then
    pass=$((pass+1)); row "W1.4apk" "PASS" "build" "APK compiles on the corrected define line"
  else
    fail=$((fail+1)); failed_items+=("W1.4apk"); row "W1.4apk" "FAIL" "build" "APK does NOT compile"
  fi
else
  row "W1.4apk" "SKIPPED" "build" "pass --with-apk to compile (~10 min; NOT installed)"
fi

# ---------------------------------------------------------------------------
# Rows that no host suite can produce. Stated, never substituted.
# ---------------------------------------------------------------------------
row "W1.3" "N/A" "process" "two-model review + merge — no local predicate, and MB1.md forbids a CI one"

if python3 tool/mb1/r1-check.py --selftest >/dev/null 2>&1; then
  row "R1" "BLOCKED" "device" "instrument SELF-TESTS green; no round has been run — GATE.md §4: not a pass"
else
  fail=$((fail+1)); failed_items+=("R1-instrument")
  row "R1" "FAIL" "device" "the R1 reader itself fails its own self-test — fix it before the round"
fi
blocked=$((blocked+1))

row "PUSHCHK" "BLOCKED" "service" "needs a live bearer token; MSI 192.168.2.39:10090 only"
blocked=$((blocked+1))

echo "-------- --------- --------- --------------------------------------------"
echo "$pass PASS, $fail FAIL, $blocked BLOCKED"
[[ ${#failed_items[@]} -gt 0 ]] && echo "failed items: ${failed_items[*]}"
echo "$ROOT" >/dev/null

if [[ $fail -gt 0 ]]; then exit 1; fi
if [[ $blocked -gt 0 ]]; then
  echo "BLOCKED rows present: this pack cannot close MB1's gate on its own, by design."
  exit 2
fi
exit 0
