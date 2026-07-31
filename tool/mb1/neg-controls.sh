#!/usr/bin/env bash
# MB1 TEST PACK — NEGATIVE CONTROLS.
#
# "A test that cannot fail is not evidence" (GATE.md §7). Each control below
# breaks ONE thing, asserts the ONE pack item that owns it goes red, restores,
# and asserts the item goes green again AND the file is byte-identical to what
# it was.
#
#   tool/mb1/neg-controls.sh            run every control
#   tool/mb1/neg-controls.sh N4 N6      run only those
#   tool/mb1/neg-controls.sh --list     show control -> item mapping
#
# Exit 0 = every control behaved (red when broken, green when restored)
#      1 = at least one control did not behave
#
# ---------------------------------------------------------------------------
# TWO HAZARDS THIS SCRIPT IS BUILT AROUND, both recorded in
# docs/execution/OWNER-DECISIONS.md (2026-07-31 10:32Z):
#
# 1. A mutation left behind manufactures a FAIL on the NEXT agent's run, and
#    that FAIL is specific, plausible, correctly formatted and indistinguishable
#    from a real regression. Every control restores in a trap, the restore is
#    verified by CONTENT HASH, and the script ends by printing `git status`.
# 2. `cp -p` + `mv -f` PRESERVES mtime, so an investigator who asks "did this
#    file change?" via mtime is told no — and that answer is wrong. This script
#    uses a plain `cp` and a plain overwrite, so a mutation window IS visible in
#    mtime, and it never trusts mtime to decide anything.
#
# TOKEN ASSEMBLY (same rule as the Dart pack): the controls that re-introduce a
# banned token build it from shell fragments, so `git grep <dead token>` over
# the whole repo still returns 0 with this file committed. Spelling one out here
# would break the very count MB1's V-1 runs.
# ---------------------------------------------------------------------------

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$ROOT" || exit 1

BAK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mb1-negctl.XXXXXX")"
MUTATED=""

restore_all() {
  if [[ -n "$MUTATED" ]]; then
    cp "$BAK_DIR/restore.bak" "$MUTATED"
    MUTATED=""
  fi
}
trap 'restore_all' EXIT INT TERM

CUBIT="lib/features/live_tracking/application/live_tracking_cubit.dart"
CHATCUBIT="lib/features/chat/application/chat_cubit.dart"
REGISTRAR="lib/core/notifications/data/device_token_registrar.dart"
REPO="lib/features/live_tracking/data/dio_live_tracking_repository.dart"
SINK="lib/core/diagnostics/diag_file_sink.dart"

# Assembled so this file never carries the banned literal contiguously.
TOK_SSE="SseLivePosition""Stream"
TOK_FIRESTORE="cloud_""firestore"

# mutate <file> <old> <new>   — exact-substring replace, exactly once.
mutate() {
  OLD="$2" NEW="$3" python3 - "$1" <<'PY'
import io, os, sys
path = sys.argv[1]
old, new = os.environ['OLD'], os.environ['NEW']
s = io.open(path, encoding='utf-8').read()
n = s.count(old)
if n != 1:
    sys.stderr.write('MUTATION TARGET NOT UNIQUE (%d matches) in %s: %r\n'
                     % (n, path, old))
    sys.exit(3)
io.open(path, 'w', encoding='utf-8').write(s.replace(old, new))
PY
}

# prepend_line <file> <line>
prepend_line() {
  LINE="$2" python3 - "$1" <<'PY'
import io, os, sys
path = sys.argv[1]
s = io.open(path, encoding='utf-8').read()
io.open(path, 'w', encoding='utf-8').write(os.environ['LINE'] + '\n' + s)
PY
}

# run_control <ID> <ITEM> <FILE> <description> <mutation-command...>
run_control() {
  local id="$1" item="$2" file="$3" desc="$4"; shift 4
  echo
  echo "############################################################"
  echo "$id  -> expects $item to go RED   ($desc)"
  echo "############################################################"

  local before_hash after_hash rc
  before_hash="$(shasum -a 256 "$file" | awk '{print $1}')"
  cp "$file" "$BAK_DIR/restore.bak"
  MUTATED="$file"

  echo "--- baseline: $item must PASS before the mutation ---"
  if ! tool/mb1/run-pack.sh "$item" >"$BAK_DIR/$id.before" 2>&1; then
    echo "VOID: $item was NOT passing before the mutation, so this control"
    echo "proves nothing. (GATE.md: a control whose baseline is red is void.)"
    tail -5 "$BAK_DIR/$id.before"
    restore_all
    return 1
  fi

  if ! "$@"; then
    echo "VOID: the mutation itself failed to apply."
    restore_all
    return 1
  fi
  if [[ "$(shasum -a 256 "$file" | awk '{print $1}')" == "$before_hash" ]]; then
    echo "VOID: the mutation changed nothing. A control that does not mutate"
    echo "cannot prove a test can fail."
    restore_all
    return 1
  fi

  echo "--- mutated: $item must FAIL ---"
  tool/mb1/run-pack.sh "$item" >"$BAK_DIR/$id.after" 2>&1
  rc=$?
  # WHICH assertion went red. A control that reds "something" is far weaker
  # evidence than a control that reds the NAMED test that owns the claim.
  echo "    RED tests:"
  grep -oE "\-\-plain-name '[^']*'" "$BAK_DIR/$id.after" \
    | sed "s/--plain-name '/      * /; s/'$//" | sort -u | head -8
  grep -oE '^ +(warning|error) - [^ ]+ - [^-]+' "$BAK_DIR/$id.after" \
    | sed 's/^/      * /' | sort -u | head -4
  grep -E '^>>> ' "$BAK_DIR/$id.after" | head -2

  restore_all
  after_hash="$(shasum -a 256 "$file" | awk '{print $1}')"
  if [[ "$after_hash" != "$before_hash" ]]; then
    echo "RESTORE FAILED for $file — DO NOT COMMIT, the tree is dirty."
    return 1
  fi

  if [[ $rc -eq 0 ]]; then
    echo ">>> $id DID NOT BEHAVE: $item stayed GREEN with the code broken."
    return 1
  fi

  echo "--- restored: $item must PASS again ---"
  if ! tool/mb1/run-pack.sh "$item" >"$BAK_DIR/$id.restored" 2>&1; then
    echo ">>> $id DID NOT BEHAVE: $item is still red after restore."
    return 1
  fi
  echo ">>> $id BEHAVED (red when broken, green when restored, file identical)"
  return 0
}

