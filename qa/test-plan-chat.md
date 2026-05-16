# Test Plan — Post-Acceptance Chat

Maps to: **FR-7.1**, **US-6.1**
Backend: `chat-service` (REST + WebSocket via `ChatService.Client.Realtime`)
Owner: Mobile QA
Status: Draft v1 — JEEB-110

## 1. Scope

The 1:1 chat thread that opens between Client and Jeeber the moment an
offer is accepted, and stays open until the delivery is rated or
disputes-window closes (whichever is later).

In scope:
- Sending and receiving every supported message type
- Delivery + read receipts (single check / double check)
- Offline send + queued replay
- WebSocket disconnect + reconnect behaviour
- Moderation hooks (mask / hide) and soft-delete
- Attachment upload (image, voice clip, location pin, document)

Out of scope:
- Group chat (no MVP requirement)
- Push notification rendering — covered in `test-plan-notifications.md` (T-qa-007)
- Voice transcription — covered in `voice-transcription-service` plan

## 2. Architecture under test

```
[Mobile Chat BLoC]
   │
   ├── REST  ── POST /api/channels/{id}/messages          (send)
   │           GET  /api/channels/{id}/messages?since=…   (replay / cold start)
   │           POST /api/channels/{id}/messages/{m}/seen  (read receipt)
   │
   └── WebSocket ── /hub/chat?channelId=…                 (live push)
                    events: message.created, message.delivered,
                            message.seen, message.hidden, message.deleted
```

Key invariants the plan exercises:

1. Every message has a client-generated `clientMessageId` so retries
   are idempotent.
2. The server is the source of truth for message ordering; the local
   cache reorders on `seq` (monotonic per channel).
3. WebSocket loss never causes message loss — REST replay closes the gap.

## 3. Message-type coverage

For each row, three tests: **send** (mobile → server), **receive**
(server → mobile via WS), **replay** (cold-start REST hydration shows it).

| Type        | Payload                                | Validation                                                  |
|-------------|----------------------------------------|-------------------------------------------------------------|
| `text`      | UTF-8 string ≤ 2000 chars              | Empty rejected; > 2000 truncated client-side with toast     |
| `text/RTL`  | Arabic string with mixed LTR digits    | Renders right-aligned; digits stay LTR                       |
| `text/emoji`| Multi-codepoint emoji 👨‍👩‍👧‍👦, ZWJ sequences | No grapheme break; copies cleanly                            |
| `image`     | JPEG ≤ 10 MB, HEIC on iOS              | Thumbnail shown immediately (optimistic); full-res lazy-load |
| `voice`     | AAC clip ≤ 60 s                         | Waveform rendered; play/pause works; seekable                |
| `location`  | `{lat,lng,accuracy}` from device GPS    | Tappable → opens Maps app deep-link                         |
| `document`  | PDF ≤ 25 MB                             | Filename + size shown; tap opens external viewer             |
| `system`    | Server-generated, e.g. "Order picked up"| Renders centered, no avatar, no reply action                |

### 3.1 Negative cases per type

- `text`: SQL-ish payload `'); DROP TABLE messages;--` round-trips unchanged.
- `image`: 11 MB upload rejected client-side before network call.
- `image`: file with mismatched extension (PNG renamed to `.jpg`) is detected by mime-sniff.
- `voice`: recording > 60 s auto-stops at 60 s with a "max length reached" toast.
- `location`: device location services off → CTA falls back to "Open settings".
- `document`: `.exe` rejected; allow-list is `pdf,docx,xlsx,jpg,png,heic`.

### 3.2 Receipt state machine

For every type:

```
[client local] → sending → sent (single check) → delivered (double check, gray)
                                              → seen     (double check, blue)
              → failed  (red ! , tap to retry)
```

Tests:

1. Happy path: sender sees `sent` within 500ms of tap, `delivered` within
   2s when peer is online, `seen` within 1s of peer opening the thread.
2. Peer offline: `sent` only; `delivered` arrives the moment peer
   reconnects; `seen` only after peer scrolls the message into view.
3. Send failure (server 5xx): `failed` shown; retry succeeds; receipts
   resume from `sent` — never duplicates.

## 4. Read-receipt edge cases

| # | Scenario                                                                     | Expected                                                          |
|---|------------------------------------------------------------------------------|-------------------------------------------------------------------|
| 1 | Peer has thread open in foreground when message arrives                      | `seen` fires immediately, gray→blue ticks on sender within 1s     |
| 2 | Peer has app backgrounded; opens app and lands on chat list (not the thread) | Stays at `delivered`; `seen` only on opening the thread           |
| 3 | Peer scrolls past message without it being viewport-visible                  | Stays at `delivered`; `seen` requires viewport-intersect ≥ 250 ms |
| 4 | Two messages in quick succession; peer reads only the latest                 | Latest → `seen`; older → `seen` too (server marks all ≤ that seq) |
| 5 | Peer has read; sender deletes message                                        | Tombstone shows on both sides; receipts removed                   |

## 5. Offline send

Setup: enable Airplane Mode (Maestro `setAirplaneMode true`).

| # | Action                                                       | Expected                                                                                                  |
|---|--------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------|
| 1 | Send 5 text messages while offline                            | Each shows clock icon + "queued" label; no error                                                          |
| 2 | Toggle Airplane Mode off                                      | All 5 send within 5 s in original order; ticks transition queued → sent → delivered                       |
| 3 | Send 1 image while offline                                    | Image renders locally with greyed overlay; queued                                                         |
| 4 | Kill app while offline messages queued                        | On relaunch (still offline), queued messages reappear in same order                                        |
| 5 | Network restored after app relaunch                           | Queue drains; `clientMessageId` prevents duplicates if a partial send completed before kill (server-side dedupe) |
| 6 | 24-hour offline timeout                                       | Messages > 24 h old in queue are marked `failed` with "Message expired — tap to retry"                    |

