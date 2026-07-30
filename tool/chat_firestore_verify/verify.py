#!/usr/bin/env python3
"""Repeatable verification for the Firestore chat transport (batches b03 + b04).

Subcommands:
  authz      rule layer  — build a contested roster, prove a leftover bidder is denied, clean up
  measure    device      — HTTP requests per inbound message, on two real phones
  contested  end-to-end  — make the live conversation contested, prove admit + 0 requests, restore

Read the README before changing anything here. Every guard in this file exists because a
real run produced a confidently wrong number without it.
"""
import argparse, datetime as dt, json, os, subprocess, sys, time, urllib.request, uuid

# ---------------------------------------------------------------- config
GATEWAY   = os.environ.get("JEEB_GATEWAY", "http://192.168.2.39:10090")
CHAT_SVC  = "http://127.0.0.1:5803/api"      # host-internal; only reachable through MSI_SH


def _find_msi_sh():
    """Locate docs/agents/scripts/msi.sh regardless of the caller's cwd.

    This script lives in <repo>/tool/chat_firestore_verify/, and the docs repo is a SIBLING
    of the repo — not inside it — so walk up until we find it. Override with MSI_SH=<path>.
    """
    if os.environ.get("MSI_SH"):
        return os.environ["MSI_SH"]
    here = os.path.abspath(__file__)
    d = os.path.dirname(here)
    for _ in range(8):
        cand = os.path.join(d, "docs", "agents", "scripts", "msi.sh")
        if os.path.isfile(cand):
            return cand
        d = os.path.dirname(d)
    raise SystemExit(
        "could not locate docs/agents/scripts/msi.sh — set MSI_SH=/abs/path/to/msi.sh")


MSI_SH = None  # resolved lazily so --help works without the workspace present
PROJECT   = "jeeb-5a293"
FS        = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"

RECEIVER  = "RZCT505K7WF"   # a33  — the phone whose requests we count
SENDER    = "RFCX306JSRT"   # s24  — the phone that sends
REC_RECV  = 9101
REC_SEND  = 9102

COMPOSER  = (541, 2087)     # composer, keyboard down
SEND_BTN  = (978, 1211)     # send button, keyboard UP — differs from the keyboard-down position


# ---------------------------------------------------------------- helpers
def now():
    return dt.datetime.now(dt.timezone.utc)


def ts(x):
    return dt.datetime.fromisoformat(x.replace("Z", "+00:00"))


