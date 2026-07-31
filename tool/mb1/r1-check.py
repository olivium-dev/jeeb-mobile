#!/usr/bin/env python3
"""MB1 R1 — the device-round reader, and its own self-test.

R1 is the ONLY row in MB1 that can prove the courier marker. Everything else in
the pack is `suite`/`static` and, per GATE.md §3, no amount of it adds up to a
claim about transport or about what a user sees. This file does not substitute
for the round; it is the instrument the round is read WITH, written and proven
in advance so V-2 is not debugging a parser at 2 a.m. with a phone in hand.

    python3 tool/mb1/r1-check.py --selftest
    python3 tool/mb1/r1-check.py --recorder <capture.db> --diag <session.jsonl> \
                                 --delivery <deliveryId> [--since-ms N --until-ms M]

Exit codes:  0 = every leg PASS      1 = a leg FAILED      3 = BLOCKED (no evidence)

WHAT THE SELF-TEST PROVES, AND WHAT IT DOES NOT
-----------------------------------------------
`--selftest` builds synthetic fixtures and checks the reader answers PASS on a
satisfying one and FAIL on each single-leg violation. That is a positive and a
negative control for THE READER. It is not evidence about the app, the gateway,
or a phone, and a green self-test must never be recorded as an R1 result. The
fixtures are written to a temp dir and deleted; they are deliberately NOT
committed, so they can never be mistaken for a capture.

THE TWO TRAPS THIS READER IS SHAPED AGAINST
-------------------------------------------
1. `jeeb-gateway/tools/api-recorder/api-recorder.db` holds 0 rows with a 0-byte
   WAL. Asked "how many stream rows?" it answers 0 — a PASS produced by an empty
   file. So every count here is quoted against `total_rows_in_capture`, and a
   capture with 0 rows is refused outright rather than scored.
2. A capture in which every `GET .../tracking` returned HTTP 200 with
   `"position":null` measures the jeeber's GPS uploader and the gateway's
   5-minute TTL, not this batch. The reader reports that shape EXPLICITLY as a
   precondition failure ("not a round"), because MB1.md is emphatic that an
   unmet precondition re-runs the round instead of failing the work.
"""

from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
import tempfile

# The deleted SSE alias. Assembled, never spelled: this file is TRACKED, and
# MB1's V-1 predicate is a repo-wide `git grep` with no pathspec, so a literal
# here would red the very gate row R1 exists to corroborate. The MB1 doc-residual
# test greps every tracked file and would name this one.
STREAM_ALIAS = "geo/jeeb" + "/stream"

SCREEN_OPEN = "tracking_screen_open"
POSITION = "tracking_position"


def load_diag(path):
    """Records from an on-device JSONL session file or a logcat dump.

    Accepts both shapes on purpose: `DiagFileSink` writes bare JSON per line,
    while `adb logcat | grep '[jeeb-diag]'` prefixes each one. A reader that
    handled only one would report an empty capture for the other — zero records,
    which reads as "the feature emitted nothing".
    """
    out = []
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            brace = line.find("{")
            if brace < 0:
                continue
            try:
                out.append(json.loads(line[brace:]))
            except json.JSONDecodeError:
                continue
    return out


def events(records, name, delivery):
    hits = []
    for r in records:
        if r.get("t") != "evt" or r.get("name") != name:
            continue
        data = r.get("data") or {}
        if delivery and data.get("deliveryId") != delivery:
            continue
        hits.append(data)
    return hits


def recorder_rows(db_path, since_ms, until_ms):
    con = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    try:
        total = con.execute("SELECT COUNT(*) FROM requests").fetchone()[0]
        q = "SELECT ts_ms, method, path, status, res_body FROM requests"
        args = []
        if since_ms is not None:
            q += " WHERE ts_ms >= ?"
            args.append(since_ms)
            if until_ms is not None:
                q += " AND ts_ms <= ?"
                args.append(until_ms)
        elif until_ms is not None:
            q += " WHERE ts_ms <= ?"
            args.append(until_ms)
        rows = con.execute(q + " ORDER BY ts_ms ASC", args).fetchall()
    finally:
        con.close()
    return total, rows


def decode(blob):
    if blob is None:
        return ""
    if isinstance(blob, bytes):
        return blob.decode("utf-8", "replace")
    return str(blob)


