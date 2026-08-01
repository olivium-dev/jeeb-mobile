#!/usr/bin/env bash
# MB1 — SUITE DELTA, by failure NAME.
#
# MB1's test pack section: "Scored on DELTA. Capture `flutter test` and
# `dart analyze lib` on origin/main BEFORE the first edit; a failure name
# present in the baseline is not a regression, a NEW name is."
#
# V-1's contract restates it: "flutter test compared to the pre-edit baseline by
# failure NAME, not by count."
#
# ---------------------------------------------------------------------------
# WHY A SCRIPT AND NOT A NUMBER
# ---------------------------------------------------------------------------
# A pass/fail COUNT cannot answer the question. "3 fail before, 4 fail after"
# is consistent with one new regression AND with one pre-existing failure being
# fixed while two new ones appear. Only the NAME SET distinguishes them, and
# only a set difference makes the answer auditable by someone who did not watch
# the run. This programme has already booked one wrong answer of exactly this
# shape (CB3/CB1's "122 vs 141": an attribute count reported as a test count).
#
# ---------------------------------------------------------------------------
# WHAT IT DOES
# ---------------------------------------------------------------------------
#   1. Creates a DETACHED worktree at the base SHA, as a SIBLING of this one,
#      because pubspec.yaml resolves `omds` through `../omds-flutter` and any
#      other location silently fails `pub get`.
#   2. Runs the full suite in BOTH trees with `--reporter json`, and extracts
#      the fully-qualified name of every test whose result is `error`/`failure`.
#   3. Prints three sets: BASELINE-ONLY (fixed or flaked out), COMMON (not a
#      regression, by MB1's own rule), and BRANCH-ONLY (**the regressions**).
#   4. Exits 1 if BRANCH-ONLY is non-empty, 0 otherwise.
#
# It NEVER deletes a branch. `git worktree add --detach` creates none, and the
# teardown is `git worktree remove`, which removes a directory and a
# registration -- see the standing hard exception in OWNER-DECISIONS.md.
#
#   tool/mb1/suite-delta.sh              run both sides (slow: two full suites)
#   tool/mb1/suite-delta.sh --branch     run the branch side only
#   tool/mb1/suite-delta.sh --keep       leave the base worktree in place

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$ROOT" || exit 1

# Re-pointed 2026-08-01 when the MB1 work moved from `b05/mb1` (cut at 30d12f1a)
# onto `b05/mb1-a3`, which is cut from current `origin/main`. Scoring the a3 line
# against 30d12f1a would book every commit main took in between as an MB1
# regression.
BASE_SHA="e45794f6db41f7977ed07dc444eccb6ee75780b2"   # origin/main
BASE_WT="$(cd "$ROOT/.." && pwd)/wt-mb1a3-base"
OUT="${TMPDIR:-/tmp}/mb1-suite-delta"
mkdir -p "$OUT"

BRANCH_ONLY=0
KEEP=0
for arg in "$@"; do
  case "$arg" in
    --branch) BRANCH_ONLY=1 ;;
    --keep)   KEEP=1 ;;
  esac
done

# names <json-file>  -> one fully-qualified failing test name per line
names() {
  python3 - "$1" <<'PY'
import io, json, sys
tests, failed = {}, set()
for line in io.open(sys.argv[1], encoding='utf-8', errors='replace'):
    line = line.strip()
    if not line.startswith('{'):
        continue
    try:
        e = json.loads(line)
    except ValueError:
        continue
    if e.get('type') == 'testStart':
        t = e['test']
        # skip the synthetic "loading …" tests the runner emits per suite
        if t.get('name', '').startswith('loading '):
            continue
        tests[t['id']] = t.get('name', '?')
    elif e.get('type') == 'testDone' and e.get('result') in ('error', 'failure'):
        if e['testID'] in tests:
            failed.add(tests[e['testID']])
    elif e.get('type') == 'error' and e.get('testID') in tests:
        failed.add(tests[e['testID']])
for n in sorted(failed):
    print(n)
PY
}

run_suite() {
  local dir="$1" tag="$2"
  echo "--- full suite in $dir  (tag=$tag) ---"
  ( cd "$dir" && flutter test --reporter json ) >"$OUT/$tag.json" 2>"$OUT/$tag.err"
  local rc=$?
  names "$OUT/$tag.json" >"$OUT/$tag.names"
  echo "    exit=$rc   failing names: $(wc -l <"$OUT/$tag.names" | tr -d ' ')"
  echo "    raw json: $OUT/$tag.json"
}

echo "============================================================"
echo "BRANCH  $(git rev-parse HEAD)"
run_suite "$ROOT" branch

if [[ $BRANCH_ONLY -eq 1 ]]; then
  echo; echo "branch-side failing names:"; cat "$OUT/branch.names"
  exit 0
fi

echo "============================================================"
echo "BASE    $BASE_SHA"
if [[ ! -d "$BASE_WT" ]]; then
  git worktree add --detach "$BASE_WT" "$BASE_SHA" || exit 1
fi
( cd "$BASE_WT" && flutter pub get >/dev/null 2>&1 )
run_suite "$BASE_WT" base

echo
echo "============================================================"
echo "DELTA BY NAME"
echo "============================================================"
echo "--- COMMON (present in the baseline -> NOT a regression, MB1's rule) ---"
comm -12 "$OUT/base.names" "$OUT/branch.names"
echo "--- BASELINE ONLY (gone on the branch) ---"
comm -23 "$OUT/base.names" "$OUT/branch.names"
echo "--- BRANCH ONLY  ***THESE ARE THE REGRESSIONS*** ---"
comm -13 "$OUT/base.names" "$OUT/branch.names" | tee "$OUT/new.names"

[[ $KEEP -eq 1 ]] || git worktree remove --force "$BASE_WT" 2>/dev/null

n="$(wc -l <"$OUT/new.names" | tr -d ' ')"
echo
echo "$n NEW failure name(s)"
[[ "$n" -eq 0 ]] || exit 1
exit 0