n1() { run_control N1 M1 "$CUBIT" \
  "re-orphan fetchLivePosition — the frozen-marker P0 itself" \
  mutate "$CUBIT" 'await _readLivePosition(cause);' '/* NEGCTL */;'; }

n2() { run_control N2 M2 "$REPO" \
  "re-introduce a deleted symbol into lib/" \
  prepend_line "$REPO" "// NEGCTL $TOK_SSE"; }

n3() { run_control N3 M3 "$CHATCUBIT" \
  "erase the dated-as-history marker (T9 doctrine) without touching the token" \
  mutate "$CHATCUBIT" 'retained not deleted' 'quietly rewritten'; }

n4() { run_control N4 M4 "$REGISTRAR" \
  "token-only dedup key — the JEBV4-159 defect, restored exactly" \
  mutate "$REGISTRAR" "'\${userId ?? ''}::\$token'" "'::\$token'"; }

n5() { run_control N5 M5 "$CHATCUBIT" \
  "cross the gallery row onto the camera" \
  mutate "$CHATCUBIT" ': await _pickerService.pickFromGallery();' \
                      ': await _pickerService.pickFromCamera();'; }

n6() { run_control N6 M6 "$CUBIT" \
  "destroy push attribution in the diag record" \
  mutate "$CUBIT" "push('push')" "push('open')"; }

n7() { run_control N7 M7 "$CUBIT" \
  "introduce a Firestore reference into the tracking feature" \
  prepend_line "$CUBIT" "// NEGCTL $TOK_FIRESTORE"; }

n8() { run_control N8 M0 "$REPO" \
  "break the analyzer without breaking compilation (unused import)" \
  prepend_line "$REPO" "import 'dart:isolate';"; }

# N9 is what stops M6b from being tautological. M6b asserts the capture header
# carries `buildSha`; drop the header field and the DEFINED run must red while
# the UNDEFINED run (M6) stays green — which is exactly the asymmetry V-1's
# "read buildSha off the capture header" row depends on.
n9() { run_control N9 M6b "$SINK" \
  "drop buildSha from the capture header (V-1's identity row)" \
  mutate "$SINK" "      if (buildSha.isNotEmpty) 'buildSha': buildSha,
" ""; }

CONTROLS=(
  "N1|M1|re-orphan fetchLivePosition (the P0)"
  "N2|M2|re-introduce a deleted symbol"
  "N3|M3|erase the dated-as-history marker"
  "N4|M4|token-only dedup key (JEBV4-159)"
  "N5|M5|cross gallery onto camera"
  "N6|M6|destroy push attribution"
  "N7|M7|Firestore reference in the tracking feature"
  "N8|M0|analyzer red, compilation intact"
  "N9|M6b|buildSha dropped from the capture header"
)

if [[ "${1:-}" == "--list" ]]; then
  for row in "${CONTROLS[@]}"; do
    IFS='|' read -r id item desc <<<"$row"
    printf '%-3s -> %-3s %s\n' "$id" "$item" "$desc"
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

BEHAVED=0; MISBEHAVED=0; RESULT=()
for row in "${CONTROLS[@]}"; do
  IFS='|' read -r id item desc <<<"$row"
  want "$id" || continue
  if "$(echo "$id" | tr '[:upper:]' '[:lower:]')"; then
    BEHAVED=$((BEHAVED+1)); RESULT+=("BEHAVED     $id -> $item  $desc")
  else
    MISBEHAVED=$((MISBEHAVED+1)); RESULT+=("DID NOT     $id -> $item  $desc")
  fi
done

echo
echo "============================================================"
for r in "${RESULT[@]}"; do echo "$r"; done
echo "$BEHAVED control(s) behaved, $MISBEHAVED did not"
echo "============================================================"
echo "--- worktree cleanliness: a leftover mutation manufactures a false FAIL"
echo "--- on the next agent's run (OWNER-DECISIONS.md, 2026-07-31 10:32Z)"
git status --porcelain
[[ $MISBEHAVED -eq 0 ]] || exit 1
exit 0