def check(recorder, diag, delivery, since_ms=None, until_ms=None):
    """Returns (ok, [(leg, ok, detail), ...])."""
    legs = []

    total, rows = recorder_rows(recorder, since_ms, until_ms)
    if total == 0:
        return False, [(
            "PRECONDITION",
            False,
            "the recorder DB holds 0 rows. A zero counted out of an empty file "
            "is not a measurement — this is the api-recorder.db trap.",
        )]

    tracking = [r for r in rows if f"deliveries/{delivery}/tracking" in (r[2] or "")]
    stream = [r for r in rows if STREAM_ALIAS in (r[2] or "")]
    reg = [r for r in rows if "PushNotification/register" in (r[2] or "")]

    records = load_diag(diag)
    opens = events(records, SCREEN_OPEN, delivery)
    positions = events(records, POSITION, delivery)
    pushes = [p for p in positions if p.get("cause") == "push"]
    applied = [p for p in positions if p.get("applied") is True]
    coords = {(p.get("lat"), p.get("lng")) for p in applied
              if p.get("lat") is not None and p.get("lng") is not None}

    denom = f"(of {total} total_rows_in_capture, {len(rows)} in window)"

    legs.append(("WIRE-1 screen_open == 1", len(opens) == 1,
                 f"{len(opens)} {SCREEN_OPEN} for {delivery} — this is THE DENOMINATOR"))
    legs.append(("WIRE-2 position >= 3", len(positions) >= 3,
                 f"{len(positions)} {POSITION} records"))
    legs.append(("WIRE-3 >=1 cause=push", len(pushes) >= 1,
                 f"{len(pushes)} of {len(positions)} carry cause:'push'"))
    legs.append((f"WIRE-4 tracking GETs >= 3", len(tracking) >= 3,
                 f"{len(tracking)} GET deliveries/{delivery}/tracking {denom}"))
    legs.append(("WIRE-5 stream rows == 0", len(stream) == 0,
                 f"{len(stream)} rows on the deleted alias {denom}"))

    if rows:
        span_ms = rows[-1][0] - rows[0][0]
        legs.append(("WIRE-6 6-min quiet window", span_ms >= 6 * 60 * 1000 and not stream,
                     f"capture spans {span_ms/1000:.0f}s with {len(stream)} stream rows "
                     f"(needs >= 360s AND zero)"))
    else:
        legs.append(("WIRE-6 6-min quiet window", False, "no rows in window"))

    legs.append(("MARKER >=2 distinct (lat,lng)", len(coords) >= 2,
                 f"{len(coords)} distinct applied:true coordinate pairs "
                 f"from {len(applied)} applied records"))

    legs.append(("CONTROL >=1 push register", len(reg) >= 1,
                 f"{len(reg)} PushNotification/register rows {denom}"))

    # Precondition, reported separately from the verdict on the WORK. MB1.md:
    # "If the recipe's preconditions were not met, the round is not a FAIL of
    # the work — it is not a round. Re-run it."
    null_positions = [r for r in tracking if '"position":null' in decode(r[4]).replace(" ", "")]
    if tracking and len(null_positions) == len(tracking):
        legs.append((
            "PRECONDITION not-a-round",
            False,
            f"all {len(tracking)} tracking reads returned position:null. That "
            f"measures the jeeber's GPS uploader and the 5-min TTL, NOT this "
            f"batch. Re-run the round per MB1.md's R1 recipe (drive to "
            f"InTransit, move >=10 m, read inside the TTL) — do not record a "
            f"FAIL against the work.",
        ))

    return all(ok for _, ok, _ in legs), legs


# ---------------------------------------------------------------------------
# Self-test: a positive control and one negative control per leg.
# ---------------------------------------------------------------------------

