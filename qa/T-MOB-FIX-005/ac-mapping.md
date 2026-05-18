# JEB-1423 (T-MOB-FIX-005) — AC ↔ test mapping

Authored by QA-PRE (JEB-1424) for ENG (JEB-1425) and QA-POST (JEB-1426).
Binding source: **LEAD pin, comment #14900** on JEB-1423.

> **LEAD-pin reconciliation note.** The parent issue's AC list cited the
> status enum as `{queued, sending, sent, delivered, read, failed}`. The LEAD
> pin (Decision 3) overrides that to `{pending, sent, delivered, read,
> failed}` and instructs that "tests expect `ChatMessageStatus.pending`,
> never `queued` or `sending`." Tests follow the LEAD pin.

## Pre-fix baseline (main @ 05ec3a7)

- `qa/T-MOB-FIX-005/pre-fix-analyze.log` — full `dart analyze` run
- `qa/T-MOB-FIX-005/pre-fix-chat-only.log` — chat-scoped `dart analyze lib/features/chat/ test/`
- **Total compile errors (whole repo):** 73
- **Chat-attributable compile errors:** 67
- **Total issues (errors + warnings + infos):** 148

Per-file chat-error breakdown (`pre-fix-chat-only.log`):

| Errors | File |
|---:|---|
| 21 | `lib/features/chat/application/chat_connection_cubit.dart` |
| 14 | `test/chat_message_serialization_test.dart` |
|  8 | `test/chat_outbox_test.dart` |
|  7 | `test/chat_connection_cubit_test.dart` |
|  7 | `lib/features/chat/domain/chat_event.dart` |
|  5 | `lib/features/chat/data/shared_prefs_chat_outbox.dart` |
|  3 | `lib/features/chat/data/in_memory_chat_outbox.dart` |
|  2 | `lib/features/chat/domain/chat_outbox.dart` |

Every one of these traces to the `ChatMessage` symbol collision documented in
LEAD pin Decision 1. AC4 measures the drop after ENG merges.

## AC ↔ test mapping

