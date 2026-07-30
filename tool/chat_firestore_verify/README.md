# chat-firestore-verify

Repeatable verification for the Firestore chat transport (batches b03 + b04).

Everything in here existed only as hand-typed commands during b03/b04. That is why two
false results nearly shipped — see **Instrument traps** below. These scripts encode the
method so the next run cannot repeat those mistakes.

## What each layer proves — and what it CANNOT

| Layer | Where | Proves | Blind to |
|---|---|---|---|
| Predicate unit tests | `test/features/deep_link_targets/chat_realtime_auction_gate_test.dart` | the whole 4 × 3 phase × roster product | anything about a real listener |
| Widget/screen tests | same file, screen group | the predicate is evaluated inside `_wrapRealtime` on a live resolution, and a contested row falls through | **whether Firestore is ever reached** — `Firebase.apps` is empty in every widget test, so `RealtimeChatGateway` is never constructed |
| Wire/mapper tests | `firestore_*_test.dart`, `realtime_chat_gateway_merge_test.dart` | document shape, `VisibleTo` filter, both event legs merged + cancelled | authorization; the rules are server-side |
| **`authz` (here)** | live project | the ruleset denies a leftover bidder and admits everyone it should | client behaviour |
| **`measure` (here)** | two real phones | HTTP requests per inbound message | rule correctness |
| **`contested` (here)** | live conv + phones | the b04 change end-to-end: contested roster → admitted → 0 requests | — |

The middle three columns are why a green `flutter test` means very little on its own here.
**Setting `_wrapRealtime` to `return inner` — feature entirely off — still produces an
all-pass suite.** Only `measure` and `contested` can tell you the transport works.

## Usage

```bash
# rule layer: build a contested roster, probe it, clean up after itself
python3 tool/chat_firestore_verify/verify.py authz

# device: count HTTP requests per inbound message (needs both phones + recorders)
python3 tool/chat_firestore_verify/verify.py measure --messages 5

# full b04 path: make the live conversation contested, prove admit + 0 requests, restore
python3 tool/chat_firestore_verify/verify.py contested
```

`measure` and `contested` need the api-recorder proxies running, one per phone with its
**own** SQLite file (they lock each other otherwise):

```bash
cd /tmp && mkdir -p rec9101 rec9102
(cd rec9101 && PORT=9101 TARGET=http://<gateway> node <repo>/tools/api-recorder/recorder.mjs &)
(cd rec9102 && PORT=9102 TARGET=http://<gateway> node <repo>/tools/api-recorder/recorder.mjs &)
adb -s <receiver> reverse tcp:9000 tcp:9101
adb -s <sender>   reverse tcp:9000 tcp:9102
```

Build the APK with `--dart-define JEEB_MOCK_BASE_URL=http://127.0.0.1:9000`.
**Not `GATEWAY_BASE_URL`** — that define has zero usages in `lib/`; it only appears to work
because the debug fallback happens to point at the dev gateway.

## Instrument traps this harness encodes

1. **`/__logs` returns rows NEWEST-FIRST.** Slicing `rows[n:]` for "new" rows silently returns
   the OLDEST ones. A b04 run reported two genuinely-sent messages as `sent=0` because of this.
   `verify.py` always sorts by `ts` and filters an explicit time window.
2. **A send that never happened reads as 0 requests.** The keyboard grows the composer into a
   multi-line box and a fixed send-coordinate lands on the keyboard instead. Both b03 and b04 hit
   this. `measure` asserts a `POST /messages` on the sender's own recorder for every message and
   refuses to report a number if any send is missing.
3. **A quiet baseline is mandatory.** Without proving the receiver is silent while idle, "0
   requests on message arrival" is not attributable to anything.
4. **Zero requests from a dead listener is a failure, not parity.** `measure` prints the receiver's
   `chat_realtime_transport` / `chat_realtime_live` diagnostics so a 0 can be distinguished from a
   broken subscription. Confirm the message rendered.
5. **Admin tokens bypass Firestore rules entirely.** `authz` obtains every identity under test
   through the real chain (`/auth/tokens` → `/v1/chat/firebase-token` → `signInWithCustomToken`)
   and uses admin only for ground-truth inspection and cleanup.
6. **A 403 with no positive control is indistinguishable from `allow read: if false`.** `authz`
   requires the permitted readers to get 200 in the same run, or it reports the result void.
