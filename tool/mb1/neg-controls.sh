#!/usr/bin/env bash
# MB1 negative controls — break the code, watch the NAMED test go red, restore.
#
# GATE.md §7: "A test that cannot fail is not evidence." Every control below
# mutates ONE thing in the production tree, re-runs the ONE pack file that is
# supposed to notice, and requires (a) a non-zero exit and (b) the EXPECTED TEST
# NAME in the failure output. Requiring the name is what distinguishes "the file
# went red" from "the right assertion went red" — a mutation that reds a
# different case in the same file is a miss, not a hit.
#
# Then it restores and re-runs, and requires green again. A control that leaves
# the tree broken has manufactured a false FAIL for whoever runs next.
#
#   tool/mb1/neg-controls.sh          # all controls
#   tool/mb1/neg-controls.sh N05      # one control
#
# ---------------------------------------------------------------------------
# THE HAZARD THIS SCRIPT IS WRITTEN AGAINST — read before changing the restore
# ---------------------------------------------------------------------------
# OWNER-DECISIONS.md, 2026-07-31 10:32Z records a traceless false FAIL on DT0
# manufactured by a sibling harness. Its backup used `cp -p` and its restore
# used `mv -f`: `cp -p` PRESERVES mtime and `mv` carries it back, so after the
# episode `stat` reported the file as never having changed. An investigator who
# reaches for mtime is told "no" and that answer is WRONG.
#
# Three deliberate differences here:
#   1. `cp` WITHOUT `-p`. The mtime is allowed to move, so a forensic question
#      about "did this file change?" has a truthful answer.
#   2. An exclusive lock held for the WHOLE mutation window, so a second copy of
#      this script blocks instead of interleaving. It is a `mkdir` lock, not
#      `flock`: flock(1) is util-linux and is absent from a stock macOS, so a
#      flock-based guard would silently degrade to NO GUARD on the very machine
#      this programme runs on. (OWNER-DECISIONS ruling: implement the shared
#      exclusive lock. This is that lock, on the MB1 side.)
#   3. sha256 verified after every restore, and an EXIT trap that restores even
#      on SIGINT. If a restore ever fails to reproduce the original digest the
#      script stops immediately rather than continuing to mutate.
set -uo pipefail

cd "$(dirname "$0")/../.." || exit 1
# Portable exclusive lock. `flock(1)` is a Linux util-linux tool and is NOT on a
# stock macOS; this harness must not silently run WITHOUT a lock on the machine
# it was written on. `mkdir` is atomic on every POSIX filesystem, so it is the
# lock, and flock is used only when it happens to exist.
LOCKDIR=".mb1-neg-controls.lock.d"
if ! mkdir "$LOCKDIR" 2>/dev/null; then
  echo "another neg-controls run holds $LOCKDIR; refusing to interleave" >&2
  echo "(if no run is live, remove it: rmdir $LOCKDIR)" >&2
  exit 1
fi

ONLY="${1:-}"
BACKUP_DIR="$(mktemp -d)"
CUR_FILE=""
behaved=0; misbehaved=0; misbehaved_ids=()

restore_current() {
  [[ -n "$CUR_FILE" ]] || return 0
  cp "$BACKUP_DIR/$(echo "$CUR_FILE" | tr / _)" "$CUR_FILE"
  CUR_FILE=""
}
trap 'restore_current; rm -rf "$BACKUP_DIR"; rmdir "$LOCKDIR" 2>/dev/null' EXIT INT TERM

