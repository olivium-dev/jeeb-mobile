# 21 · Order chat — REVISED instruction set (authoritative)

Reviewed against: `screens/21-order-chat.{png,html,note.md}`, the live source of every lane file,
the shipped kit source in `lib/core/widgets/jeeb/` (Wave 1 is REAL — 31 files, 476 tests green),
`03-WAVE1-KIT.md`, `00-MIGRATION-PLAN.md` §4/§4.6/§5/§7.2, `02-PLAN-ENHANCED.md` R1/R5/R7/R8,
`_BASELINE.md`, and every cited test. Every `file:line` below was re-checked on 2026-08-03.
Where this document contradicts the original proposal, **this document wins**.

Verdict: **rebuild the chrome, restyle the thread, add the quick-reply row.** The cubit's data
flow gains exactly one method (`sendQuickReply`). **No route, DI, theme, or kit edit. No container
edit** — `lib/features/deep_link_targets/chat_detail_screen.dart` is verified untouched: its only
`ChatAppBar` mount is title-only (`:1676`), and `onTrackOrder` (`→ /orders/:id/tracking`),
`onViewSummary` (`→ order-summary`), `onOpenDispute` (`→ escalate`) are already wired
(`:1740-1788`).

## What changed vs the original proposal

- **VOID → kit.** The proposal's §5.5 hand-rolls the composer pill from `OmdsTextField` +
  `suffixIcon` (with a fallback plan for hit-targets). The kit ships **`JeebChatComposer`**
  (`jeeb_chat_composer.dart:26-49`) with `fieldKey`/`attachKey`/`sendKey` and
  `inputIdentifier`/`attachIdentifier`/`sendIdentifier` pass-throughs, `isAttaching`, and the exact
  board pill (h52 grows, 19px `image_outlined` attach, Ø38 send circle, `.38` disabled fade,
  `TextInputAction.newline` + sentence caps hardcoded at `:209-210` — same as today). Consume it.
  Hand-rolling this is a review defect.
- **VOID → kit.** The proposal's screen-local outline pill for the TTL countdown: the kit ships
  **`JeebSystemChip.accent`** and its own doc names `broadcast_ttl_indicator.dart` as the consumer
  (`jeeb_system_chip.dart:27-30`). Consume it.
- **CORRECTED the strip shadow:** `JeebShadows.ctaNavy` (0 10 24) → **`JeebNavySurfaceCard.stripShadow`**
  (`jeeb_navy_surface_card.dart:138`, `0 8 20 rgba(11,19,81,.25)`) — the kit measured it from this
  screen's HTML (`box-shadow: rgba(11,19,81,0.25) 0px 8px 20px`, html:25) and shipped it for 21.
- **CORRECTED the trailing-slot mechanism:** `JeebTopBar.trailing` takes a **`JeebTopBarAction`**
  (icon + onPressed + identifier + semanticLabel), not a Widget — "render `actions.first` in the
  trailing circle" cannot compile. `ChatAppBar`'s `actions: List<Widget>?` is **replaced** by
  `trailing: JeebTopBarAction?` (both production call sites verified: `chat_screen.dart:464`
  passes the dispute affordance — lane-owned, rebuilt in task 3; `chat_detail_screen.dart:1676`
  passes title only — unaffected).
- **CORRECTED the avatar slot:** `JeebAvatar` takes `imageUrl` only — there is no `ImageProvider`
  param, and `chat_dm_header_parity_test` D1 (`:112-114`) pins the pre-resolved-image case to
  ClipOval + Image. Keep the image-provider branch screen-local (Ø42 ClipOval+Image) and use
  `JeebAvatar` for the url/initial fallback. Keep the whole `chat_detail_avatar` Semantics idiom
  in `chat_app_bar.dart` (pass the wrapped cluster into `JeebTopBar.avatar`, leave
  `avatarIdentifier: null` — the kit's avatar wrapper has no `label`/`button` params and would
  split the node).
- **CUT the `chat_bubble_timestamp.dart` restyle.** `JeebChatBubble` owns the meta line (`time:`
  is a pre-formatted String in an LTR isolate; ink is `metaInkOf` — incoming `onSurfaceVariant`,
  outgoing `onSecondaryContainer`, already implemented and documented at
  `jeeb_chat_bubble.dart:208-209/342-349`). The proposal's §2.1 "deliberate divergence" on the
  incoming timestamp is therefore **already the kit's shipped decision** — nothing for this lane
  to flag. `ChatBubbleTimestamp` stays untouched: `offer_card_bubble.dart` (out of scope) still
  consumes it.
- **CUT the §8.4 meta-line isolate micro-spec** (word outside the LTR isolate) — kit-owned.
- **CUT the waveform / play-disc / 120×74 tile geometry specs** — `JeebChatMedia.voice/.photo`
  and `JeebWaveform.inBubble` own them.
- **ADDED a missed will-break:** `test/chat_screen_test.dart:119-126` reads
  `tester.widget<ChatComposerIconButton>(find.byKey(ChatComposer.sendButtonKey))` — that type dies
  with the kit swap. Rewrite the two reads as semantics-enabled assertions (task 8). After the
  swap `chat_composer_icon_button.dart` has zero consumers (verified: only `chat_composer.dart`,
  that test, and a comment in `confirm_delivery_action_sheet.dart:254`) — **delete the file**.
- **ADDED missed must-stay-greens:** `test/semantics_identifier_surfacing_test.dart`
  (`chat_detail_message_<id>`/`_read` surfacing `:173-179`; `order_summary_pinned` leaf-id
  non-folding `:578-629`), `test/chat_message_bubble_rtl_test.dart` (`:78,:97` — directional
  alignment), `test/features/chat/chat_header_status_chip_stale_test.dart` (`:114` reads the Texts
  under `order_summary_status` — the id must stay on the collapsed status text).
- **CORRECTED the parity-script path:** `qa/t-mob-fix-002/l10n_parity_check.sh`
  (`tool/l10n_parity_check.sh` does not exist).
