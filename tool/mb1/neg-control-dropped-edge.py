#!/usr/bin/env python3
"""Apply ONE mutation that removes half of the ported `0ad2752` fix.

Driven by tool/mb1/neg-control-dropped-edge.sh. Every replacement is a LITERAL
exact-match on the shipped source; if the source moves, the match fails and the
script fails loudly rather than silently "passing" a mutation it never applied.

Usage: neg-control-dropped-edge.py <N1|N2|N3> <cubit_path> <repo_path>
Exit 0 = mutation applied. Exit 1 = literal not found (script is stale).
"""
import sys


def sub(path, old, new, label):
    with open(path, encoding="utf-8") as fh:
        src = fh.read()
    n = src.count(old)
    if n != 1:
        print(f"  literal for {label} matched {n} times, expected exactly 1")
        return False
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(src.replace(old, new))
    return True


N1_GUARD_OLD = """    if (isClosed || _isTerminal) return;
    if (_statusReadInFlight) {
      _pendingPushEdge = true;
      return;
    }
    _statusReadInFlight = true;"""
N1_GUARD_NEW = """    if (isClosed || _isTerminal || _statusReadInFlight) return;
    _statusReadInFlight = true;"""

N1_DRAIN_OLD = """    if (!_pendingPushEdge) return;
    _pendingPushEdge = false;
    await _refreshFromPush();"""
N1_DRAIN_NEW = """    _pendingPushEdge = false;"""

N2_GUARD_OLD = """    if (_positionReadInFlight) {
      // Coalesce onto the trailing edge instead of dropping the cause. See
      // [_pendingPositionCause] — the LAST cause wins, because it is the most
      // recent reason to believe the marker is stale.
      _pendingPositionCause = cause;
      return;
    }"""
N2_GUARD_NEW = """    if (_positionReadInFlight) return;"""

N2_DRAIN_OLD = """    final pending = _pendingPositionCause;
    if (pending == null) return;
    _pendingPositionCause = null;
    await _readLivePosition(pending);"""
N2_DRAIN_NEW = """    _pendingPositionCause = null;"""

N3_OLD = """    } catch (_) {"""
N3_NEW = """    } on _NeverThrownByTheParser {"""

N3_SHIM = """
/// Negative-control shim: a type nothing ever throws, so the bare `catch` the
/// mutation replaced can no longer swallow a `TypeError`.
class _NeverThrownByTheParser implements Exception {}
"""


def main():
    if len(sys.argv) != 4:
        print(__doc__)
        return 1
    which, cubit, repo = sys.argv[1], sys.argv[2], sys.argv[3]

    if which == "N1":
        ok = sub(cubit, N1_GUARD_OLD, N1_GUARD_NEW, "N1 guard")
        ok = sub(cubit, N1_DRAIN_OLD, N1_DRAIN_NEW, "N1 drain") and ok
        return 0 if ok else 1
    if which == "N2":
        ok = sub(cubit, N2_GUARD_OLD, N2_GUARD_NEW, "N2 guard")
        ok = sub(cubit, N2_DRAIN_OLD, N2_DRAIN_NEW, "N2 drain") and ok
        return 0 if ok else 1
    if which == "N3":
        if not sub(repo, N3_OLD, N3_NEW, "N3 catch"):
            return 1
        with open(repo, "a", encoding="utf-8") as fh:
            fh.write(N3_SHIM)
        return 0

    print(f"unknown mutation {which}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