def http(method, url, body=None, headers=None, timeout=30):
    data = json.dumps(body).encode() if body is not None else None
    h = {"Content-Type": "application/json"}
    h.update(headers or {})
    req = urllib.request.Request(url, data=data, headers=h, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            raw = r.read().decode()
            return r.status, (json.loads(raw) if raw.strip() else {})
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, (json.loads(raw) if raw.strip() else {})
        except Exception:
            return e.code, {"raw": raw[:300]}
    except Exception as e:
        return -1, {"err": str(e)}


def recorder_rows(port):
    """TRAP 1: /__logs returns rows NEWEST-FIRST. Always sort before any windowing."""
    st, d = http("GET", f"http://127.0.0.1:{port}/__logs?limit=800", timeout=15)
    if st != 200:
        raise SystemExit(f"recorder :{port} unreachable ({st}) — is it running?")
    rows = d if isinstance(d, list) else d.get("rows", d.get("logs", []))
    return sorted(rows, key=lambda x: x.get("ts", ""))


def window(rows, t0, seconds):
    t1 = t0 + dt.timedelta(seconds=seconds)
    return [r for r in rows if t0 <= ts(r["ts"]) <= t1]


def adb(serial, *args, timeout=30):
    return subprocess.run(["adb", "-s", serial, *args],
                          capture_output=True, text=True, timeout=timeout)


def msi(cmd, timeout=90):
    global MSI_SH
    if MSI_SH is None:
        MSI_SH = _find_msi_sh()
    r = subprocess.run(["bash", MSI_SH, cmd], capture_output=True, text=True, timeout=timeout)
    if not r.stdout.strip():
        # An empty body here is almost always ssh refusing the session ("Too many
        # authentication failures" after several rapid connections), not an empty API
        # response. Surface it instead of letting a caller parse "" as a bad payload.
        raise SystemExit(f"msi.sh returned nothing. stderr: {r.stderr.strip()[:300]}")
    return r.stdout


def msi_json(cmd, timeout=90):
    """Last non-empty line of an msi() result, parsed as JSON."""
    out = msi(cmd, timeout)
    for line in reversed(out.strip().splitlines()):
        line = line.strip()
        if line.startswith("{") or line.startswith("["):
            return json.loads(line)
    raise SystemExit(f"no JSON in msi output: {out[:300]}")


def gcloud_token():
    return subprocess.run(["gcloud", "auth", "print-access-token"],
                          capture_output=True, text=True, timeout=60).stdout.strip()


def require_devices():
    out = subprocess.run(["adb", "devices"], capture_output=True, text=True, timeout=30).stdout
    missing = [s for s in (RECEIVER, SENDER) if f"{s}\tdevice" not in out]
    if missing:
        raise SystemExit(f"device(s) not attached: {missing}. Refusing to fake a result.")


# ---------------------------------------------------------------- identities
def real_chain_identity(user_id, api_key):
    """TRAP 5: never use an admin token for an identity under test — admin bypasses rules."""
    bearer = None
    for path, body in (("/auth/tokens", {"userId": user_id}),
                       ("/auth/tokens", {"user_id": user_id})):
        st, js = http("POST", GATEWAY + path, body)
        if st in (200, 201):
            for k in ("accessToken", "access_token", "token"):
                if isinstance(js, dict) and js.get(k):
                    bearer = js[k]
                    break
        if bearer:
            break
    if not bearer:
        return None, "no bearer from /auth/tokens"
    st, js = http("POST", f"{GATEWAY}/v1/chat/firebase-token", {},
                  {"Authorization": f"Bearer {bearer}"})
    if st != 200:
        return None, f"mint failed {st}"
    st, sj = http("POST",
                  f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key={api_key}",
                  {"token": js["token"], "returnSecureToken": True})
    if st != 200:
        return None, f"signInWithCustomToken failed {st}"
    return sj["idToken"], "real chain"


# ---------------------------------------------------------------- authz
def cmd_authz(args):
    """Build a contested roster, prove the leftover bidder is denied, clean up."""
    run = uuid.uuid4().hex[:8]
    client, winner, loser, outsider = (f"vfy-client-{run}", f"vfy-winner-{run}",
                                       f"vfy-loser-{run}", f"vfy-outsider-{run}")
    api_key = args.api_key
    at = gcloud_token()
    AH = {"Authorization": f"Bearer {at}"}

    print(f"project={PROJECT} run={run}\n== build contested roster ==")
    ck = f"vfy-{run}"
    # ONE ssh session for the whole setup. msi.sh opens a fresh connection per call and
    # sshd refuses after a few rapid ones ("Too many authentication failures"), which
    # surfaces as an empty body — so batch, never loop.
    script = (
        f'C={CHAT_SVC}; '
        f'CID=$(curl -s -X POST $C/conversations -H "Content-Type: application/json" '
        f'-d \'{{"correlation_key":"{ck}","owner_user_id":"{client}","owner_role_in_convo":"client","phase":"broadcasting"}}\' '
        f'| python3 -c "import json,sys;print(json.load(sys.stdin)[\'conversation_id\'])"); '
        f'for U in {winner} {loser}; do curl -s -o /dev/null -X POST $C/conversations/$CID/participants '
        f'-H "Content-Type: application/json" -d "{{\\"user_id\\":\\"$U\\",\\"role_in_convo\\":\\"jeeber_offerer\\"}}"; done; '
        # seat the winner WITHOUT removing the loser — the swallowed-step-4 state
        f'curl -s -o /dev/null -X PATCH $C/conversations/$CID/phase -H "Content-Type: application/json" '
        f'-d \'{{"phase":"accepted","winner_user_id":"{winner}","winner_role_in_convo":"jeeber_winner","remove_others":false}}\'; '
        f'MT=$(curl -s -X POST $C/conversations/$CID/messages -H "Content-Type: application/json" '
        f'-d \'{{"kind":"text","author_id":"{winner}","body":"thread-{run}"}}\' '
        f'| python3 -c "import json,sys;print(json.load(sys.stdin)[\'message_id\'])"); '
        f'MB=$(curl -s -X POST $C/conversations/$CID/messages -H "Content-Type: application/json" '
        f'-d \'{{"kind":"text","author_id":"{client}","audience":"all","body":"broadcast-{run}"}}\' '
        f'| python3 -c "import json,sys;print(json.load(sys.stdin)[\'message_id\'])"); '
        f'echo "{{\\"cid\\":\\"$CID\\",\\"thread\\":\\"$MT\\",\\"broadcast\\":\\"$MB\\"}}"'
    )
    built = msi_json(script, timeout=150)
    cid = built["cid"]
    msgs = {"thread": built["thread"], "broadcast": built["broadcast"]}
    print(f"  conversation={cid}")

    st, doc = http("GET", f"{FS}/Conversations/{cid}", None, AH)
    seated = live = False
    for v in doc.get("fields", {}).get("Participants", {}).get("arrayValue", {}).get("values", []):
        f = v["mapValue"]["fields"]
        role = f.get("RoleInConvo", {}).get("stringValue", "")
        act = not f.get("RemovedAt", {}).get("timestampValue")
        seated |= (role == "jeeber_winner" and act)
        live |= ("offerer" in role and act)
    print(f"  contested? seated_winner={seated} live_bidder={live}")
    if not (seated and live):
        raise SystemExit("could not build a contested roster — probe would be meaningless")

    print("\n== probe (rules enforced) ==")
    results = []

    def leg(label, uid, mid, want):
        tok, how = real_chain_identity(uid, api_key)
        if not tok:
            print(f"  VOID  {label}: {how}")
            results.append(None)
            return
        st, _ = http("GET", f"{FS}/Conversations/{cid}/Messages/{mid}", None,
                     {"Authorization": f"Bearer {tok}"})
        ok = st == want
        results.append(ok)
        print(f"  {'PASS' if ok else 'FAIL'}  {st} (want {want})  {label}")

    leg("leftover loser -> winner thread   <== THE QUESTION", loser, msgs["thread"], 403)
    leg("winner -> same message", winner, msgs["thread"], 200)
    leg("client -> same message", client, msgs["thread"], 200)
    leg("NON-participant -> same message", outsider, msgs["thread"], 403)
    leg("loser -> broadcast (should SEE)", loser, msgs["broadcast"], 200)

    print("\n== cleanup ==")
    for mid in msgs.values():
        http("DELETE", f"{FS}/Conversations/{cid}/Messages/{mid}", None, AH)
    http("DELETE", f"{FS}/Conversations/{cid}", None, AH)
    st, _ = http("GET", f"{FS}/Conversations/{cid}", None, AH)
    print(f"  scratch conversation re-read -> {st} (404 = gone)")

    headline, controls = results[0], results[1:]
    # TRAP 6: a 403 means nothing unless the permitted readers got 200 in the SAME run.
    ok = bool(headline) and all(c for c in controls if c is not None) and len([c for c in controls if c]) >= 4
    print("\n" + "=" * 62)
    print(f"VERDICT  gate_removal_authorized / leak closed : {ok}")
    print("=" * 62)
    return 0 if ok else 1


# ---------------------------------------------------------------- measure
def send_one(text):
    """TRAP 2: verify the POST actually happened. A missed tap reads as 0 requests."""
    before = len([r for r in recorder_rows(REC_SEND)
                  if r.get("method") == "POST" and "messages" in r.get("path", "")])
    adb(SENDER, "shell", "input", "tap", str(COMPOSER[0]), str(COMPOSER[1])); time.sleep(1.5)
    adb(SENDER, "shell", "input", "text", text); time.sleep(1.2)
    adb(SENDER, "shell", "input", "tap", str(SEND_BTN[0]), str(SEND_BTN[1])); time.sleep(8)
    after = [r for r in recorder_rows(REC_SEND)
             if r.get("method") == "POST" and "messages" in r.get("path", "")]
    return (len(after) > before), (after[-1] if after else None)


def transport_diag():
    out = adb(RECEIVER, "logcat", "-d", timeout=45).stdout
    keep = [l for l in out.splitlines()
            if "chat_realtime_transport" in l or "chat_realtime_live" in l
            or "chat_realtime_contested_admitted" in l or "chat_realtime_unavailable" in l]
    return keep[-4:]


def measure(n, label):
    require_devices()
    t0 = now()
    print(f"== quiet baseline: receiver idle on the open chat, {45}s ==")
    time.sleep(45)
    idle = [r for r in recorder_rows(REC_RECV) if ts(r["ts"]) > t0]
    print(f"  receiver requests while idle: {len(idle)}")
    if idle:
        # TRAP 3: without a silent baseline the number below is not attributable.
        for r in idle:
            print(f"    {r['ts'][-13:]} {r.get('method')} {r.get('path','')[:60]}")
        print("  !! NON-ZERO BASELINE — the per-message number is not attributable")

    print(f"\n== {label}: {n} messages ==")
    sends = []
    for i in range(1, n + 1):
        ok, row = send_one(f"{label.upper().replace(' ','')}{i}")
        if not ok:
            print(f"  message {i}: NOT SENT (tap missed the send button) — excluded")
        else:
            sends.append(row)

    if len(sends) < n:
        print(f"\n  !! only {len(sends)}/{n} messages actually sent.")
        if not sends:
            print("  NUMBER VOID — refusing to report 0 requests caused by 0 messages.")
            return None

    recv = recorder_rows(REC_RECV)
    total = 0
    for r in sends:
        win = window(recv, ts(r["ts"]), 22)
        fetch = [x for x in win if "conversations" in x.get("path", "")]
        total += len(fetch)
        print(f"  send {r['ts'][-13:]} {r.get('status')} -> receiver total={len(win)} fetch={len(fetch)}")
        for x in win:
            print(f"      {x['ts'][-13:]} {x.get('method')} {x.get('path','')[:55]}")

    per = total / len(sends)
    print(f"\n  RESULT: {total}/{len(sends)} = {per:.2f} message-fetch requests per inbound message")
    print("  b03 baseline BEFORE the Firestore transport = 2.00")
    # TRAP 4: a 0 from a dead listener is a failure. Show the transport diagnostics.
    print("\n  receiver transport diagnostics (a 0 with no live transport is a FAILURE):")
    for l in transport_diag():
        print(f"    {l[-150:]}")
    print("  -> confirm the messages actually rendered on the receiver before trusting this.")
    return per


def cmd_measure(args):
    per = measure(args.messages, "settled")
    return 0 if per == 0.0 else 1


# ---------------------------------------------------------------- contested
def cmd_contested(args):
    cid, probe = args.conversation, f"vfycontest-{uuid.uuid4().hex[:6]}"
    print(f"== make {cid} contested (adds a LIVE bidder beside the seated winner) ==")
    msi(f"curl -s -o /dev/null -X POST {CHAT_SVC}/conversations/{cid}/participants "
        f"-H 'Content-Type: application/json' -d '{{\"user_id\":\"{probe}\",\"role_in_convo\":\"jeeber_offerer\"}}'")
    state = msi(f"curl -s {CHAT_SVC}/conversations/{cid}")
    if "jeeber_offerer" not in state:
        raise SystemExit("roster did not become contested; aborting")
    print("  roster is contested")

    try:
        print("\n== force the receiver to re-resolve (back out, re-enter chat) ==")
        adb(RECEIVER, "logcat", "-c")
        adb(RECEIVER, "shell", "input", "tap", "54", "157"); time.sleep(4)
        adb(RECEIVER, "shell", "input", "tap", "540", "518"); time.sleep(9)
        diag = transport_diag()
        admitted = any("contested_admitted" in l for l in diag)
        refused = any("chat_realtime_unavailable" in l for l in diag)
        live = any("\"live\":true" in l for l in diag)
        for l in diag:
            print(f"    {l[-150:]}")
        print(f"\n  classified contested + ADMITTED : {admitted and not refused}")
        print(f"  Firestore transport live        : {live}")
        if refused or not live:
            print("  !! the gate refused, or the transport is not live — b04 has regressed")
            return 1
        per = measure(args.messages, "contested")
        return 0 if per == 0.0 else 1
    finally:
        print("\n== restore the roster ==")
        msi(f"curl -s -o /dev/null -X PATCH {CHAT_SVC}/conversations/{cid}/phase "
            f"-H 'Content-Type: application/json' -d '{{\"phase\":\"accepted\",\"remove_others\":false,"
            f"\"remove_user_ids\":[\"{probe}\"]}}'")
        state = msi(f"curl -s {CHAT_SVC}/conversations/{cid}")
        print(f"  probe bidder removed: {'yes' if probe not in state or 'removed_at' in state else 'CHECK MANUALLY'}")


# ---------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    a = sub.add_parser("authz", help="rule layer: contested roster, leftover bidder must be denied")
    a.add_argument("--api-key", required=True, help="Firebase web API key from google-services.json")
    a.set_defaults(func=cmd_authz)

    m = sub.add_parser("measure", help="device: HTTP requests per inbound message")
    m.add_argument("--messages", type=int, default=5)
    m.set_defaults(func=cmd_measure)

    c = sub.add_parser("contested", help="end-to-end: contested roster admitted + 0 requests")
    c.add_argument("--conversation", required=True)
    c.add_argument("--messages", type=int, default=3)
    c.set_defaults(func=cmd_contested)

    args = ap.parse_args()
    sys.exit(args.func(args))


if __name__ == "__main__":
    main()