# control <id> <file> <perl-expr> <test-file> <expected-test-name-fragment> <what>
control() {
  local id="$1" file="$2" expr="$3" testfile="$4" name="$5" what="$6"
  [[ -n "$ONLY" && "$ONLY" != "$id" ]] && return 0

  local bak="$BACKUP_DIR/$(echo "$file" | tr / _)"
  cp "$file" "$bak"
  local before; before="$(shasum -a 256 "$file" | cut -d' ' -f1)"
  CUR_FILE="$file"

  # BASELINE: the test must be PASSING before we break anything. A control whose
  # subject was already red proves nothing and must be reported VOID, not "ok".
  if ! flutter test "$testfile" -r compact >/dev/null 2>&1; then
    printf '%-5s VOID       %s\n' "$id" "$what — baseline was already RED"
    misbehaved=$((misbehaved+1)); misbehaved_ids+=("$id")
    restore_current; return 0
  fi

  perl -0pi -e "$expr" "$file"
  if [[ "$(shasum -a 256 "$file" | cut -d' ' -f1)" == "$before" ]]; then
    printf '%-5s VOID       %s — the mutation did not change the file\n' "$id" "$what"
    misbehaved=$((misbehaved+1)); misbehaved_ids+=("$id")
    restore_current; return 0
  fi

  # NO PIPELINE around the match. `set -o pipefail` + `grep -q` is a silent
  # false-negative generator, and it cost two controls a bogus WRONG-CASE
  # verdict here before it was found:
  #
  #   `tr '\r' '\n' <out | grep -qF "$name"`
  #
  # `grep -q` exits 0 the instant it matches and closes the pipe; `tr` is still
  # writing, takes SIGPIPE, and exits 141; `pipefail` reports the rightmost
  # NON-ZERO status, so the pipeline is 141 and the `if` is FALSE — on a match.
  # It is load-bearing that this is SIZE-DEPENDENT: with a small capture `tr`
  # finishes before `grep` quits and the bug is invisible, so 18 of 20 controls
  # behaved and the only two that did not were the two whose failure output
  # dumps a whole source file into `Actual:`. A harness bug that fires only on
  # the biggest failures is exactly the shape that gets mistaken for a real
  # finding.
  #
  # Normalise to a file first (the compact reporter overwrites its progress line
  # with CARRIAGE RETURNS, so an un-normalised capture is one enormous line),
  # then grep the file. No pipe, no SIGPIPE, no pipefail interaction.
  local rc named=0
  local outfile="$BACKUP_DIR/out.txt"
  flutter test "$testfile" -r compact >"$outfile" 2>&1; rc=$?
  tr '\r' '\n' <"$outfile" >"$outfile.norm"
  if grep -qF "$name" "$outfile.norm"; then named=1; fi

  cp "$bak" "$file"; CUR_FILE=""
  local after; after="$(shasum -a 256 "$file" | cut -d' ' -f1)"
  if [[ "$after" != "$before" ]]; then
    echo "FATAL: restore of $file did not reproduce $before — STOPPING" >&2
    exit 3
  fi

  if [[ $rc -ne 0 && $named -eq 1 ]]; then
    # And green again after the restore, so the red is attributable to the
    # mutation rather than to anything ambient.
    if flutter test "$testfile" -r compact >/dev/null 2>&1; then
      printf '%-5s ok         %s\n' "$id" "$what"
      printf '      %s -> RED, restored -> GREEN\n' "$name"
      behaved=$((behaved+1))
    else
      printf '%-5s VOID       %s — still red AFTER restore\n' "$id" "$what"
      misbehaved=$((misbehaved+1)); misbehaved_ids+=("$id")
    fi
  elif [[ $rc -eq 0 ]]; then
    printf '%-5s DID-NOT    %s — the file stayed GREEN under the mutation\n' "$id" "$what"
    misbehaved=$((misbehaved+1)); misbehaved_ids+=("$id")
  else
    printf '%-5s WRONG-CASE %s — red, but not "%s"\n' "$id" "$what" "$name"
    misbehaved=$((misbehaved+1)); misbehaved_ids+=("$id")
  fi
}

# The forbidden literals, ASSEMBLED. This script is a tracked file and the DOC
# receipt greps every tracked file of every extension, so spelling either token
# here would red the very row these controls exist to prove is red-able. The
# first draft of this file did exactly that.
ALIAS="geo/jeeb""/stream"
BACKOFF="kPosition""RearmBackoff"

CUBIT=lib/features/live_tracking/application/live_tracking_cubit.dart
INSTR=test/features/live_tracking/tracking_diag_instrument_test.dart
RECEIPT=test/features/live_tracking/sse_teardown_grep_receipt_test.dart
DOCTEST=test/mb1/mb1_doc_residual_receipts_test.dart

echo "MB1 negative controls @ $(git rev-parse --short HEAD)"
echo "ID    RESULT     CONTROL"
echo "----- ---------- ---------------------------------------------------------"

# --- W1.1: the wire and the teardown -------------------------------------
control N01 "$CUBIT" \
  's{await source\.fetchLivePosition\(deliveryId: deliveryId\)}{null}' \
  "$RECEIPT" "call expression in lib/" \
  "W1.1 orphan the production call site (the pre-MB1 P0 state)"