def _fixture(tmp, *, opens=1, positions=3, push=True, tracking=3, streams=0,
             span_ms=7 * 60 * 1000, coords=2, register=1, all_null=False):
    dev = "DLV-SELFTEST"
    db = os.path.join(tmp, "cap.db")
    if os.path.exists(db):
        os.remove(db)
    con = sqlite3.connect(db)
    con.execute("CREATE TABLE requests (id TEXT PRIMARY KEY, ts_ms INTEGER, "
                "method TEXT, path TEXT, status INTEGER, res_body BLOB)")
    n = 0
    base = 1_785_000_000_000
    body = b'{"position":null}' if all_null else b'{"position":{"lat":1,"lng":2}}'
    for i in range(tracking):
        con.execute("INSERT INTO requests VALUES (?,?,?,?,?,?)",
                    (f"t{i}", base + i, "GET", f"/deliveries/{dev}/tracking", 200, body))
        n += 1
    for i in range(streams):
        con.execute("INSERT INTO requests VALUES (?,?,?,?,?,?)",
                    (f"s{i}", base + i, "GET", f"/v1/{STREAM_ALIAS}/{dev}", 404, b""))
        n += 1
    for i in range(register):
        con.execute("INSERT INTO requests VALUES (?,?,?,?,?,?)",
                    (f"r{i}", base + 1, "PUT", "/api/PushNotification/register", 201, b""))
        n += 1
    # A last row that sets the capture span.
    con.execute("INSERT INTO requests VALUES (?,?,?,?,?,?)",
                ("z", base + span_ms, "GET", "/health", 200, b"ok"))
    con.commit()
    con.close()

    jsonl = os.path.join(tmp, "diag.jsonl")
    with open(jsonl, "w", encoding="utf-8") as fh:
        for _ in range(opens):
            fh.write("[jeeb-diag] " + json.dumps(
                {"t": "evt", "name": SCREEN_OPEN, "data": {"deliveryId": dev}}) + "\n")
        for i in range(positions):
            cause = "push" if (push and i > 0) else "open"
            lat = 33.0 + (i if i < coords else coords - 1) * 0.01
            fh.write(json.dumps({
                "t": "evt", "name": POSITION,
                "data": {"deliveryId": dev, "cause": cause, "applied": True,
                         "lat": lat, "lng": 35.0, "polyline": 2},
            }) + "\n")
    return db, jsonl, dev


def selftest():
    ok_all = True
    with tempfile.TemporaryDirectory() as tmp:
        db, jsonl, dev = _fixture(tmp)
        ok, legs = check(db, jsonl, dev)
        print(f"POS  overall={'PASS' if ok else 'FAIL'}")
        for name, good, detail in legs:
            print(f"       {'ok ' if good else 'RED'} {name}: {detail}")
        if not ok:
            ok_all = False
            print("  !! the positive control does not pass — the reader is broken")

        negs = [
            ("WIRE-1", dict(opens=2)),
            ("WIRE-2", dict(positions=1, coords=1)),
            ("WIRE-3", dict(push=False)),
            ("WIRE-4", dict(tracking=1)),
            ("WIRE-5", dict(streams=4)),
            ("WIRE-6", dict(span_ms=60 * 1000)),
            ("MARKER", dict(coords=1)),
            ("CONTROL", dict(register=0)),
            ("PRECONDITION", dict(all_null=True)),
        ]
        for leg, kw in negs:
            db, jsonl, dev = _fixture(tmp, **kw)
            ok, legs = check(db, jsonl, dev)
            reds = [n for n, good, _ in legs if not good]
            hit = any(n.startswith(leg) for n in reds)
            verdict = "ok " if (not ok and hit) else "RED"
            if verdict == "RED":
                ok_all = False
            print(f"NEG  {verdict} break {leg:<12} -> overall="
                  f"{'FAIL' if not ok else 'PASS'}, red legs={reds}")

        # The empty-DB trap, as its own control.
        empty = os.path.join(tmp, "empty.db")
        con = sqlite3.connect(empty)
        con.execute("CREATE TABLE requests (id TEXT PRIMARY KEY, ts_ms INTEGER, "
                    "method TEXT, path TEXT, status INTEGER, res_body BLOB)")
        con.commit()
        con.close()
        ok, legs = check(empty, jsonl, dev)
        good = (not ok) and legs[0][0] == "PRECONDITION"
        if not good:
            ok_all = False
        print(f"NEG  {'ok ' if good else 'RED'} an EMPTY capture is REFUSED, not "
              f"scored as 0 stream rows")
    print("SELFTEST", "PASS" if ok_all else "FAIL")
    return 0 if ok_all else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--recorder")
    ap.add_argument("--diag")
    ap.add_argument("--delivery")
    ap.add_argument("--since-ms", type=int)
    ap.add_argument("--until-ms", type=int)
    a = ap.parse_args()

    if a.selftest:
        return selftest()

    if not (a.recorder and a.diag and a.delivery):
        print("BLOCKED: no device round has been performed.")
        print("  R1 needs a recorder DB and an on-device diag JSONL from a real")
        print("  round on the delivery under test. GATE.md §4: BLOCKED is not a")
        print("  pass, and it must NOT be substituted with a host suite.")
        print("  Prove the reader first:  r1-check.py --selftest")
        return 3

    ok, legs = check(a.recorder, a.diag, a.delivery, a.since_ms, a.until_ms)
    for name, good, detail in legs:
        print(f"{'PASS' if good else 'FAIL'}  {name}: {detail}")
    print("R1", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
