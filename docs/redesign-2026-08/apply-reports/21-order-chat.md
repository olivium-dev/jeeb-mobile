# 21 · Order chat — implementation report

Branch `feat/redesign-24-migration`. Instruction set: `per-screen-revised/21-order-chat.md`.
Status: **applied** (tasks 1–10 landed; three deliberate divergences from the instruction set are
called out below, each with the measurement that forced it).

---

## What shipped

| File | Change |
|---|---|
| `lib/features/chat/presentation/widgets/chat_app_bar.dart` | rebuilt on `JeebTopBar.identity`; `actions: List<Widget>?` → `trailing: JeebTopBarAction?`; `+ rating`; `_ChatBackButton`/`_ChatHeaderLeading`/`_UrlOrInitialAvatar`/`OMDSAppBar` deleted |
| `lib/features/chat/presentation/chat_screen.dart` | app-bar args, strip `onTrack` wiring, quick-reply mount + reserve, list padding, row clustering |
| `lib/features/chat/presentation/widgets/order_chat_pinned_summary.dart` | `JeebNavySurfaceCard` shell (r14, `stripShadow`, no border), Ø8 accent dot, capsule-free collapsed line, white `Track` pill, re-toned expanded block, `_SummaryChip` on `JeebSurfaceTone.chipFill` |
| `lib/features/chat/presentation/widgets/chat_message_bubble.dart` | rebuilt on `JeebChatBubble` / `JeebChatMedia` / `JeebChatStatus` / `JeebWaveform.inBubble`; `+ clustered` |
| `lib/features/chat/presentation/widgets/chat_composer.dart` | mounts `JeebChatComposer` |
| `lib/features/chat/presentation/widgets/chat_composer_icon_button.dart` | **DELETED** (zero consumers after the swap) |
| `lib/features/chat/presentation/widgets/system_message_bubble.dart` | `JeebSystemChip.filled` (settled fact) / `.outlined` (live event) + the ` · HH:mm` suffix |
| `lib/features/chat/presentation/widgets/chat_date_separator.dart` | `OmdsDateChip` → `JeebSystemChip.filled` |
| `lib/features/chat/presentation/widgets/broadcast_ttl_indicator.dart` | full-bleed `tertiaryContainer` slab → centred `JeebSystemChip.accent` |
| `lib/features/chat/presentation/widgets/chat_offer_only_one_footer.dart` | ink `colorScheme.tertiary` → `context.jeebRoles.accent` |
| `lib/features/chat/application/chat_cubit.dart` | `+ sendQuickReply` |
| NEW `lib/features/chat/presentation/widgets/chat_quick_reply_bar.dart` | consumer of `JeebQuickReplyRow` |
| NEW `lib/features/chat/presentation/chat_redesign_l10n.dart` | feature-local l10n stopgap (see below) |

`lib/features/deep_link_targets/chat_detail_screen.dart` is **untouched**, as the instruction set
verified: its one `ChatAppBar` mount is title-only, so the `actions:` → `trailing:` swap does not
reach it.

## Refusals kept (all board-drawn, none shipped)

* **mic in the composer circle** — B-04. The board draws a mic in the SEND slot and no send button,
  so shipping it is "replace send with a mic". Send + attach shipped; `chat_detail_voice_button`
  stays absent.
* **green presence dot** — no counterpart-presence signal exists anywhere (`ChatConnectionCubit`
  reports MY socket and has zero consumers).
* **call button** — no phone number reaches this surface; the trailing circle keeps
  `order_chat_open_dispute`.
* **"usually replies in 1 min"** — no field exists. Omitted with a `TODO(redesign-24)` at the slot.
* **one bubble carrying voice + photo** — `MessageKind` is one-of; rendered honestly as two
  consecutive same-author bubbles with a tightened gap (`clustered`).
* **playable voice note** — the Ø32 disc renders inert (`onPlay: null`, no identifier).
* **yellow star** — the ★ inherits the subtitle ink; `starRatingColor` is not consumed here.

## Divergences FROM the instruction set (with the evidence)

1. **Every ink on the navy strip is `onPrimary`.** §7 prescribed a two-ink hierarchy (facts
   `onPrimary`, qualifiers `onSecondaryContainer` "4.59:1"). That number is **light-only**: in the
   dark theme `colorScheme.primary` inverts to a pale periwinkle card and `onSecondaryContainer`
   on it measures **1.32:1**. No scheme role is both visibly muted and ≥AA on `primary` in both
   themes (every `on*`/container role was measured), and the tone's `mutedInk` is a `.7` alpha that
   the alpha guard correctly refuses. Hierarchy is now type size + weight. A new negative control
   in `chat_header_contrast_test` pins the 1.32:1 reading so the refusal cannot be quietly undone.