control N02 lib/features/live_tracking/domain/delivery_tracking_info.dart \
  "s{/// GET /deliveries/\{id\}/tracking\.}{/// GET /deliveries/{id}/tracking and GET /v1/$ALIAS/{id}.}" \
  "$RECEIPT" "appears in 0 files under lib/ + test/" \
  "W1.1 re-introduce the deleted alias in a DOC COMMENT"

control N03 "$CUBIT" \
  's{\Aimport}{void _mb1NegControlCadence() {\n  Timer.periodic(const Duration(seconds: 5), (_) {});\n}\nimport}' \
  "$RECEIPT" "no Timer / Future.delayed in the live_tracking feature" \
  "W1.1 re-arm a cadence inside the feature"

# NOTE: the first spelling of this control renamed the class to
# `LivePositionSourceRenamed` and the receipt stayed GREEN — because a substring
# lens still matches a SUPERSTRING. The control was wrong, not the receipt. The
# rename below produces a name that does not contain the original.
control N04 lib/features/live_tracking/domain/live_tracking_repository.dart \
  's{LivePositionSource}{LivePosCapability}g' \
  "$RECEIPT" "is still PRESENT (a zero here is the FAILURE)" \
  "W1.1 delete the type MB1 exists to wire (the grep-driven false pass)"

# --- W1.1b: the instrument ------------------------------------------------
control N05 "$CUBIT" \
  's{    Diag\.event\(kTrackingScreenOpenEvent, <String, Object\?>\{\n      .deliveryId.: deliveryId,\n    \}\);\n}{}' \
  "$INSTR" "exactly ONE per cubit construction" \
  "W1.1b delete the screen_open emission (the denominator)"

control N06 "$CUBIT" \
  "s{'applied': applied,}{'applied': true,}" \
  "$INSTR" "applied:false" \
  "W1.1b hardcode applied:true (a dropped merge counted as a marker)"

control N07 "$CUBIT" \
  "s{'cause': cause\.wire,}{'cause': 'open',}" \
  "$INSTR" "screen open -> open; push -> push" \
  "W1.1b hardcode cause:'open' (push attribution becomes unprovable)"

# NOTE: the first spelling anchored on `'authorization',`, which appears TWICE
# in this file — once in the HEADER set and once in kSensitiveDataKeys — and
# perl's s/// without /g replaces the FIRST. The mutation landed in the wrong
# set and the instrument correctly stayed green. `'accesstoken',` is unique.
control N08 lib/core/diagnostics/diag_redaction.dart \
  "s|'accesstoken',|'accesstoken',\\n  'lat',|" \
  "$INSTR" "coordinates are NOT redacted" \
  "W1.1b redact lat (MARKER leg silently unmeasurable, everything else green)"

control N09 "$CUBIT" \
  's{if \(overlay != null\) _positionReadCount\+\+;}{}' \
  test/features/live_tracking/tracking_live_position_overlay_test.dart \
  "overlays the jeeber position onto the stage snapshot" \
  "W1.1c drop the arrival counter the KEPT overlay test pins"

# --- W1.1c: the kept files ------------------------------------------------
control N10 test/features/live_tracking/tracking_live_position_overlay_test.dart \
  "s{'DioLiveTrackingRepository.fetchLivePosition parses the tracking '}{'a renamed case '}" \
  test/mb1/mb1_w1_1c_kept_tests_test.dart \
  "payload-adequacy pack survived, by NAME" \
  "W1.1c lose a payload-adequacy case in the rework"

# --- W1.2: FCM re-registration -------------------------------------------
control N11 lib/core/notifications/data/device_token_registrar.dart \
  's{final key = _key\(uid, token\);}{final key = _key(null, token);}' \
  test/mb1/mb1_w1_2_fcm_reregistration_test.dart \
  "A out, B in on the same instance" \
  "W1.2 dedup on the TOKEN alone (JEBV4-159: user B never registers)"

control N12 lib/app/app.dart \
  's{if \(registrar != null\) unawaited\(registrar\.notifyLogin\(\)\);}{if (registrar != null) {}}' \
  test/mb1/mb1_w1_2_fcm_reregistration_test.dart \
  "notifyLogin() on the AUTHENTICATED arm" \
  "W1.2 unwire the login trigger (run-15 root cause)"

