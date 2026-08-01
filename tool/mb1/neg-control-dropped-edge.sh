#!/usr/bin/env bash
# MB1 — NEGATIVE CONTROLS for the ported `0ad2752` fix.
#
# A passing test proves nothing on its own: it may be passing because the
# assertion is vacuous. Each mutation below REMOVES one half of the fix, re-runs
# the guarding test file, and requires it to go RED. If a mutation leaves the
# suite green, that guard is self-fulfilling and must be rewritten.
#
#   N1  drop the coalesced push edge in `_refreshFromPush`
#         -> tracking_dropped_push_edge_test.dart MUST fail
#   N2  drop the coalesced cause in `_readLivePosition`
#         -> tracking_dropped_push_edge_test.dart MUST fail
#   N3  remove the bare `catch` in `DioLiveTrackingRepository.fetchLivePosition`
#         -> tracking_position_read_totality_test.dart MUST fail
#
# Usage:  bash tool/mb1/neg-control-dropped-edge.sh
# Exit 0 = every mutation was DETECTED. Exit 1 = at least one guard is blind.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

CUBIT="lib/features/live_tracking/application/live_tracking_cubit.dart"
REPO="lib/features/live_tracking/data/dio_live_tracking_repository.dart"
T_EDGE="test/features/live_tracking/tracking_dropped_push_edge_test.dart"
T_TOTAL="test/features/live_tracking/tracking_position_read_totality_test.dart"

BAK="$(mktemp -d)"
cp "$CUBIT" "$BAK/cubit.dart"
cp "$REPO" "$BAK/repo.dart"
restore() { cp "$BAK/cubit.dart" "$CUBIT"; cp "$BAK/repo.dart" "$REPO"; }
trap 'restore; rm -rf "$BAK"' EXIT

FAILED=0

# $1 = mutation id, $2 = human name, $3 = test file
run_mutation() {
  local id="$1" name="$2" testfile="$3"
  echo
  echo "=== $id  $name"
  if ! python3 "$ROOT/tool/mb1/neg-control-dropped-edge.py" "$id" "$CUBIT" "$REPO"; then
    echo "FAIL[$id]: could not apply the mutation (the source moved). Fix this script."
    FAILED=1
    restore
    return
  fi
  if flutter test "$testfile" >/dev/null 2>&1; then
    echo "FAIL[$id]: the suite stayed GREEN with the fix removed."
    echo "          -> $testfile does NOT actually guard '$name'."
    FAILED=1
  else
    echo "OK  [$id]: detected — $testfile went RED with the fix removed."
  fi
  restore
}

run_mutation N1 "drop the coalesced push edge (_refreshFromPush)" "$T_EDGE"
run_mutation N2 "drop the coalesced cause (_readLivePosition)"    "$T_EDGE"
run_mutation N3 "remove the bare catch (fetchLivePosition)"       "$T_TOTAL"

echo
echo "=== BASELINE: restored source must be GREEN again"
if flutter test "$T_EDGE" "$T_TOTAL" >/dev/null 2>&1; then
  echo "OK  [B0]: restored source is green."
else
  echo "FAIL[B0]: restore left the tree red."
  FAILED=1
fi

echo
if [ "$FAILED" -eq 0 ]; then
  echo "ALL NEGATIVE CONTROLS DETECTED."
else
  echo "AT LEAST ONE NEGATIVE CONTROL WAS NOT DETECTED."
fi
exit "$FAILED"
