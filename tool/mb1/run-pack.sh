#!/usr/bin/env bash
# MB1 TEST PACK — runner.
#
# Runs each MEMBER ITEM as a SEPARATE PROCESS and prints a SEPARATE verdict for
# each. Nothing short-circuits: every item runs even after an earlier one fails,
# because a pack that goes red as one lump cannot tell the verifiers which item
# broke (GATE.md §8).
#
#   tool/mb1/run-pack.sh              run every item
#   tool/mb1/run-pack.sh M2 M5        run only those items
#   tool/mb1/run-pack.sh --list       show the item -> member-item mapping
#
# Exit 0 = every item PASS
#      1 = at least one item FAIL
#      2 = every item that ran PASSED, but at least one is BLOCKED (no device).
#          GATE.md §4: BLOCKED is VOID and VOID counts as FAIL for closing a
#          gate. `exit 2` exists so a caller cannot mistake a device-less run
#          for a clean one.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$ROOT" || exit 1

# The commit this branch was cut from. Every "this is gone now" claim in the
# pack is measured against it, and the ancestry row below is what proves the
# branch is a descendant rather than a divergent rewrite.
BASE_SHA="30d12f1a2023db8a98e4af40a0627897ede8c577"

# ITEM | member item | how it is run
ITEMS=(
  "M0|GATE — dart analyze lib + ancestry (build/static)|__gate__"
  "M1|W1.1 THE WIRE — 4 causes, no cadence, no blanking, wire path|test/mb1/m1_tracking_wire_test.dart"
  "M2|W1.1 THE TEARDOWN — one grep receipt per deleted symbol|test/mb1/m2_sse_teardown_receipts_test.dart"
  "M3|STALE DOC-COMMENT CLEANUPS — 4 token sites + 2 prose sites, pinned by base line (site 5 is in M9)|test/mb1/m3_doc_comment_sites_test.dart"
  "M4|W1.2 FCM RE-REGISTRATION on login / user-switch|test/mb1/m4_fcm_reregistration_test.dart"
  "M5|W4.1 GALLERY PICK — cubit, resolver, DI, impl, stale prose|test/mb1/m5_gallery_pick_test.dart"
  "M6|THE V-2 INSTRUMENT + proof its predicate can FAIL|test/mb1/m6_diag_instrument_test.dart"
  "M6b|buildSha POS control — same file under --dart-define|__buildsha__"
  "M7|NON-CLAIMS — no Firestore path, Firebase.apps empty, device rows|test/mb1/m7_nonclaims_test.dart"
  "M8|R1 DEVICE ROUND — not runnable here, by construction|__device__"
  "M9|W1.1c THE TWO KEPT TEST FILES — reworked, not deleted|__kept__"
  "M10|OWNER RULING 2026-07-31 #2 — MSI Dev Tool preset, RENDERED|test/mb1/m10_devtool_msi_preset_test.dart"
  "M11|V-1's CONTRACT in its own command shape — repo-wide git grep|test/mb1/m11_v1_contract_shape_test.dart"
)

if [[ "${1:-}" == "--list" ]]; then
  for row in "${ITEMS[@]}"; do
    IFS='|' read -r id desc how <<<"$row"
    printf '%-4s %s\n' "$id" "$desc"
  done
  exit 0
fi