# --- W4.1: the gallery pick ----------------------------------------------
control N13 lib/core/di/injection_container.dart \
  's{\(\) => ImagePickerPhotoPickerService\(\),}{() => StubPhotoPickerService(),}' \
  test/mb1/mb1_w4_1_gallery_pick_test.dart \
  "resolves to ImagePickerPhotoPickerService" \
  "W4.1 bind the STUB in DI (synthetic bytes, no OS gallery)"

control N14 lib/features/chat/presentation/chat_screen.dart \
  's{    if \(sl\.isRegistered<PhotoPickerService>\(\)\) return sl<PhotoPickerService>\(\);\n    return StubPhotoPickerService\(\);}{    return StubPhotoPickerService();}' \
  test/mb1/mb1_w4_1_gallery_pick_test.dart \
  "DI FIRST, stub only as fallback" \
  "W4.1 resolve the stub BEFORE consulting DI (P4/P5)"

# --- DOC: the repo-wide residual predicate --------------------------------
# The control that proves the two lenses are NOT the same instrument.
control N15 README.md \
  "s{\\A}{<!-- GET /v1/$ALIAS/{id} -->\\n}" \
  "$DOCTEST" "appears in 0 tracked files (any extension)" \
  "DOC a residual in a NON-DART tracked file (W1.1's lens cannot see this)"

control N16 android/app/src/debug/res/xml/network_security_config.xml \
  "s{\\A}{<!-- $BACKOFF -->\\n}" \
  "$DOCTEST" "appears in 0 tracked files (any extension)" \
  "DOC a residual in an Android XML resource"

# --- OWN2: the DevTool preset --------------------------------------------
control N17 lib/devtool/dev_settings_page.dart \
  "s{  kMsiGatewayBaseUrl,\n  'http://10\.0\.2\.2:4010',}{  'http://10.0.2.2:4010',\n  kMsiGatewayBaseUrl,}" \
  test/devtool/dev_server_url_presets_test.dart \
  "MSI is present and is FIRST" \
  "OWN2 demote MSI out of first place"

control N18 lib/devtool/dev_settings_page.dart \
  "s{'https://api\.jeeb\.app/v1',}{'http://192.168.2.50:10090',}" \
  test/devtool/dev_server_url_presets_test.dart \
  "no preset points at the banned .50 host" \
  "OWN2 point a preset at the banned .50 host"

# --- W1.4: the build line -------------------------------------------------
# Both of these APPEND (`\z`), they do not prepend (`\A`).
#
# A Dart declaration inserted ABOVE the imports is a compile error —
# "Directives must appear before any declarations" — so the test file fails to
# LOAD and the run is red for the wrong reason: the assertion never executes and
# its name never reaches the output, which this harness reports as WRONG-CASE.
# N20 did exactly that, and the diagnosis was masked twice: once by the compile
# error looking like a plausible red, and once by a patch whose search string
# did not match, so the "fix" was a silent no-op and the symptom persisted
# unchanged. Both are on the record because a control that reds for the wrong
# reason is worse than no control.
control N19 lib/features/registration/presentation/super_login/super_login_entry_points.dart \
  's{\z}{\n// ignore: unused_element\nString mb1NegControlReader() => AppConfig.gatewayBaseUrl;\n}' \
  test/mb1/mb1_w1_4_build_line_test.dart \
  "ZERO readers in lib/ outside its declaration" \
  "W1.4 add a reader of GATEWAY_BASE_URL (build line now points at prod)"

control N20 lib/core/dev_flags.dart \
  "s{\\z}{\nconst String mb1NegControlHost = 'http://192.168.2.50:10090';\n}" \
  test/mb1/mb1_w1_4_build_line_test.dart \
  "no lib/ source hardcodes the banned .50 host" \
  "W1.4 hardcode the banned .50 host in lib/"

echo "----- ---------- ---------------------------------------------------------"
echo "$behaved control(s) behaved, $misbehaved did not"
[[ ${#misbehaved_ids[@]} -gt 0 ]] && echo "did not behave: ${misbehaved_ids[*]}"
echo
echo "R1's own controls are INSIDE its reader (10 of them, one per leg plus the"
echo "empty-capture trap):  python3 tool/mb1/r1-check.py --selftest"
exit $(( misbehaved > 0 ? 1 : 0 ))