## 6. WebSocket reconnect

Setup: hold WebSocket connection open in a foreground chat.

| # | Disruption                                                  | Expected mobile behaviour                                                                                              |
|---|-------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------|
| 1 | Server drops the socket (graceful close 1001)               | Banner: "Reconnecting…"; exponential backoff 1s/2s/4s/8s/15s, capped at 30s                                            |
| 2 | TCP cut (Wi-Fi off mid-session)                              | Same banner; on reconnect, REST gap-fill via `?since=<lastSeq>` runs *before* re-subscribing to live events            |
| 3 | Wi-Fi → cellular handoff                                     | Reconnect within 3s; no duplicate messages; no missed messages (verified by sending one from peer during the handoff) |
| 4 | Server restart while client is connected                     | Banner persists until backend healthy; once up, full replay from `lastSeq`                                              |
| 5 | Token expiry during long session                             | 401 on next event → silent refresh via `auth-service` → resubscribe; no banner shown                                   |
| 6 | Peer sends 200 messages during a 60 s disconnect              | Replay returns them in order; UI does not jank (verified with `flutter run --profile` — no frame > 32 ms)              |

### 6.1 Cold start

| # | Scenario                                                          | Expected                                                                                |
|---|-------------------------------------------------------------------|-----------------------------------------------------------------------------------------|
| 1 | First open of a chat thread, no local cache                       | Skeleton placeholder ≤ 200 ms; first 50 messages within 1.5 s on 3G                     |
| 2 | Second open, full cache                                           | Messages render from cache instantly; delta fetch via `?since=<lastSeq>`                |
| 3 | Cache corrupted (manual SharedPreferences mutation)               | App detects schema mismatch, drops cache, falls back to full fetch — no crash, no data loss |

## 7. Moderation surfaces

| # | Server action                          | Expected mobile behaviour                                       |
|---|----------------------------------------|-----------------------------------------------------------------|
| 1 | Server returns `mask`-ed message        | Body replaced with "⚠️ This message was hidden by moderation"; original not retrievable |
| 2 | Server returns `hide` for a message     | Message removed from list; timeline does not collapse — system note replaces it |
| 3 | Sender hits per-channel rate limit (429) | Toast: "Slow down — try again in {Retry-After}s"; send button disabled for that window |
| 4 | Profanity flagged client-side (optional) | No client-side block; server is authoritative                   |

## 8. Soft-delete

| # | Scenario                                            | Expected                                                                |
|---|-----------------------------------------------------|-------------------------------------------------------------------------|
| 1 | Sender long-presses own message → Delete            | Tombstone "Message deleted" on both sides within 2 s                    |
| 2 | Sender deletes a message peer has already quoted    | Quote remains; original tombstoned; quote shows "(deleted)" inline label|
| 3 | Sender tries to delete > 24 h after sending          | Delete option disabled with tooltip "Older than 24 hours"               |

## 9. Performance budgets

Per `mobile-perf-budget`:

- Cold open of chat list: ≤ 1.5 s on Pixel 4a
- Time to first message render in a thread: ≤ 800 ms with cache, ≤ 1.5 s without
- Scroll: 60 fps sustained on a 1000-message thread (no frame > 32 ms)
- Memory: thread held open 30 min < 150 MB RSS

## 10. Test inventory

### 10.1 Unit (`test/features/chat/`)

- `chat_message_test.dart` — entity equality, serialization round-trip
- `message_queue_test.dart` — enqueue/dequeue, dedupe by clientMessageId, expiry
- `seq_reconciler_test.dart` — out-of-order WebSocket events get reordered

### 10.2 Widget (`test/features/chat/presentation/`)

- `chat_bubble_test.dart` — every message type renders + receipt state
- `chat_input_test.dart` — text length, attachment picker, send disabled states
- `chat_thread_page_test.dart` — empty / loaded / error / reconnecting banners

### 10.3 Integration (`integration_test/chat/`)

- `send_text_flow_test.dart` — Patrol-driven, full BLoC + mocked Dio
- `offline_queue_flow_test.dart` — toggles connectivity via `connectivity_plus` mock
- `reconnect_flow_test.dart` — kills mock WS server; asserts replay correctness

### 10.4 E2E (`qa/maestro/chat/`) — added in T-qa-009

- `flow_send_receive.yaml` — two devices on Maestro Cloud, real backend
- `flow_offline_replay.yaml` — single device, airplane-mode toggle
- `flow_reconnect.yaml` — toggle Wi-Fi mid-session

## 11. Test data

Seeded in `jeeb-infrastructure/seeds/qa-chat.sql`:

- Channel `qa-channel-empty` — fresh channel, no messages
- Channel `qa-channel-200` — pre-loaded 200-message history for scroll perf
- Channel `qa-channel-mixed` — every message type at least once
- Channel `qa-channel-moderated` — contains masked + hidden + deleted messages

## 12. Risks and assumptions

- **Assumption**: chat-service exposes a stable `since=<seq>` REST endpoint
  for replay. If only `since=<timestamp>` is available, the reconciler in
  §6 needs adjustment because clock-skew can drop messages.
- **Risk**: HEIC images on iOS are converted to JPEG before upload by the
  chat-service. If conversion fails server-side, the client must show
  "Upload failed — try again" and not silently strip the image.
- **Risk**: Voice clips depend on mic permission, which is tested by Patrol
  but the **first-time** prompt cannot be auto-dismissed on iOS — this is
  an exploratory-only test on iOS Tier 1.