2. **New strings ship through a feature-local `ChatRedesignL10n`**, not through missing
   `AppLocalizations` getters. The wiring request in `wiring/21-order-chat.md` is unchanged and
   still the real ask; this is the `LiveTrackingL10n` / `OtpHandoverL10n` precedent from screens 12
   and 13, and it is what keeps this lane at **0 analyzer errors** today. Delete the file when the
   integrator lands the batch.
3. **Strip radius is a literal `14`**, not `Spacing.small` (12). The kit's own radius doc lists 14
   for screen 21 and permits design-exact px on that parameter; 12 visibly squares the strip
   against the 18-radius bubbles under it.

## Bug found and fixed inside this lane

While bisecting two red regression suites I found that my own edit to `_ChatMessageList` had
dropped `controller: controller` from the `ListView`. The `ScrollController` was then never
attached (`hasClients == false` in the post-frame callback), so **the thread stopped auto-scrolling
to the newest message** — the last rows simply never laid out. Restored and pinned by the two
suites that caught it (`bilateral_empty_thread_regression_test`, `dev_chat_sending_fixture_test`).

## Tests

**Updated (design legitimately changed — shape and intent preserved):**

* `chat_dm_header_parity_test` D2 — `arrow_back_ios` → `DirectionalIcons.back` glyphs; directional
  intent still asserted in both directions.
* `chat_dm_header_parity_test` D3 — **REVERSED on the design's authority** (the render draws `9:24`
  on the incoming bubble): both bubbles carry a time, and the assertion is narrowed to the rule that
  survives — only the sender's bubble carries a delivery status.
* `chat_header_contrast_test` — binding block rewritten against the navy roles; the measured table's
  H1 rows re-based on `primary` with the chip fill **blended** (`onPrimary @ .14` over navy) rather
  than measured as if opaque; two new rows for the Track pill. No threshold lowered; the alpha guard
  is untouched and still green.
* `chat_screen_test` — the two `tester.widget<ChatComposerIconButton>(…).onPressed` reads become
  semantics assertions on `ChatComposer.sendButtonKey` (the deleted type has no replacement widget
  to read).
* `chat_image_bubble_source_test` — the documented pre-existing "unbounded OmdsCachedImage shimmer
  throws" is **fixed** by the kit's measured 120×74 tile; the test now asserts `takeException()` is
  null so a regression to an unbounded tile reds it.
* `firestore_realtime_chat_test` — `find.text` → `find.textContaining` on the system row, which now
  carries its ` · HH:mm`.

**New:**

* `test/features/chat/chat_quick_reply_bar_test.dart` — row present on the accepted client thread;
  absent on the Jeeber leg, in `broadcasting`, and in the COMPOSE state; one tap = exactly one
  outgoing message with an empty composer; the Arabic pill is not force-directioned; plus the
  `ChatCubit.sendQuickReply` unit test.
* `test/features/chat/order_chat_strip_redesign_test.dart` — `order_chat_track_cta` absent with no
  route and with an empty `deliveryId`, present + 48 dp + tappable otherwise, and riding in the
  COLLAPSED row; system chip prints ` · HH:mm` only for a dated row.

**Gates**

* `dart analyze lib/features/chat lib/features/deep_link_targets/chat_detail_screen.dart` → **No
  issues found** (0 errors, 0 new warnings/infos).
* `flutter test test/features/chat/ test/chat_*.dart` → **489 passing, 0 failing**;
  `chat_header_overflow_test` re-run last, green.
* `bash tool/check_design_tokens.sh` → 6 violations repo-wide, **0 in `lib/features/chat`**
  (settlement ×3, location, wallet, reviews — all pre-existing, other lanes').
* `bash qa/t-mob-fix-002/l10n_parity_check.sh` → red on 89 missing getters repo-wide, **0 of them
  chat's** (kyc, rating, request_type, home_client — other lanes' pending wiring).
* Blocked by other lanes, not by this one: `test/decision_violations_test.dart` and
  `test/semantics_identifier_surfacing_test.dart` cannot COMPILE right now because
  `mutual_rating_screen.dart`, `kyc_wizard_screen.dart`, `request_type_screen.dart`,
  `client_home_greeting.dart` and `replies_card.dart` call `AppLocalizations` getters that do not
  exist yet. Nothing in `lib/features/chat` contributes to that; both files should be re-run after
  the integrator lands the l10n batches.

## Advisory (already in the wiring file, repeated here)

Four Maestro flows still `assertVisible: id: "chat_detail_voice_button"`
(`02-chat-client.yaml:175`, `03-chat-after-aproval-client.yaml:179`,
`04-delivery-screen-chat-delivery-man.yaml:92`, `07-chat-dm-blank.yaml:128`). They have been stale
since B-04 and were NOT edited by this lane. They must be fixed by deleting the assertions, never
by resurrecting the mic.

Side effect worth stating: `chat_detail_back_button` is now emitted on **every** header variant —
the old `showBackButton: !showAvatar` OMDS branch carried no identifier. Strictly better for Maestro.