WANTED=("$@")
want() {
  [[ ${#WANTED[@]} -eq 0 ]] && return 0
  local id="$1" w
  for w in "${WANTED[@]}"; do [[ "$w" == "$id" ]] && return 0; done
  return 1
}

PASS=0; FAIL=0; BLOCKED=0
RESULTS=()

run_gate() {
  local ok=0
  echo "--- dart analyze lib ---"
  if ! dart analyze lib; then ok=1; fi
  echo "--- ancestry: $BASE_SHA must be an ancestor of HEAD ---"
  if git merge-base --is-ancestor "$BASE_SHA" HEAD; then
    echo "ancestor exit=0  HEAD=$(git rev-parse HEAD)"
  else
    echo "ANCESTRY FAILED: $BASE_SHA is not an ancestor of HEAD"
    ok=1
  fi
  # NEGATIVE CONTROL for the ancestry check itself. `--is-ancestor` must
  # DISCRIMINATE DIRECTION: HEAD is ahead of the base, so the reversed question
  # has to answer no. An ancestry gate that says yes both ways is not a gate,
  # and this programme runs a deploy-lineage rule on exactly this command.
  if git merge-base --is-ancestor HEAD "$BASE_SHA"; then
    echo "ANCESTRY NEG CONTROL FAILED: HEAD was accepted as an ancestor of the"
    echo "base as well, so the check above discriminates nothing"
    ok=1
  else
    echo "ancestry neg control ok (reversed question correctly rejected)"
  fi
  return $ok
}

run_buildsha() {
  # V-1 reads `buildSha` off the on-device capture header. The key is a
  # compile-time String.fromEnvironment, so the plain M6 run exercises only the
  # "omitted when undefined" branch. This item compiles the SAME file with the
  # define set and requires the header to carry it.
  local sha
  sha="$(git rev-parse HEAD)"
  flutter test --dart-define="JEEB_BUILD_SHA=$sha" \
    test/mb1/m6_diag_instrument_test.dart
}

run_kept() {
  # W1.1c is the one member item whose claim is about OTHER TESTS, so asserting
  # its shape from source is not enough — the two kept files have to actually
  # RUN. `m9_*` counts the cases and pins the fakes against the surviving
  # capability; the two kept files themselves are what prove those cases pass.
  # Running them here rather than leaving them to the full-suite delta means a
  # rework that compiles but reds names ITSELF as M9 instead of hiding in a
  # 3700-test summary.
  flutter test \
    test/mb1/m9_kept_tests_rework_test.dart \
    test/features/live_tracking/live_tracking_push_driven_test.dart \
    test/features/live_tracking/tracking_live_position_overlay_test.dart
}

run_device() {
  cat <<'EOF'
BLOCKED BY CONSTRUCTION — this item is not a missing test, it is a claim no
host suite can settle. Per GATE.md §3 these are `device` / `capture` class:

  * W1.4 / R1: the APK must be built from the MERGED sha and its buildSha
    matched on the handset (DEVICE-BUILD.md §1 step 3). There is no APK here.
  * V-2: >=3 distinct jeeberPosition values inside ONE foreground dwell, with
    the screen-entry count == 1 and >=1 push-attributed update. M6 ships the
    instrument AND the predicate, and proves the predicate rejects the
    re-entry shape -- but the numbers come from a capture, not from a VM.
  * V-2: `offer_accepted` in the s24 shade while backgrounded. A shade is an
    OS surface; `Firebase.apps` is empty in every host test (M7.b asserts it),
    so no push transport is ever constructed here.
  * V-2: user-switch push -- one addressed to B lands, one addressed to A does
    not. M4 proves the CLIENT issues the register hop; arrival is the
    predicate and a registration-row flip proves an upsert, not arrival.
  * V-2: the 6-min zero-stream window, and V-1's recorder-DB rows. M1 proves
    no cadence inside a fakeAsync zone; only a recorder capture proves nothing
    left the handset.

Reported BLOCKED, which GATE.md §4 treats as VOID, which counts as FAIL for
closing a gate. It is deliberately NOT reported PASS.
EOF
  return 0
}

for row in "${ITEMS[@]}"; do
  IFS='|' read -r id desc how <<<"$row"
  want "$id" || continue
  echo
  echo "============================================================"
  echo "$id  $desc"
  echo "============================================================"
  case "$how" in
    __gate__)     run_gate; rc=$? ;;
    __buildsha__) run_buildsha; rc=$? ;;
    __kept__)     run_kept; rc=$? ;;
    __device__)   run_device; rc=99 ;;
    *)            flutter test "$how"; rc=$? ;;
  esac
  if [[ $rc -eq 99 ]]; then
    BLOCKED=$((BLOCKED+1)); RESULTS+=("BLOCKED $id  $desc")
    echo ">>> $id BLOCKED"
  elif [[ $rc -eq 0 ]]; then
    PASS=$((PASS+1)); RESULTS+=("PASS    $id  $desc")
    echo ">>> $id PASS"
  else
    FAIL=$((FAIL+1)); RESULTS+=("FAIL    $id  $desc")
    echo ">>> $id FAIL (rc=$rc)"
  fi
done

echo
echo "============================================================"
echo "MB1 PACK SUMMARY"
echo "============================================================"
for r in "${RESULTS[@]}"; do echo "$r"; done
echo
echo "$FAIL item(s) FAIL, $BLOCKED BLOCKED, $((PASS+FAIL+BLOCKED)) total"

if [[ $FAIL -gt 0 ]]; then exit 1; fi
if [[ $BLOCKED -gt 0 ]]; then exit 2; fi
exit 0