- **HARDENED the quick-reply gate** with `!viewerIsJeeber`: the canned lines ("I'm home", "Call me
  at the door") are client-voice; `ChatScreen` also hosts the Jeeber leg, and the board only
  evidences the client thread.
- **HARDENED the on-navy chip fill:** the expanded block's `_SummaryChip` fill comes from
  `JeebSurfaceTone.of(context).chipFill` (navy publishes `onPrimary @ .14`,
  `jeeb_surface_tone.dart`) — never hand-mixed alpha. **Text/Icon inks stay solid roles**
  (`onPrimary` / `onSecondaryContainer`) — `chat_header_contrast_test.dart:155-184` fails ANY
  alpha-faded foreground in the strip, so `tone.mutedInk` (`.7`) is banned for text here.
- **KEPT every refusal** (§2 below) — all re-verified, including the presence dot: the plan's kit
  table (`00-MIGRATION-PLAN.md:386`) lists 21 as the `presence` dot consumer, but no
  counterpart-presence signal exists anywhere in the app (`ChatConnectionCubit` reports MY socket
  and has zero consumers in `lib/` — verified). Data honesty outranks the table: the dot slot
  stays null.
- **KEPT the C1 resolution** (board shape, pinned vocabulary), the D3 reversal (incoming
  timestamp now renders — the board draws `9:24`, html:35), the B-04 send-not-mic refusal, and the
  rating pass-through (`OrderChatSummary.rating` verified real:
  `order_chat_summary.dart:46`, populated from `jeeberRating` at
  `dio_order_chat_summary_repository.dart:120-122`).

---

## 0. Files and kit policy

Lane owns (all verified to exist at these paths):

| File | Change |
|---|---|
| `lib/features/chat/presentation/chat_screen.dart` | app-bar args, strip `onTrack` wiring, quick-reply mount, list padding, reserve |
| `lib/features/chat/presentation/widgets/chat_app_bar.dart` | rebuild body on `JeebTopBar.identity` |
| `lib/features/chat/presentation/widgets/order_chat_pinned_summary.dart` | navy shell + re-tone + Track pill |
| `lib/features/chat/presentation/widgets/chat_message_bubble.dart` | rebuild bubbles on `JeebChatBubble` |
| `lib/features/chat/presentation/widgets/chat_composer.dart` | mount `JeebChatComposer` |
| `lib/features/chat/presentation/widgets/chat_composer_icon_button.dart` | **DELETE** (dead after the swap) |
| `lib/features/chat/presentation/widgets/system_message_bubble.dart` | `JeebSystemChip` |
| `lib/features/chat/presentation/widgets/chat_date_separator.dart` | `JeebSystemChip.filled` |
| `lib/features/chat/presentation/widgets/broadcast_ttl_indicator.dart` | `JeebSystemChip.accent` |
| `lib/features/chat/presentation/widgets/chat_offer_only_one_footer.dart` | ink swap only |
| `lib/features/chat/application/chat_cubit.dart` | +`sendQuickReply` |
| NEW `lib/features/chat/presentation/widgets/chat_quick_reply_bar.dart` | consumer of `JeebQuickReplyRow` |
| this screen's tests (§4) | update/add |

**Untouched:** `chat_detail_screen.dart`, `chat_bubble_timestamp.dart`, `offer_card_bubble.dart`,
`offer_accepted_banner.dart`, `chat_fee_banner.dart`, `jeeber_removed_banner.dart`,
`confirm_delivery_action_sheet.dart`, `chat_header_expansion_store.dart`, `auto_direction_text.dart`,
everything in `lib/core/**` and `lib/l10n/**` (wiring requests only).

Kit consumed (import `package:jeeb_mobile/core/widgets/jeeb/<file>.dart`; signatures in
`03-WAVE1-KIT.md`, all re-verified against source):

| Widget | Lands in | Signature anchors |
|---|---|---|
| `JeebTopBar.identity` + `JeebTopBarAction` | `chat_app_bar.dart` | `identifier:` → the leading circle; `leadingTooltip:` = a11y label; `avatar:`/`avatarIdentifier:`/`onAvatarPressed:`; `trailing: JeebTopBarAction(icon, onPressed, identifier, semanticLabel, iconSize)`; default back = `Navigator.maybePop` |
| `JeebAvatar` | avatar url/initial branch | `initial:` (full name ok), `diameter: 42`, `imageUrl:`; **`dot: null`** (§2) |
| `JeebNavySurfaceCard` | strip shell | `radius:`, `padding:`, `shadow: JeebNavySurfaceCard.stripShadow`, publishes the navy `JeebSurfaceTone` |
| `JeebChatBubble` + `JeebChatMedia` + `JeebChatStatus` | `chat_message_bubble.dart` | `side:`, `text:` xor `child:` (pass `AutoDirectionText` **without a style**), `media:`, `time:` (String, LTR-isolated), `status:` (`.icon(...)` / `.text(...)` with `identifier`/`semanticLabel`/`nodeKey`), `bubbleKey:`, `maxWidthFraction: 0.78` default |
| `JeebWaveform.inBubble()` | voice media slot | no geometry params, side-aware via tone |
| `JeebSystemChip.filled/.outlined/.accent` | system bubble, date chip, TTL | `label:`, `identifier:`, `semanticLabel:`, `center:`, `key:` |
| `JeebChatComposer` | `chat_composer.dart` | full param list at `jeeb_chat_composer.dart:26-49` |
| `JeebQuickReplyRow` + `JeebQuickReply` | new `chat_quick_reply_bar.dart` | `replies:`, row `identifier:`/`semanticLabel:`; per-pill `label`/`onTap`/`identifier` |
| `JeebSurfaceTone.of(context)` | `_SummaryChip` re-tone | `chipFill`/`chipInk` only — never `mutedInk` for strip text |

The white **Track pill is screen-local by kit design** (`03-WAVE1-KIT.md` §5: "21's white 'Track'
pill … screen-local (no on-navy unselected chip exists in the kit, by design)").

Tokens: `lib/features/chat/**` is NOT in `no_raw_semantic_colors_test.dart` (verified: zero
matches), but `tool/check_design_tokens.sh` bans hex, `Colors.*`, `fontSize:`,
`BorderRadius.circular(N)`, raw `EdgeInsets`, and sized `SizedBox` here. Design-exact px (14-radius,
6/13 pill pad…) that have no token snap to the nearest token (noted inline below) — never a raw
literal. Type via `context.jeebText` (verified sizes: `body` 13.5, `bodySmall` 12, `caption` 11.5,
`label` 10.5). Orange via `context.jeebRoles.accent`. Periwinkle = `colorScheme.onSecondaryContainer`
(`app_theme.dart:140`). `JeebSemanticColors` is not read by this screen; `readTick` is banned
(`00-MIGRATION-PLAN.md:213`).

---

## 1. Semantics inventory — FROZEN (re-greped from source 2026-08-03)

Every identifier below is emitted today and must survive **byte-identically**:

```
chat_screen.dart          order_chat_open_dispute · chat_history_error · chat_detail_message_list
chat_app_bar.dart         chat_detail_back_button · chat_detail_avatar
chat_composer.dart        chat_detail_message_input | order_chat_composer_input   (param-driven)
                          chat_detail_send_button   | order_chat_composer_send    (param-driven)
                          chat_detail_attach_button
chat_message_bubble.dart  chat_detail_message_<id> · chat_detail_message_sending/_sent/
                          _delivered/_read/_failed
chat_date_separator.dart  chat_detail_date_separator
chat_offer_only_one_footer.dart  chat_detail_offer_only_one_note
order_chat_pinned_summary.dart   order_chat_pinned_summary · order_summary_pinned ·
                          order_chat_summary_reference · order_summary_status · order_summary_price ·
                          order_chat_summary_expand · order_summary_jeeber_name ·
                          order_chat_view_summary_link · order_chat_request_description ·
                          order_summary_item · order_summary_eta · order_summary_tier ·
                          order_chat_cash_label · order_summary_cash_label
offer_card_bubble.dart    chat_detail_accept_<offerId> · chat_detail_decline_<offerId>   (untouched)
offer_accepted_banner.dart / chat_fee_banner.dart / confirm_delivery_*                    (untouched)
chat_detail_screen.dart   chat_resolution_error                                           (untouched)
```

Frozen `Key`s: `ChatComposer.textFieldKey/sendButtonKey/attachButtonKey`,
`Key('chat-bubble-<id>')`, `Key('chat-photo-<id>')`, `Key('chat-image-<id>')`,
`Key('chat-voice-<id>')`, `Key('chat-status-<id>')`, `Key('chat-system-<id>')`,
`Key('chat-date-separator')`, `Key('broadcast-ttl-indicator')`, `ChatScreen.rootKey/
messageListKey/emptyStateKey/historyErrorKey`, `chatHeaderSlotKey`.

Nesting rule: `chat_message_bubble.dart:48-51` and `order_chat_pinned_summary.dart:249-265` use
`container: true` + `explicitChildNodes: true` boundaries so inner ids stay first-class nodes —
`semantics_identifier_surfacing_test.dart:173-179/578-629` asserts exactly this. The kit widgets
add no `MergeSemantics` (verified), so keep the existing outer wrappers verbatim.

**`chat_detail_voice_button` must stay absent** (B-04). Four stale Maestro flows still assert it
(`.maestro/flows/02-chat-client.yaml:175`, `03-chat-after-aproval-client.yaml:179`,
`04-delivery-screen-chat-delivery-man.yaml:92`, `07-chat-dm-blank.yaml:128` — verified). Maestro is
not in CI; the Dart guard (`chat_composer_no_mic_b04_test.dart`) wins. Flag the flows to the E2E
owner via the wiring file's advisory — do NOT edit them, do NOT resurrect the mic.

New identifiers (intent-keyed, `<screen>_<element>`):

| New id | Element |
|---|---|
| `order_chat_track_cta` | white `Track` pill in the navy strip (verified unused anywhere today) |
| `order_chat_quick_reply_row` | row container (the kit emits it `container: true` + `explicitChildNodes: true`) |
| `order_chat_quick_reply_home` / `_door` / `_thanks` | the three pills (the kit's own tests already model these ids) |

No identifier for the voice play disc — it is non-interactive (`onPlay` MUST stay null, B-04; the
kit doc pins this at `JeebChatMedia.voice`).

---

## 2. Refusals & divergences from the board (state each in the PR)

| Board draws | Ship | Why |
|---|---|---|
| mic in the Ø38 composer circle, **no send button anywhere** | **send** (`Icons.send`) + attach | B-04: `chat_composer_no_mic_b04_test.dart` asserts `Icons.mic_none` and `chat_detail_voice_button` absent; the kit composer enforces it. This is "replace send with a mic" — refused |
| green presence dot on the avatar | no dot | no counterpart-presence signal exists; `ChatConnectionCubit` = MY socket, zero consumers. Overrides the plan's kit-table row (`00-MIGRATION-PLAN.md:386` lists 21 under `presence`) — data honesty wins |
| call button (trailing circle) | existing dispute affordance (`order_chat_open_dispute`) | no phone number reaches this surface; the one gated contact path is `DeliveryStatusCubit.requestContactNumber()` (`delivery_status_cubit.dart:108`), on another screen |
| `usually replies in 1 min` | omit + `// TODO(redesign-24): needs gateway reply-latency — omitted, not faked.` | no field anywhere; `02-PLAN-ENHANCED.md:274` lists it as genuinely suspect |
| `Medicine · In transit · $8 cash` (item name as heading, no View-summary, inline cash) | board's SHAPE (navy r14 card, shadow, Ø8 accent dot, one line, white Track pill) + today's four pinned strings | `order_chat_pinned_summary_labels_test.dart` pins heading = `friendlyReference`, link = "View summary", cash = "Pay cash on delivery", status = `deliveryStage*`; `chat_header_a11y_test` pins the collapsed/expanded split. Item name already lives at `order_chat_request_description` in the disclosed block |
| one bubble carrying voice + photo | two consecutive same-author bubbles, clustered gap | `MessageKind` is one-of (`delivery_chat_message.dart`); `JeebChatMedia` is one-of. The wire cannot express both — never fake it |
| playable voice note | Ø32 disc rendered inert (`onPlay: null`, no id) | no audio player exists; an id on a permanent no-op is the B-04 defect class |
| ★ tinted yellow | ★ inherits the periwinkle subtitle ink | `00-MIGRATION-PLAN.md:212`: `starRatingColor` is for 11/12/15 only; 21's ★ inherits |
| incoming bubble has a timestamp (`9:24`) | ship it — **reverses D3** | the render is the spec; `chat_dm_header_parity_test.dart:156-173` is updated (one test, §4). Incoming shows time only, never a status node |

Counterpart rating is **not** the §7.2-C3 conflict: C3 blocks screen 12's star because
`DeliveryTrackingInfo.fromTrackingJson` nulls `rating`. This screen reads `OrderChatSummary.rating`
— a different DTO on a different repository, really populated (verified). **Do not import the
tracking model here.**

D56/D52/D20, fee-vocabulary, deleted-features: none appear on this screen. The quick-reply row is
a new affordance, not a revival. No commission/fee copy is added.

---

## 3. Task list — execute top to bottom

**Task 1 — Write the wiring file.** Create `docs/redesign-2026-08/wiring/21-order-chat.md` with
the exact blocks from §6. From here on, code as if the l10n batch is granted (the lane won't
compile clean until the integrator lands it — expected; say so in your report).

**Task 2 — `chat_cubit.dart`: one method.** Place next to `sendText()` (`:673`):

```dart
/// One-tap quick reply: stage [text] and send in one call so the composer
/// field never round-trips through the canned string.
Future<void> sendQuickReply(String text) async {
  emit(state.copyWith(composerText: text));
  await sendText();
}
```

`sendText` (`:673-693`) already trims, appends optimistically, and clears `composerText` — no other
cubit change. Add a cubit test: `sendQuickReply('I\'m home')` appends exactly one outgoing text
message and leaves `composerText` empty.

**Task 3 — `chat_app_bar.dart`: rebuild the body on `JeebTopBar.identity`.**
Keep the class, `PreferredSizeWidget`, and params `title/avatarUrl/avatarImage/showAvatar/
onAvatarTap`; **replace** `actions: List<Widget>?` with `trailing: JeebTopBarAction?`; **add**
`rating: double = 0`.

```
preferredSize = Size.fromHeight(Sizes.sevenXLarge)          // 72
build:
  Material(color: colorScheme.surface, elevation 0)
    └ SafeArea(bottom: false)
        └ JeebTopBar.identity(
            identifier: 'chat_detail_back_button',           // lands on the Ø40 back circle
            leadingTooltip: l10n.chatBackA11y,
            title: title,                                    // identity scale: 16/w700, 1 line
            subtitleSlot: rating > 0 ? _RatingLine(rating) : null,
            avatar: showAvatar ? _avatarCluster() : null,    // null = title-only (broadcasting/error page)
            avatarIdentifier: null,                          // our own Semantics wrapper below
            trailing: trailing,
          )
```

- `_avatarCluster()`: keep today's `chat_detail_avatar` node shape verbatim —
  `Semantics(identifier: 'chat_detail_avatar', button: onAvatarTap != null, label: l10n.chatAvatarA11y)`
  around (`onAvatarTap != null ? GestureDetector(opaque) : identity`) around the visual: when
  `avatarImage != null` keep the existing ClipOval + Image at Ø42 (D1 pins ClipOval+Image
  count); else `JeebAvatar(initial: title, imageUrl: avatarUrl, diameter: JeebTopBar.identityAvatarDiameter)`.
  Delete `_ChatBackButton`, `_ChatHeaderLeading`, `_UrlOrInitialAvatar`, `OMDSAppBar`, and the
  `isRtl` glyph pick (`:123-129`) — the kit's leading circle uses `DirectionalIcons.back(context)`
  (verified: `arrow_back`/`arrow_forward`, `directional_icons.dart:16-17`).
- `_RatingLine(rating)`: `Semantics(label: l10n.chatCounterpartRatingA11y(value), child:
  ExcludeSemantics(child: Row(min, [star glyph, gap 4, Directionality(ltr, Text(value))])))` where
  `value = rating.toStringAsFixed(1)`; style `jeebText.caption` w600, ink
  `colorScheme.onSecondaryContainer`; the ★ is `Icons.star_rounded` at `Sizes.medium` in the SAME
  periwinkle ink — never `starRatingColor`. LTR isolate so `4.9` never renders `9.4`.
- Side effect (call out in the PR): `chat_detail_back_button` is now emitted on EVERY header
  variant — the old `showBackButton: !showAvatar` OMDS branch (`:69`) carried no id. Strictly
  better for Maestro.

**Task 4 — `chat_screen.dart`: feed the new app-bar API + strip wiring + row mount.**

- `:464-484`: replace the `actions:` list with

  ```dart
  rating: widget.pinnedSummary?.rating ?? 0,
  trailing: showDispute
      ? JeebTopBarAction(
          icon: Icons.report_gmailerrorred_outlined,
          onPressed: widget.onOpenDispute!,
          identifier: 'order_chat_open_dispute',
          semanticLabel: l10n.escalateTitle,
          iconSize: 18,
        )
      : null,
  ```

  The `showDispute` gate (`:455-461`) is unchanged.
- `_buildBody` → `_ChatBody`: add `onTrackSummary` (new prop) computed from props already in scope:

  ```dart
  onTrackSummary: (widget.onTrackOrder != null &&
          (widget.pinnedSummary?.deliveryId.isNotEmpty ?? false))
      ? () => widget.onTrackOrder!(widget.pinnedSummary!.deliveryId)
      : null,
  ```

  This is deliberately NOT `_trackOrderCallback` (`:544-549`): that one needs
  `state.canTrackDelivery` (an accept-response id captured this session); the strip's id comes from
  the resolved summary and exists on a cold open of an already-accepted thread — the exact case the
  board draws. Pass it into `OrderChatPinnedSummary(onTrack: ...)` at the `:703-710` mount.
- Quick-reply mount in `_ChatBody`'s Column between `Expanded(child: body)` (`:810`) and
  `ChatComposer` (`:811-829`):

  ```dart
  final showQuickReplies = state.isComposerVisible &&
      state.phase != ConversationPhase.broadcasting &&
      onFirstMessageBroadcast == null &&     // compose-state guard — see below
      !viewerIsJeeber;                       // client-voice canned lines
  ...
  if (showQuickReplies) const ChatQuickReplyBar(),
  ```

  The compose guard is **load-bearing, not cosmetic**: in compose state the FIRST outgoing message
  broadcasts the request and becomes its description (`:585-607` → `onFirstMessageBroadcast`). A
  quick-tapped "I'm home" would create a request described "I'm home". Pass
  `onFirstMessageBroadcast == null` down to `_ChatBody` as a bool (`quickRepliesEnabled`) — the
  hook itself lives on `_ChatScaffold`.
- Overflow budget: the row is a new non-flexible Column child. Add

  ```dart
  /// Vertical room the quick-reply row adds to the non-flexible chrome when
  /// visible — folded into the composer reserve so the bounded header slot
  /// (see kChatComposerReserve) keeps the message list from starving.
  const double kChatQuickReplyReserve = 48;
  ```

  and in BOTH reserve subtractions inside `_ChatBody.build` (`:793-806`) replace
  `kChatComposerReserve * scale` with
  `(kChatComposerReserve + (showQuickReplies ? kChatQuickReplyReserve : 0)) * scale`.
  Re-run `chat_header_overflow_test` LAST (task 10) — prefer raising the reserve over weakening
  any bound.
- `_ChatMessageList` (`:988-995`): `padding` vertical `Spacing.small` → `Spacing.medium` (html:31
  `padding: 16px 24px 0`; the 24 gutter lands on the rows, task 6).
- Row clustering: `_rows()` (`:999-1014`) marks a message row `clustered: true` when the previous
  row is a message with the same `author` and both are non-system; thread it through `_ChatRowData`
  → `_ChatRow` → `ChatMessageBubble(clustered:)`. This is how the board's single "voice + photo"
  block is honestly rendered as two wire messages.

**Task 5 — NEW `chat_quick_reply_bar.dart`.**

```dart
/// Screen-local consumer of the kit's JeebQuickReplyRow: three client-voice
/// canned replies, one-tap send via ChatCubit.sendQuickReply.
class ChatQuickReplyBar extends StatelessWidget {
  const ChatQuickReplyBar({super.key});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<ChatCubit>();
    return JeebQuickReplyRow(
      identifier: 'order_chat_quick_reply_row',
      semanticLabel: l10n.chatQuickReplyRowA11y,
      replies: [
        JeebQuickReply(label: l10n.chatQuickReplyImHome,
            identifier: 'order_chat_quick_reply_home',
            onTap: () => cubit.sendQuickReply(l10n.chatQuickReplyImHome)),
        JeebQuickReply(label: l10n.chatQuickReplyCallAtDoor,
            identifier: 'order_chat_quick_reply_door',
            onTap: () => cubit.sendQuickReply(l10n.chatQuickReplyCallAtDoor)),
        JeebQuickReply(label: l10n.chatQuickReplyThanks,
            identifier: 'order_chat_quick_reply_thanks',
            onTap: () => cubit.sendQuickReply(l10n.chatQuickReplyThanks)),
      ],
    );
  }
}
```

The kit row owns padding (10/24/0 inside the scroll view), pills (8/13, 12/w600 navy, 1.5px
outline), horizontal scroll, and the no-forced-LTR rule (AR pill shapes itself — kit-asserted).
Do not wrap it in a second scroll view.

**Task 6 — `chat_message_bubble.dart`: rebuild on `JeebChatBubble`.**
Keep: the `SystemMessageBubble` early return (`:38-40`), the outer
`Semantics(identifier: 'chat_detail_message_<id>', container: true, explicitChildNodes: true)`
(`:48-51`), the per-kind routing switch, `_imageContent`'s source precedence **verbatim**
(`:335-354` — bytes ▸ absolute http(s) ▸ placeholder; a bare `imageUrl` is a CDN object_ref, not
fetchable), the a11y wrappers (`chatPhotoA11y`/`chatImageA11y`/`chatVoiceNoteA11y`), and every Key.
Delete: `_DirectionalBubble`, `_BubbleFooter`, `_StatusIcon`, `_ImagePlaceholder`,
`_VoicePlayerRow` (geometry now kit-owned).

- Row padding (`:53-56`): `horizontal: Spacing.medium` → `Spacing.xLarge` (the 24 gutter);
  `vertical: Spacing.twoXSmall`, or `top: Spacing.threeXSmall` when `clustered` (task 4).
- Shared helpers:

  ```dart
  JeebChatBubbleSide _sideOf(m) => m.isMine ? outgoing : incoming;
  String? _timeOf(context, m) => m.hasServerTimestamp
      ? DateFormat.Hm(Localizations.localeOf(context).toLanguageTag()).format(m.sentAt)
      : null;                                  // undated row → NO clock, ever
  JeebChatStatus? _statusOf(context, m) => !m.isMine ? null : switch (m.status) {
      sending   => JeebChatStatus.icon(Icons.access_time,
                     identifier: 'chat_detail_message_sending',
                     semanticLabel: l10n.chatMessageSendingA11y,
                     nodeKey: Key('chat-status-${m.id}')),
      sent      => ....icon(Icons.done, 'chat_detail_message_sent', ...),
      delivered => ....icon(Icons.done_all, 'chat_detail_message_delivered', ...),
      read      => JeebChatStatus.text(l10n.chatMessageReadLabel,      // the word, never a tick
                     identifier: 'chat_detail_message_read',
                     semanticLabel: l10n.chatMessageReadA11y,
                     nodeKey: Key('chat-status-${m.id}')),
      failed    => ....icon(Icons.error_outline,
                     iconColor: Theme.of(context).colorScheme.error,
                     'chat_detail_message_failed', ...),
    };
  ```

  All five status identifiers and their existing a11y labels survive; only `read` swaps its Icon
  for the localized word. **The counterpart bubble now carries `time` (D3 reversal) and never a
  `status`.** `context.omdsColorTokens.infoColor` (`:633`) and the double-blue-tick treatment are
  deleted with `_StatusIcon`.
- text → `JeebChatBubble(side:, child: AutoDirectionText(m.text) /* no style — kit inks it */,
  time:, status:, bubbleKey: Key('chat-bubble-${m.id}'))`.
- voice → `media: JeebChatMedia.voice(waveform: const JeebWaveform.inBubble(), label:
  _formatDuration(m.voiceDurationMs ?? 0), onPlay: null /* B-04 — no player exists */)`, plus
  `child:` = the existing transcription line when `voiceTranscription != null` (keep the
  `__unavailable__` branch). Keep `_formatDuration` (file-local). `Icons.play_arrow_rounded` is the
  kit default — `voice_note_bubble_widget_test.dart:110` keeps resolving.
- photo/image → `media: JeebChatMedia.photo(photo: <resolved widget or null>)`: pass the
  `Image.memory`/`OmdsCachedImage` widget from the existing precedence helpers; pass `photo: null`
  for the placeholder case (the kit draws the 120×74 r10 tile). `child:` = the caption
  `AutoDirectionText` when `m.text.isNotEmpty`.
- location → `JeebChatBubble(side:, child: <existing icon+text Row>, time:, status:)`.
- offerCard branch: unchanged (`ChatScreen` routes it before this widget).

**Task 7 — `order_chat_pinned_summary.dart`: navy shell, re-toned inks, Track pill.**
The `StatefulWidget` + `ChatHeaderExpansionStore` + `_expansionKey` + `_toggle` catch-up +
collapsed/expanded split are all pinned — restyle inside them, never around them.

- Add `final VoidCallback? onTrack;` (doc: "Routes to live tracking. Null hides the pill — never a
  dead end, the same G5 rule as `offer_accepted_track_cta`.").
- Shell (`:266-286`): replace `DecoratedBox` + its `Padding` with

  ```dart
  Padding(                                    // inset card, not a full-bleed slab
    padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge, Spacing.small, Spacing.xLarge, Spacing.xSmall), // 24/12/24/8 — nearest
    child: JeebNavySurfaceCard(               // tokens to the board's 24/14; bottom 8 keeps the
      radius: Spacing.small,                  // drop shadow clear of the slot's clip edge
      shadow: JeebNavySurfaceCard.stripShadow,
      padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.medium, vertical: Spacing.small),
      child: <existing Column, unchanged structure>,
    ),
  )
  ```

  No border (R7: the shadow IS the boundary on navy). The card publishes the navy tone.
- `_CollapsedRow`: keep the `Wrap` (`:402-405` — the text-scale overflow fix). New contents, in
  order: Ø8 dot (`Container(width/height: Spacing.xSmall, BoxDecoration(color:
  context.jeebRoles.accent, shape: circle))`, `ExcludeSemantics`) → reference → `·` → status → `·`
  → price. The two `·` separators are decorative `ExcludeSemantics` Texts.
  - reference (`:414-417`) and price (`:447-450`): `jeebText.bodySmall` + `FontWeight.w700`, ink
    `colorScheme.onPrimary` (board: 12.5/w700 white). Keep both Semantics wrappers verbatim.
  - status: **drop the `_SummaryChip` capsule** — a plain
    `Semantics(identifier: 'order_summary_status', container: true, label:
    l10n.orderChatFieldValueA11y(l10n.orderChatFieldStatus, statusLabel), child:
    ExcludeSemantics(Text(statusLabel, bodySmall w700 onPrimary)))`. The id stays on an element
    whose descendants are the status Texts — `chat_header_status_chip_stale_test.dart:114` keeps
    reading. Dropping the two capsules is what buys the width that lets `Track` fit on one line.
  - after the `Expanded(Wrap)`: the Track pill, then `_ExpandToggle` (unchanged ids/labels; icon
    ink `:493` → `colorScheme.onSecondaryContainer`).
- Track pill (screen-local, rendered only when `widget.onTrack != null &&
  summary.deliveryId.isNotEmpty`):

  ```dart
  Semantics(identifier: 'order_chat_track_cta', button: true, label: l10n.orderSummaryTrack,
    child: ExcludeSemantics(child: MinTapTarget(onTap: widget.onTrack!,   // 48dp floor —
      child: Container(                                                    // a11y test's bar
        padding: const EdgeInsetsDirectional.symmetric(
            horizontal: Spacing.small, vertical: Spacing.twoXSmall),       // nearest tokens to 6/13
        decoration: BoxDecoration(color: colorScheme.onPrimary, borderRadius: OmdsBorderRadius.pill),
        child: Text(l10n.orderSummaryTrack,
            style: context.jeebText.caption.copyWith(
                fontWeight: FontWeight.w700, color: colorScheme.primary)),
      ))))
  ```

  Copy reuses **`orderSummaryTrack`** — no new key.
- Expanded block — structure unchanged, inks re-toned (the §2.1 rule: fact = `onPrimary`
  15.6:1, qualifier = `onSecondaryContainer` 4.59:1 — both SOLID; the alpha guard at
  `chat_header_contrast_test.dart:155-184` must keep passing):
  - `_PartyRow` name (`:527-529`): `jeebText.bodySmall`, ink `onSecondaryContainer`.
  - view-summary link (`:563-569`): `jeebText.bodySmall` w700, ink `onPrimary`, underline kept
    (decorationColor `onPrimary`).
  - `_RequestDescription`: text ink `onPrimary`; icon ink `onSecondaryContainer`.
  - `_SummaryChip` (`:706-719`): fill `JeebSurfaceTone.of(context).chipFill`, **no border**;
    icon + resolved value ink `onPrimary`; the `orderSummaryValuePending` placeholder ink
    `onSecondaryContainer`. Keep the `"<field>: <value>"` label + `ExcludeSemantics` idiom and the
    48dp floor verbatim.
  - `_CashOnDeliveryRow` (`:615-630`): `jeebText.caption`, icon + text ink `onSecondaryContainer`.
- If the collapsed line reads too dense in review, the copy question goes to the owner (plan risk
  #11) — do **not** solve it by deleting a pinned string.

**Task 8 — `chat_composer.dart`: mount the kit pill; delete `chat_composer_icon_button.dart`.**
`ChatComposer` (the stateful class, its params, static Keys, `_send`, `_openAttachmentSheet`, the
`BlocListener` controller sync `:121-125`) all survive. Replace `_ComposerBar`/`_AttachButton`/
`_ComposerField`/`_SendButton` with:

```dart
BlocBuilder<ChatCubit, ChatState>(
  buildWhen: (p, c) => p.canSendText != c.canSendText || p.isAttaching != c.isAttaching,
  builder: (context, state) => JeebChatComposer(
    controller: _controller,
    focusNode: _focusNode,
    hintText: widget.hintText ?? l10n.chatComposerHint,
    onChanged: (v) => context.read<ChatCubit>().composerChanged(v),
    onSend: state.canSendText ? _send : null,     // null → .38 circle + Semantics(enabled:false)
    onAttach: _openAttachmentSheet,
    isAttaching: state.isAttaching,               // spinner swap + tap block, kit-owned
    fieldKey: ChatComposer.textFieldKey,
    attachKey: ChatComposer.attachButtonKey,
    sendKey: ChatComposer.sendButtonKey,
    inputIdentifier: widget.inputIdentifier,      // chat_detail_* | order_chat_composer_*
    attachIdentifier: 'chat_detail_attach_button',
    sendIdentifier: widget.sendIdentifier,
    inputSemanticLabel: ..., attachSemanticLabel: l10n.chatAttachA11y,
    sendSemanticLabel: l10n.chatSendA11y,
  ),
)
```

The kit owns: no top hairline (the old `:176-184` border is gone), padding 10/24 + SafeArea, the
h52 pill, the 19px `image_outlined` attach glyph, the Ø38 send circle, `TextInputAction.newline` +
sentence caps (`jeeb_chat_composer.dart:209-210` — behavior-identical). `onVoiceRecordingComplete`
stays on the class (dormant seam — do not remove). Then **delete
`chat_composer_icon_button.dart`** and its import.

**Task 9 — small files.**
- `system_message_bubble.dart`: keep `_copyFor` and the empty-string early-out and
  `Key('chat-system-<id>')`. Body → `JeebSystemChip`:
  `MessageKind.system` → `.outlined` (live/progress: "Karim is on the way · ETA 20 min");
  `offerAccepted`/`offerRejected` → `.filled` (settled facts). Label:
  `message.hasServerTimestamp ? l10n.chatSystemChipWithTime(copy, DateFormat.Hm(locale).format(message.sentAt)) : copy`
  — an undated row gets NO clock (`chat_undated_band_contract_test` exists precisely for this).
- `chat_date_separator.dart`: `OmdsDateChip` → `JeebSystemChip.filled(key:
  Key('chat-date-separator'), label: _label(...), identifier: 'chat_detail_date_separator',
  semanticLabel: _label(...))`. `_label` logic unchanged.
- `broadcast_ttl_indicator.dart`: timer/`didUpdateWidget`/hide-when-expired logic unchanged. The
  full-bleed `tertiaryContainer` Container (`:71-98`) → centred
  `JeebSystemChip.accent(key: Key('broadcast-ttl-indicator'), label:
  l10n.chatBroadcastTtlLabel(_secondsLeft))` inside `Padding(vertical: Spacing.xSmall)` (R5: a
  countdown is exactly "what is expiring right now").
- `chat_offer_only_one_footer.dart`: ink only — `colorScheme.tertiary` (`:29`) →
  `context.jeebRoles.accent`. Nothing else.

**Task 10 — Tests (§4), then gates.**
`flutter analyze` (bar: the 5 baseline infos, 0 errors, nothing new) ·
`flutter test test/features/chat/ test/chat_screen_test.dart test/chat_dm_header_parity_test.dart
test/chat_message_bubble_rtl_test.dart test/semantics_identifier_surfacing_test.dart
test/decision_violations_test.dart` — run `chat_header_overflow_test` LAST ·
`bash tool/check_design_tokens.sh` · `bash qa/t-mob-fix-002/l10n_parity_check.sh` ·
`grep -rn "identifier: '" lib/features/chat/presentation/` diffed against §1 (the composer's
param-driven ids checked at the call sites). Report which steps were blocked on the l10n batch.

---

## 4. Test impact

### Will break — legitimately (the design changed); rewrite, keep each test's shape

| Test | Break | Fix |
|---|---|---|
| `chat_header_contrast_test.dart:63-153` binding block | shell `surfaceContainerHigh`+`outline` border → `JeebNavySurfaceCard` navy, no border; status capsule gone; heading/price `onSurface` → `onPrimary`; link `primary` → `onPrimary`; expand icon → `onSecondaryContainer`; neutral chip → `tone.chipFill`, borderless | rewrite against the navy roles |
| `chat_header_contrast_test.dart:235+` measured rows | header background row changes | add rows: `onPrimary` on `primary` 15.6:1, `onSecondaryContainer` on `primary` 4.59:1. Both pass — never lower a threshold |
| `chat_header_contrast_test.dart:155-184` alpha guard | must **still pass** | it is why every strip Text/Icon ink is a solid role; if it reds, the implementation is wrong, not the test |
| `chat_dm_header_parity_test.dart:133-154` D2 | `arrow_back_ios` → `DirectionalIcons.back` glyphs | expected pair → `arrow_back`/`arrow_forward`; directional intent still asserted |
| `chat_dm_header_parity_test.dart:156-173` D3 | incoming bubble now shows its time (board html:35) | `find.text('09:41')` → `findsNWidgets(2)`; add: only the sender's bubble has a status node. **This reverses documented D3 on the design's authority — call it out in the PR** |
| `chat_dm_header_parity_test.dart:99-131` D1 | avatar tree changes | must still find exactly one ClipOval + one Image for the provided-image case (task 3 preserves it); if `JeebAvatar` adds an inner Image on the url path, scope the finder to descendants of `chat_detail_avatar` — never relax the count |
| `test/chat_screen_test.dart:119-126` | `tester.widget<ChatComposerIconButton>` — type deleted | assert enabled/disabled via semantics on `find.byKey(ChatComposer.sendButtonKey)` (kit reports `Semantics(enabled:)`); drop the import |
| `chat_composer.dart` hairline/glyph assertions if any surface in `chat_screen_m1plus_widget_test` | attach glyph `Icons.add` → `Icons.image_outlined` (kit default; the board draws the photo glyph, html:60) | update any `find.byIcon(Icons.add)` to the key-based finders |

### Must stay green — if one reds, the change is wrong

- `chat_composer_no_mic_b04_test.dart` — the whole B-04 refusal (kit composer keeps it).
- `order_chat_pinned_summary_labels_test.dart` — all four pinned strings, `friendlyReference`,
  role-aware party naming, 2-line clamp, and the `lessThan(260)` expanded-height bound
  (`:364-367`; the navy restyle removes capsule padding and adds only shadow — verify).
- `chat_header_a11y_test.dart` — collapsed shows ONLY reference/status/price (`:75-91` asserts
  `findsNothing` for eta/tier/cash/jeeber_name/view_link/description only, so adding
  `order_chat_track_cta` to the collapsed row is safe); 48dp targets; `"<field>: <value>"`.
- `chat_header_overflow_test.dart` — the bounded-slot architecture is untouched; the quick-reply
  row rides the raised reserve (task 4).
- `chat_header_status_chip_stale_test.dart` — reads Texts under `order_summary_status` (`:114`).
- `test/semantics_identifier_surfacing_test.dart` — `chat_detail_message_<id>`/`_read` (`:173-179`)
  and the `order_summary_pinned` leaf ids (`:578-629`) stay first-class nodes.
- `test/chat_message_bubble_rtl_test.dart` — directional bubble alignment (kit uses
  `AlignmentDirectional`).
- `chat_screen_m1plus_widget_test.dart`, `chat_picker_binding_test.dart` (taps
  `ChatComposer.attachButtonKey` — pass-through key), `voice_note_bubble_widget_test.dart`
  (`:110` pins `Icons.play_arrow_rounded` — kit default), `chat_image_bubble_source_test.dart`
  (precedence verbatim), `chat_undated_band_contract_test.dart`, `order_chat_jm025_test.dart`,
  `chat_history_load_error_test.dart`, `chat_empty_state_overflow_test.dart`,
  `new_bug_01_phase_gate_test.dart`, the six ordering/regression suites in `test/features/chat/`.
- `test/core/theme/*`, `test/core/widgets/jeeb/*` — frozen; not yours.

### New tests

- `test/features/chat/chat_quick_reply_bar_test.dart`: row present on the accepted client thread;
  **absent** when (a) compose hook wired, (b) phase broadcasting, (c) `viewerIsJeeber`; tapping
  a pill appends exactly one outgoing message and the composer field stays empty; AR pill renders
  un-mirrored in an EN thread (kit covers the widget-level RTL — this is the screen-level smoke).
- Track pill: `order_chat_track_cta` absent when `onTrack` null or `deliveryId` empty; tap fires
  with `summary.deliveryId`.
- System chip: label carries ` · HH:mm` only when `hasServerTimestamp`.
- Cubit: `sendQuickReply` (task 2).

### Goldens

None committed for this feature (the 6 PNGs belong to 18 and the 24-sheet). No regeneration.

---

## 5. RTL checklist (board is LTR; all of this must survive mirroring)

1. Bubble tails/alignment/max-width — kit-owned (`BorderRadiusDirectional` 18/18/18/6,
   `AlignmentDirectional`); `time` sits in the kit's LTR isolate.
2. Text inside bubbles keeps `AutoDirectionText` (UAX#9 first-strong) — pass it as `child:`.
3. Quick replies — kit-owned: leading-edge start under RTL, no `reverse:`, no forced LTR on the
   Arabic pill.
4. Top bar — kit-owned mirroring; the rating NUMBER is wrapped in `Directionality(ltr)` (task 3)
   so `4.9` never renders `9.4`.
5. Strip — outer `Padding` and pill paddings are `EdgeInsetsDirectional`; the `Wrap` mirrors free;
   the price keeps whatever isolation it has today (do not add).
6. Composer — kit-owned (attach/send land on the leading edge in Arabic — correct).
7. Existing coverage that must stay green: `order_chat_pinned_summary_labels_test` M10/M11,
   `chat_dm_header_parity_test` D2, `chat_message_bubble_rtl_test`.

---

## 6. Stop conditions

**Done means:** tasks 1-10 landed; every §1 identifier and Key greps identically (composer ids
verified at the call sites); the §4 will-break tests are rewritten and everything else in §4 is
green; the four `_BASELINE.md` failures are the only other reds; `flutter analyze` = 5 baseline
infos, 0 errors, nothing new; both scripts clean; the PR notes the D3 reversal, the B-04/mic and
presence-dot/call-button refusals, the unconditional `chat_detail_back_button`, and the stale
Maestro flows advisory.

**Do NOT touch:** `lib/core/router/app_router.dart` · `lib/core/di/injection_container.dart` ·
`lib/core/theme/*` · `lib/core/widgets/jeeb/*` (frozen kit) · `lib/l10n/*` · `pubspec.yaml` ·
`lib/features/deep_link_targets/chat_detail_screen.dart` · `chat_bubble_timestamp.dart` ·
`offer_card_bubble.dart` · `offer_accepted_banner.dart` · `chat_fee_banner.dart` ·
`jeeber_removed_banner.dart` · `confirm_delivery_action_sheet.dart` ·
`lib/features/live_tracking/presentation/widgets/order_summary_pinned_header.dart` (screen 12's
rendering of the shared ids — never merge the two) · `.maestro/**` · `test/support/*` ·
`lib/devtool/*` · the `_ChatHeaderSlot`/`kChatHeaderMaxViewportFraction`/`kChatPinnedCtaReserve`
architecture (restyle inside it) · the other three `_BASELINE.md` failures. Do not add a mic, a
presence dot, a call button, a reply-latency line, a playable voice note, an audio player, or any
endpoint/field the wire does not carry. Do not consume `JeebSemanticColors.readTick` or
`starRatingColor` here.

---

## 7. Explicitly out of scope (cut from the original proposal)

- Hand-rolled composer pill / `OmdsTextField` `suffixIcon` fallback engineering — kit consumed.
- Screen-local TTL outline pill — `JeebSystemChip.accent` consumed.
- `chat_bubble_timestamp.dart` restyle — file untouched; the bubble path stops importing it.
- Any restyle of the offer-card bubble, accepted banner, fee banner, removed banner, or the
  confirm-delivery sheet — no counterpart on the board / other phase.
- `_ChatHistoryShimmer` gutter alignment — transient surface, not evidenced by the render.
- Editing the four stale Maestro flows — flagged to the E2E owner, not this lane.