| AC | What it asserts | Test file / line |
|---|---|---|
| AC1 | `dart analyze --fatal-infos` reports **0 errors** in `lib/features/chat/**` | `qa/T-MOB-FIX-005/post-fix-chat-only.log` (captured by QA-POST after ENG merges) — verified by re-running the same `dart analyze lib/features/chat/` command used for `pre-fix-chat-only.log`. Pre-fix expected: 67 → post-fix expected: 0 errors in `lib/features/chat/**`. |
| AC2 | `dart analyze --fatal-infos` reports **0 errors** in `test/chat_*_test.dart` | Same `post-fix-chat-only.log`; covers the test files updated/added by this branch (`test/chat_message_serialization_test.dart`, `test/chat_message_status_test.dart`, `test/chat_connection_cubit_test.dart`, `test/chat_outbox_test.dart`, `test/chat_old_presentation_smoke_test.dart`, plus the OLD-presentation tests `test/chat_cubit_test.dart`, `test/chat_screen_test.dart` after ENG's rename in files #3–#10). |
| AC3 | `flutter test test/chat_*_test.dart` passes 100% | All 5 QA-PRE-authored test files: `test/chat_message_serialization_test.dart` (codec round-trip — full group `ChatMessage codec contract`, lines ~17-130), `test/chat_message_status_test.dart` (state machine — group `ChatMessage status transitions via copyWith`, lines ~60-105), `test/chat_outbox_test.dart` (persistence + `markFailed` default-impl smoke, lines ~85-115), `test/chat_connection_cubit_test.dart` (cubit-level retry semantics, `retry()` group line ~285), `test/chat_old_presentation_smoke_test.dart` (DeliveryChatMessage surface, full file). |
| AC4 | Post-merge, total Dart compile error count on `main` drops by exactly the chat-attributable count (currently **67** under this baseline, ~39 in the LEAD pin's stale snapshot) | QA-POST captures `dart analyze 2>&1 | tee qa/T-MOB-FIX-005/post-fix-analyze.log` on the merge commit and asserts `pre_fix_total - post_fix_total == chat_attributable`. Baseline: 73 → expected post-fix: 6 (the non-chat warnings already in main). |
| AC5 | Given a fresh checkout, when I run `flutter analyze`, then no chat-related errors are reported | Same `post-fix-analyze.log` filtered for `features/chat\|test/chat_` — expected count: 0. |
| AC6 | `ChatMessage.toJson()` round-trips through `ChatMessage.fromJson()` losslessly | `test/chat_message_serialization_test.dart` — group `ChatMessage codec contract` tests: `round-trips with every field set (8-field identity)` (line ~17), `round-trips a default message (status=pending, attempts=0, serverId=null)` (line ~47), `toJson serializes createdAt in UTC even when given a local TZ` (line ~78), `toJson emits the lowercase enum name for status` (line ~93), `fromJson hydrates every status enum value` (line ~120). |

## QA-PRE-authored test inventory

1. **`test/chat_message_serialization_test.dart`** — EXTENDED.
   - Existing `ChatMessage` / `ChatEvent.fromJson` groups retained.
   - New `ChatMessage codec contract` group: 7 tests covering 8-field identity, defaults, exact JSON keys, UTC enforcement on `createdAt`, lowercase enum name on `status`, and `fromJson` tolerance of every enum value.
   - New `ChatMessage.copyWith` group: 3 tests covering identity preservation, no-arg round-trip, and per-field replacement.

2. **`test/chat_message_status_test.dart`** — NEW.
   - `ChatMessageStatus enum surface`: pinned value list + order (per LEAD Decision 3).
   - `ChatMessage status transitions via copyWith`: happy path (`pending → sent → delivered → read`), dead-letter (`pending → failed`), retry semantics (`failed → pending` + `attempts = 0`), attempts-counter independence.
   - `ChatOutbox.markFailed default impl`: 5 tests across `SharedPrefsChatOutbox` and `InMemoryChatOutbox` covering "flips status, doesn't remove", "no-op for unknown id", "preserves attempts".

3. **`test/chat_connection_cubit_test.dart`** — UPDATED.
   - File-level docstring binding the wire-shape ctor contract.
   - `retry()` test extended: explicit `attempts == 1` assertion (the resend bumps from 0 → 1, confirming reset happened).

4. **`test/chat_outbox_test.dart`** — UPDATED.
   - File-level docstring binding the wire-shape ctor contract.
   - Added `markFailed default impl flips status without removing entry` (persistence-layer smoke against the real SharedPrefs store).
   - Added `survives reload after markFailed (status persists to disk)`.

5. **`test/chat_old_presentation_smoke_test.dart`** — NEW.
   - Pins the post-rename `DeliveryChatMessage` API: `.text(...)` and `.photo(...)` factories, every getter (`id`, `author`, `sentAt`, `status`, `kind`, `text`, `photoBytes`, `photoSource`, `isMine`, `isPhoto`, `isText`), `copyWith(status:)`.
   - Pins sibling enums `ChatAuthor`, `MessageStatus` (sending/sent/delivered/read/failed — distinct from the wire-shape `ChatMessageStatus`), `MessageKind`.
   - **Expected to compile-fail on `main`** until ENG creates `lib/features/chat/domain/delivery_chat_message.dart`. Per the hardened DoD on JEB-1424.

## Out of QA-PRE scope (handed back to QA-POST / orchestrator)

- Running the new tests green (ENG owns the implementation).
- Updating the 8 OLD-presentation callers to import `delivery_chat_message.dart` (ENG, files #3–#10 in LEAD pin Decision 5).
- iOS/Android smoke (QA-POST: offline-send → reconnect → bubble transitions; survive app kill).
- Final `dart analyze` error-delta calculation against AC4 (QA-POST captures post-merge baseline).
