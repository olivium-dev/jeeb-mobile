# 21 · Order chat — implementation proposal

Design source: `screens/21-order-chat.png` · `screens/21-order-chat.html` · `screens/21-order-chat.note.md`
Spine: `00-MIGRATION-PLAN.md` (§4 token bridge, §5 kit, §6 Wave 4, §7.2 locked decisions) + `02-PLAN-ENHANCED.md` (R1–R14, C1/C2).

**Verdict: rebuild.** The chrome (top bar, pinned strip, composer) is rebuilt; the thread is
restyled; the quick-reply row is net new. Nothing about the cubit's data flow changes except one
new `sendQuickReply` method.

Files this lane owns:

| File | LOC | Role |
|---|---|---|
| `lib/features/chat/presentation/chat_screen.dart` | 1105 | body column, header slot, message list, composer mount |
| `lib/features/chat/presentation/widgets/chat_app_bar.dart` | 228 | the header |
| `lib/features/chat/presentation/widgets/chat_message_bubble.dart` | 649 | 6 bubble kinds + status ticks |
| `lib/features/chat/presentation/widgets/chat_composer.dart` | 314 | field + attach + send |
| `lib/features/chat/presentation/widgets/chat_composer_icon_button.dart` | 69 | circle/borderless icon button |
| `lib/features/chat/presentation/widgets/order_chat_pinned_summary.dart` | 811 | the pinned strip |
| `lib/features/chat/presentation/widgets/system_message_bubble.dart` | 64 | centred system chip |
| `lib/features/chat/presentation/widgets/chat_date_separator.dart` | 48 | date chip |
| `lib/features/chat/presentation/widgets/chat_bubble_timestamp.dart` | 55 | bubble meta clock |
| `lib/features/chat/presentation/widgets/chat_offer_only_one_footer.dart` | 36 | orange note |
| `lib/features/chat/presentation/widgets/broadcast_ttl_indicator.dart` | 100 | offer-window countdown |
| `lib/features/chat/application/chat_cubit.dart` | — | +1 method (`sendQuickReply`) |
| NEW `lib/features/chat/presentation/widgets/chat_quick_reply_bar.dart` | — | screen-local consumer of `JeebQuickReplyRow` |

**Not touched by this lane:** `lib/features/deep_link_targets/chat_detail_screen.dart` (the `/chat/:id`
container) except for **one** change — passing `onTrackOrder` through to the strip already works via
the existing prop, so the container needs **no edit at all**. `offer_accepted_banner.dart`,
`chat_fee_banner.dart`, `confirm_delivery_action_sheet.dart`, `offer_card_bubble.dart` and
`jeeber_removed_banner.dart` are deliberately left alone (see §12).

---

## 1. Layout & structure

### 1.1 What the design is, measured from the HTML

```
column
├─ 14/24/0   identity top bar        Ø40 back circle · Ø42 avatar+presence dot · name/sub · Ø40 trailing circle
├─ 14/24/0   navy pinned strip r14   Ø8 orange dot · "Medicine · In transit · $8 cash" · white "Track" pill
├─ flex:1    thread, 16/24/0, gap 10 centred system chips + incoming/outgoing bubbles
├─ 10/24/0   quick-reply row         3 outline pills, nowrap, horizontally scrollable
└─ 10/24/30  composer                h52 pill: placeholder · 19px attach glyph · Ø38 circle
```

The bottom ~45% of the render is empty white. On this screen that is **data-driven, not a layout
rule** (R1): a short thread simply does not fill the viewport. Do **not** add filler, and do not
vertically centre the list — the existing `Expanded(child: body)` at `chat_screen.dart:810` already
produces exactly this.

### 1.2 Structural moves

**A. The app bar leaves `Scaffold.appBar` in spirit but not in mechanism.**
The design's header is an in-body row at padding `14/24/0` with no divider and no elevation, 40+42+40
tall (~70dp), not a 56dp `kToolbarHeight` `OMDSAppBar`.

Do **not** restructure `Scaffold` (`chat_screen.dart:462`). `ChatAppBar` is also mounted by
`chat_detail_screen.dart:1676` inside `OmdsErrorStatePage(appBar:)`, which requires a
`PreferredSizeWidget`. Instead: keep the class and its whole public API
(`title/avatarUrl/avatarImage/showAvatar/onAvatarTap/actions`) and change only its body —

```
ChatAppBar (PreferredSizeWidget, preferredSize = Size.fromHeight(Sizes.sevenXLarge /*72*/))
  └ Material(color: colorScheme.surface, elevation: 0)
      └ SafeArea(bottom: false)
          └ JeebTopBar.identity(...)                      // kit §5 #1
```

Drop `OMDSAppBar` from this file. That removes the `showBackButton: !showAvatar` branch
(`chat_app_bar.dart:69`) whose OMDS-drawn back button carried **no** identifier — after the change
`chat_detail_back_button` is emitted unconditionally, which is strictly better for Maestro.

**B. The pinned strip becomes a navy card, and keeps the disclosure model.**
`OrderChatPinnedSummary` stays a `StatefulWidget` with `ChatHeaderExpansionStore`; its
`DecoratedBox` shell (`order_chat_pinned_summary.dart:266-279`) is replaced by
`JeebNavySurfaceCard` (kit §5 #4). Collapsed = the design's one line; expanded = today's disclosed
block, re-toned for navy. **The collapsed/expanded split is pinned by `chat_header_a11y_test` and
must not change** — the design's one-line strip *is* today's collapsed row.

**C. `Track` moves into the strip.** The design puts a white `Track` pill at the end of the strip.
Today the only Track affordance is `offer_accepted_track_cta` inside the dismissible
`OfferAcceptedBanner`, which disappears once dismissed. Add a white pill to the strip's collapsed
row, gated so it is never a dead end (see §4.2).

**D. The quick-reply row is inserted** between `Expanded(child: body)` and `ChatComposer` in
`_ChatBody`'s `Column` (`chat_screen.dart:810-829`).

**E. Deleted:**
- the composer's top hairline border (`chat_composer.dart:176-184`) — the design has none;
- `_ImagePlaceholder`'s 168×112 slab (`chat_message_bubble.dart:357-376`) → the design's 120×74 tile;
- the flat progress bar in `_VoicePlayerRow` (`chat_message_bubble.dart:443-450`) → `JeebWaveform.inBubble`;
- the `primaryContainer` capsule around the status chip in the collapsed strip row (R8: on a navy
  fill every internal chip re-tones — here it re-tones to plain white w700 text with a `·`
  separator, which is also what the design draws and what keeps the row from wrapping).

**F. Added:** `_ChatHeaderSlot`'s inner `Column` gets `EdgeInsetsDirectional.only(bottom: Spacing.small)`.
`SingleChildScrollView` clips (`clipBehavior: Clip.hardEdge`), and the navy strip's new drop shadow
would be sheared off at the slot's bottom edge without that gap.

---

## 2. Tokens — every hardcoded value that must become a token

`lib/features/chat/**` is **not** in `no_raw_semantic_colors_test.dart`'s 18-file list, but
`tool/check_design_tokens.sh` still bans hex, `Colors.*`, `fontSize:`, `BorderRadius.circular(N)`,
`EdgeInsets.x(N)` and `SizedBox(width|height: N)` here. Design-exact px (14, 18/6 radii, 120×74,
Ø38, Ø42) live **inside `lib/core/widgets/jeeb/`**, never in these files (§4.4).

| Where (file:line) | Today | Becomes |
|---|---|---|
| `chat_app_bar.dart:129` | `Icons.arrow_back_ios` via a local `isRtl` check | `DirectionalIcons.back(context)` (design draws the filled arrow, not the chevron) — §11 |
| `chat_app_bar.dart:130` | `iconSize: Sizes.large` (20) | 20px navy glyph in a Ø40 `surfaceContainerHigh` circle (kit) |
| `chat_app_bar.dart:158` | `_size = Sizes.fourXLarge` (48) | Ø42 via `JeebAvatar.thread` (kit §5 #9) |
| `chat_app_bar.dart:223-224` | `primaryContainer` / `onPrimaryContainer` avatar fill | `colorScheme.primary` + `onPrimary`, initial `15/w800` (kit) |
| name line (new) | — | `context.jeebText` — 16/w700 navy: use `titleProminent` scaled by the kit, ink `colorScheme.onSurface` |
| sub line (new) | — | `jeebText.caption` (11.5/w600), ink `colorScheme.onSecondaryContainer` (periwinkle) |
| `order_chat_pinned_summary.dart:272` | `color: colors.surfaceContainerHigh` | `colorScheme.primary` |
| `order_chat_pinned_summary.dart:273-278` | `Border(bottom: outline, 1dp)` | **no border**; `JeebShadows.ctaNavy` (R7: shadows only under navy) |
| `order_chat_pinned_summary.dart:414-417` `_CollapsedRow` reference | `titleSmall.copyWith(bold, onSurface)` | `jeebText.caption` + `FontWeight.w700`, ink `colorScheme.onPrimary` |
| `order_chat_pinned_summary.dart:447-450` price | `titleSmall.copyWith(bold, onSurface)` | same treatment, ink `colorScheme.onPrimary` |
| `order_chat_pinned_summary.dart:707-718` `_SummaryChip` | `primaryContainer` / `surfaceContainerLowest` fill + `outline` border | on-navy: **no capsule** in the collapsed row; in the expanded block the chip becomes fill `Colors.white.withValues(alpha:.14)`-equivalent → use `colorScheme.onPrimary` at 14% **only as a fill** (decorative), ink `colorScheme.onPrimary`, empty-state ink `colorScheme.onSecondaryContainer` |
| `order_chat_pinned_summary.dart:493` expand icon | `colors.onSurfaceVariant` | `colorScheme.onSecondaryContainer` (solid — see §2.1) |
| `order_chat_pinned_summary.dart:527-529` party name | `bodyMedium` + `onSurfaceVariant` | `jeebText.bodySmall`, ink `colorScheme.onSecondaryContainer` |
| `order_chat_pinned_summary.dart:563-569` view-summary link | `labelLarge` + `primary` + underline | `jeebText.bodySmall` w700, ink `colorScheme.onPrimary`, underline kept |
| `order_chat_pinned_summary.dart:615-630` cash row | `labelMedium` + `onSurfaceVariant` | `jeebText.caption`, ink `colorScheme.onSecondaryContainer` |
| live dot (new) | — | Ø8 `context.jeebRoles.accent` (R5: the live-state dot is orange) |
| `chat_message_bubble.dart:149-150` | `Radius.circular(Spacing.small)` (12) / `Spacing.twoXSmall` (4) | 18 / 6, built once inside `JeebChatBubble` with `BorderRadiusDirectional` (§4.4) |
| `chat_message_bubble.dart:119` | `_bubbleMaxWidthFraction = 0.7` | `0.78` (HTML `max-width: 78%`) — kit constant |
| `chat_message_bubble.dart:182-187` | padding `16/16/16/4` | `11/14` (kit) |
| `chat_message_bubble.dart:194` | `textTheme.bodyLarge` | `context.jeebText.body` (13.5 / w500 / lh 19) |
| outgoing bubble (new) | flat | `JeebShadows.bubbleOut` |
| `chat_bubble_timestamp.dart:47-51` | `labelSmall` + `onSurfaceVariant.withValues(alpha: opacityHigh)` | 10/w600 **solid**; incoming ink `colorScheme.onSurfaceVariant`, outgoing ink `colorScheme.onSecondaryContainer` (§2.1) |
| `chat_message_bubble.dart:365-374` `_ImagePlaceholder` | `Sizes.fiveXLarge*3 × *2`, `Icons.image_outlined` @40, faded | 120×74 r10 `surfaceContainerHighest`, 20px `onSecondaryContainer` glyph (kit media slot) |
| `chat_message_bubble.dart:440` play glyph | bare `Icon(Icons.play_arrow_rounded)` | same `IconData` at 14px white inside a Ø32 `colorScheme.primary` disc |
| `chat_message_bubble.dart:443-450` | flat `Container` bar | `JeebWaveform.inBubble` (5 bars w2.5 gap 2, h 8/14/10/15/9) |
| `chat_message_bubble.dart:453-455` duration | `labelMedium` | `jeebText.caption` w700, muted ink |
| `system_message_bubble.dart:33-41` | `surfaceContainer` pill + `labelMedium` + `onSurfaceVariant` | `JeebSystemChip` — `filled` (`surfaceContainerHigh`, pad `4/12`, `jeebText.label`, `onSecondaryContainer`) or `outlined` (1.5px `colorScheme.outline`, pad `5/13`, `onSurfaceVariant`) |
| `chat_offer_only_one_footer.dart:29` | `colorScheme.tertiary` | `context.jeebRoles.accent` — **the only sanctioned orange** (§4.6) |
| `broadcast_ttl_indicator.dart:78,84,91` | `tertiaryContainer` / `onTertiaryContainer` full-bleed slab | centred outline pill: 1.5px `jeebRoles.accent`, text `jeebText.label` in `jeebRoles.accent` (R5 — a countdown is exactly "what is expiring right now") |
| `chat_composer.dart:176-184` | `surface` + top `outlineVariant` border | no border; container padding `Spacing.small / Spacing.xLarge / Spacing.small` + `SafeArea(top:false)` |
| `chat_composer.dart:282` | `borderRadius: UIConstants.borderRadiusXLarge` | pill (999) |
| `chat_composer_icon_button.dart:44-49` | `primary.withValues(alpha: opacityDisabled)` when disabled | keep the disabled fade (functional), but the enabled send circle is Ø38 solid `colorScheme.primary` with an `onPrimary` 18px glyph |
| `chat_composer.dart:244` attach glyph | `Icons.add` | `Icons.image_outlined` at 19px, ink `colorScheme.onSecondaryContainer` (HTML line 60 draws the photo glyph) |
| `chat_screen.dart:991` list padding | `EdgeInsets.symmetric(vertical: Spacing.small)` | `EdgeInsets.symmetric(vertical: Spacing.medium)` (HTML `padding: 16px 24px 0`) |
| `chat_message_bubble.dart:53-56` row padding | `horizontal: Spacing.medium` (16) | `horizontal: Spacing.xLarge` (24) — the universal gutter (§4.3) |

### 2.1 The on-navy ink rule, and why no alpha

`chat_header_contrast_test.dart:155-184` asserts that **no** `Text` or `Icon` colour inside
`OrderChatPinnedSummary` has `alpha < 1.0`. R8's "re-tone internals to `rgba(255,255,255,.7)`" would
violate that guard directly. Use two **solid** roles instead, which is what the board actually
renders and which measures clean:

| Ink | Role | On `#0B1351` |
|---|---|---|
| the fact | `colorScheme.onPrimary` `#FFFFFF` | **15.6 : 1** |
| its qualifier | `colorScheme.onSecondaryContainer` `#777FC0` | **4.59 : 1** — AA for body text |

`colorScheme.onSecondaryContainer` **is** the periwinkle (§4.1 maps `--jeeb-periwinkle` to it), so
this needs no new token and dodges `JeebSemanticColors.mutedText`'s "decorative only, never
body-text ink" rule. `JeebSemanticColors` is not read by this screen at all.

**Refused: `JeebSemanticColors.readTick` (`#20F0FF`).** Zero occurrences board-wide (§4.1). The
current read state uses `context.omdsColorTokens.infoColor`
(`chat_message_bubble.dart:633`) — that is not the cyan token either, and it is replaced by the word
`Read`, not re-tinted.

**Flagged, not silently shipped: the incoming timestamp's contrast.** The HTML sets the incoming
`9:24` to periwinkle on `--jeeb-surface-high` `#EAE7EB` = **3.07 : 1**, below AA for a 10px label.
Use `colorScheme.onSurfaceVariant` `#5C4038` there instead (the board's own "brown subtitle" ink,
comfortably AA) and keep periwinkle only on the navy outgoing bubble where it measures 4.59:1. This
is a deliberate one-token divergence from the HTML; state it in the PR.

---

## 3. Shared components consumed

Build order §5.1 puts this screen's kit at **step 10**, after steps 1, 3, 5, 6, 8. All of these must
exist before this lane starts:

| Kit widget | Where it lands here | Notes |
|---|---|---|
| `JeebTopBar.identity` (#1) | `chat_app_bar.dart` body | back circle + Ø42 avatar + name/sub + **real trailing slot** |
| `JeebAvatar` Ø42 (#9) | inside the top bar | `presence` dot = **refused** (§7); keep the initial/URL/image precedence from `_UrlOrInitialAvatar` |
| `JeebNavySurfaceCard` (#4) | `order_chat_pinned_summary.dart` shell | r14, `shadow: ctaNavy`, no decorative ring |
| `JeebChatBubble` (#16) | `chat_message_bubble.dart` `_DirectionalBubble` replacement | owns 18/6 `BorderRadiusDirectional`, 78% max width, `11/14` padding, the meta line, and the media slot |
| `JeebWaveform.inBubble` (#14) | `_VoicePlayerRow` | 5 bars, navy at .4–.7 (white .4–.7 when outgoing) |
| `JeebSystemChip` (#17) | `system_message_bubble.dart`, `chat_date_separator.dart`, `broadcast_ttl_indicator.dart` | `filled` + `outlined` |
| `JeebChatComposer` (#18) | `chat_composer.dart` `_ComposerBar` | **send, never mic** (§9-C2) |
| `JeebQuickReplyRow` (#26) | NEW `chat_quick_reply_bar.dart` | net new surface |
| `JeebSelectChip.quickReply` (#6) | inside #26 | pad `8/13`, 12/w600, ink **navy** (R2 — quick replies do *not* use the brown unselected ink) |
| `JeebCtaButton` — *not used* | — | this screen has no docked CTA |

**Kit contract this screen needs and the plan does not yet spell out:** `JeebChatBubble`'s media slot
must accept the play-disc + waveform + label group **or** the 120×74 photo tile, **never both at
once** — see §5.3.

---

## 4. New functionality and what it needs from the cubit/state

### 4.1 Quick replies (net new)

`JeebQuickReplyRow` with three pills. Behaviour = one-tap send.

**Cubit change — one method** on `ChatCubit`:

```dart
/// One-tap quick reply. Sets the composer to [text] and sends it in one step so
/// the field never visibly flickers through the canned string.
Future<void> sendQuickReply(String text) async { … }   // composerChanged + sendText
```

Doing this from the widget as `composerChanged(text); sendText();` also works (both are synchronous
into the emit) but makes `ChatComposer`'s `BlocListener` (`chat_composer.dart:121-125`) sync the
controller to the canned text and back to `''` — a visible one-frame flash. Put it in the cubit.

**Visibility gate — load-bearing, not cosmetic.** In the compose phase the FIRST outgoing message
*broadcasts the request and becomes its description*
(`chat_screen.dart:585-607` → `onFirstMessageBroadcast`). A quick-tapped `I'm home` would create a
request described "I'm home". Render the row **only** when

```
state.isComposerVisible && state.phase != ConversationPhase.broadcasting && onFirstMessageBroadcast == null
```

which is also where the design puts it (an accepted, in-transit thread).

### 4.2 `Track` in the pinned strip

The strip already holds `summary.deliveryId`, which is the same id `order_chat_view_summary_link`
routes on. Add to `OrderChatPinnedSummary`:

```dart
/// Routes to live tracking. Null hides the pill (never a dead end — the G5 rule
/// the accepted banner's Track CTA already follows).
final VoidCallback? onTrack;
```

Wire it in `chat_screen.dart:703-710` from the props already in scope:

```dart
onTrack: (onTrackOrder != null && summary.deliveryId.isNotEmpty)
    ? () => /* host handler */ : null,
```

`ChatScreen.onTrackOrder` is `void Function(String deliveryId)?` and `chat_detail_screen.dart:1740`
already routes it to `/orders/$deliveryId/tracking`. **No container edit needed.** Note the
difference from `_trackOrderCallback` (`chat_screen.dart:544-549`), which additionally requires
`state.canTrackDelivery` (an accept-response id captured *in this session*); the strip's id comes
from the resolved summary and is available on a cold open of an already-accepted thread — which is
precisely the case the design draws.

Copy: reuse the existing key **`orderSummaryTrack`** ("Track order" / "تتبّع الطلب"). No new key.

### 4.3 Counterpart rating in the header — buildable, with a caveat

`OrderChatSummary.rating` exists (`order_chat_summary.dart:46`) and is really populated from
`delivery['jeeberRating'] ?? request['jeeberRating']`
(`dio_order_chat_summary_repository.dart:120-122`), defaulting to `0`.

So `★ 4.9` **is** renderable: pass `pinnedSummary?.rating` down to `ChatAppBar` and render the star
row only when `rating > 0`.

**This is a different DTO from screen 12's.** §7.2-C3 blocks the courier star because
`DeliveryTrackingInfo.fromTrackingJson` deliberately nulls `rating`. That parser is not on this path
and must not be read here. Do not "reuse" the tracking model to fill this header.

Star colour: **do not tint it yellow.** §4.1 lists 21's ★ among the screens where the glyph inherits
the surrounding periwinkle/navy ink. `context.omdsColorTokens.starRatingColor` is for 11/12/15 only.

### 4.4 Genuinely unavailable — omit with a TODO, never fake

| Design element | Why it cannot be built | Action |
|---|---|---|
| `usually replies in 1 min` | no field anywhere; named in §7.6's "still genuinely suspect" list | omit; `// TODO(redesign-24): needs gateway reply-latency — omitted, not faked.` |
| green **presence dot** on the avatar | there is no counterpart-presence signal. `ChatConnectionCubit` reports **my own** socket state and has zero consumers in `lib/` — using it would assert "Karim is online" from "my websocket is up" | omit the dot; `JeebAvatar` renders without it |
| the **call** button in the trailing slot | no phone number reaches this surface. `DeliveryStatusCubit.requestContactNumber()` (`delivery_status_cubit.dart:108`) is the one gated contact path and it lives on the delivery-status screen | trailing slot renders `order_chat_open_dispute` instead (§7) |
| a **playable** voice note | there is no audio player; `_VoicePlayerRow` has no `onTap` today | render the Ø32 disc **non-interactive and with no identifier**. Adding a button id for a permanent no-op is exactly the B-04 defect |
| one bubble carrying **voice + photo** | `MessageKind` is one-of (`delivery_chat_message.dart:34`); a voice row has `voiceUrl/voiceDurationMs/voiceTranscription`, an image row has `imageUrl/photoBytes`. The wire cannot express both | render as two consecutive same-author bubbles; tighten the gap so they read as a cluster (§5.3) |

---

## 5. Detail specs

### 5.1 Top bar (`chat_app_bar.dart`)

```
Row  padding 14/24/0, gap 12
 ├ Semantics(chat_detail_back_button) → Ø40 surfaceContainerHigh circle,
 │    DirectionalIcons.back(context) @20 navy, onTap Navigator.maybePop()
 ├ Semantics(chat_detail_avatar)      → Ø42 JeebAvatar (image ▸ url ▸ initial 15/w800 on primary)
 │    rendered only when showAvatar (unchanged gate)
 ├ Expanded column
 │    title 16/w700 onSurface, maxLines 1, ellipsis
 │    sub   11.5/w600 onSecondaryContainer  → [★ rating]  (omitted when rating == 0)
 └ actions.first, re-skinned to a Ø40 surfaceContainerHigh circle (18px navy glyph)
```

The `actions` list already carries exactly one item (`order_chat_open_dispute`,
`chat_screen.dart:471-484`); the top bar renders `actions.first` in the design's trailing circle and
ignores any extra, since no caller passes more than one.

### 5.2 Pinned strip (`order_chat_pinned_summary.dart`)

Collapsed row (the design's one line), left→right, all four pinned strings preserved:

```
Ø8 jeebRoles.accent dot
reference  (order_chat_summary_reference)   white w700
·  status  (order_summary_status)           white w700, NO capsule
·  price   (order_summary_price)            white w700
Track pill (order_chat_track_cta)           white fill, navy label, pad 6/13, r999
expand     (order_chat_summary_expand)      48×48, onSecondaryContainer chevron
```

Keep `_CollapsedRow`'s `Wrap` (`order_chat_pinned_summary.dart:402-405`) — it is the text-scale
overflow fix. Dropping the two capsules buys back roughly 90dp of row width, which is what makes
`Track` fit; without that the strip wraps to two lines at scale 1.0. **If it still reads as too dense
in review, the copy question goes to the owner (plan risk #11) — do not solve it by deleting a
pinned string.**

Expanded block: unchanged structure (`_PartyRow`, `_RequestDescription`, ETA/tier chips,
`_CashOnDeliveryRow`), re-toned per §2.1.

### 5.3 Thread rows

| Row kind | Today | Becomes |
|---|---|---|
| date separator | `OmdsDateChip` | `JeebSystemChip.filled` — keep `chat_detail_date_separator` and `Key('chat-date-separator')` |
| `system` | `SystemMessageBubble` filled chip | `JeebSystemChip.outlined` (a live/progress event: "Karim is on the way · ETA 20 min") |
| `offerAccepted` / `offerRejected` | same filled chip | `JeebSystemChip.filled` (a settled fact: "Offer accepted · 9:12") |
| text | `_TextBubble` | `JeebChatBubble` + `jeebText.body` |
| voice | `_VoiceBubble` | disc + `JeebWaveform.inBubble` + `0:06` + transcription line unchanged |
| photo / image | `_PhotoBubble` / `_ImageBubble` | media slot; **keep `_imageContent`'s source precedence verbatim** (`chat_message_bubble.dart:335-354`) — bytes ▸ absolute http(s) ▸ placeholder |
| location | `_LocationBubble` | shell only |
| offer card | `OfferCardBubble` | untouched this wave |

**System chip time suffix.** The design writes `Offer accepted · 9:12`. Build it from
`message.sentAt` **only when `message.hasServerTimestamp`** — an undated row carries a 1970 ordering
anchor and `chat_undated_band_contract_test.dart` exists precisely to stop it being painted as a
clock. New key `chatSystemChipWithTime` = `"{event} · {time}"`.

**Consecutive-bubble clustering** (how the design's "one media bubble" is honestly rendered): when
`messages[i].author == messages[i-1].author` and both are non-system, drop the row's top padding to
`Spacing.threeXSmall`. Two stacked bubbles from Karim then read as the render's single grouped
media block without inventing a wire shape.

### 5.4 Bubble meta line

`_BubbleFooter` (`chat_message_bubble.dart:549-587`) becomes a single directional meta line:

```
[time]  [· Read]      // read only
[time]  [tick]        // sent / delivered — small glyph in the meta ink
[time]  [clock|error] // sending / failed
```

All five `Semantics(identifier: …)` nodes at lines 606/616/622/628/638 survive with their existing
labels; only the `read` case swaps its `Icon` child for a `Text(l10n.chatMessageReadLabel)`
(new key, "Read" / "تمت القراءة"). Keep `Key('chat-status-${message.id}')`.

**The footer must now render for the counterpart too** (time only, no status glyph) — see §11-D3.

### 5.5 Composer

```
padding Spacing.small / Spacing.xLarge / Spacing.small   (+ SafeArea(top:false))
OmdsTextField
  fillColor    : colorScheme.surfaceContainerHigh
  borderRadius : pill
  key          : ChatComposer.textFieldKey
  suffixIcon   : Row(mainAxisSize: min, [
                   attach 19px onSecondaryContainer  (ChatComposer.attachButtonKey,
                                                      chat_detail_attach_button),
                   Ø38 primary circle + onPrimary 18px Icons.send
                                                     (ChatComposer.sendButtonKey, sendIdentifier),
                 ])
```

`OmdsTextField` already exposes `fillColor`, `borderRadius` and `suffixIcon`
(`omds_text_field.dart:35-40`), so the single-pill composer needs no OMDS change and no fork.

**Verify before committing to `suffixIcon`:** `chat_picker_binding_test.dart:104` taps
`ChatComposer.attachButtonKey`. If OMDS constrains `suffixIcon` such that the two targets are not
hit-testable at ≥48dp, fall back to keeping attach/send as siblings of the field inside one
`surfaceContainerHigh` pill container with the field made transparent. Do **not** shrink the tap
targets below 48dp to fit the design's 19px glyph — pad it.

The `isAttaching` spinner branch (`chat_composer.dart:232-239`) stays.

---

## 6. New routes

**None.** Every destination the design implies already has a route:

| Affordance | Route | Wired at |
|---|---|---|
| `Track` | `/orders/:id/tracking` (`live-tracking`) | `chat_detail_screen.dart:1742` |
| view summary | `order-summary` | `chat_detail_screen.dart:1778` |
| dispute (trailing circle) | `escalate` | `chat_detail_screen.dart:1788` |
| back | `Navigator.maybePop()` | `chat_app_bar.dart:131` |

No `app_router.dart` edit, no `backFallbacks` edit, no DI edit.

---

## 7. Semantics identifiers

### 7.1 Frozen — every one of these must still be emitted

From `lib/features/chat/**` plus the `/chat/:id` container:

```
chat_screen.dart               order_chat_open_dispute · chat_history_error · chat_detail_message_list
chat_app_bar.dart              chat_detail_back_button · chat_detail_avatar
chat_composer.dart             chat_detail_message_input | order_chat_composer_input
                               chat_detail_send_button   | order_chat_composer_send
                               chat_detail_attach_button
chat_message_bubble.dart       chat_detail_message_<id>
                               chat_detail_message_sending / _sent / _delivered / _read / _failed
offer_card_bubble.dart         chat_detail_message_<id> · chat_detail_accept_<offerId>
                               chat_detail_decline_<offerId>
chat_date_separator.dart       chat_detail_date_separator
chat_offer_only_one_footer     chat_detail_offer_only_one_note
order_chat_pinned_summary      order_chat_pinned_summary · order_summary_pinned
                               order_chat_summary_reference · order_summary_status · order_summary_price
                               order_chat_summary_expand · order_summary_jeeber_name
                               order_chat_view_summary_link · order_chat_request_description
                               order_summary_item · order_summary_eta · order_summary_tier
                               order_chat_cash_label · order_summary_cash_label
offer_accepted_banner.dart     offer_accepted_banner · offer_accepted_banner_text
                               chat_start_active_delivery_cta · offer_accepted_track_cta
                               offer_accepted_dismiss_cta
chat_fee_banner.dart           chat_dm_fee_banner · chat_dm_fee_banner_dismiss · chat_dm_order_picked_button
confirm_delivery_*             confirm_delivery_illustration · confirm_delivery_action_sheet
                               confirm_delivery_drag_handle · confirm_delivery_title
                               confirm_delivery_subtitle · confirm_delivery_confirm_button
chat_detail_screen.dart        chat_resolution_error
```

Nesting rule that must survive the rebuild: `chat_message_bubble.dart:48` and
`order_chat_pinned_summary.dart:249/257/600/609` all use `container: true` +
`explicitChildNodes: true` so the inner ids are not merged away. `JeebChatBubble` and
`JeebNavySurfaceCard` must not introduce a `MergeSemantics` or a bare `Semantics` between the
container node and its children.

`chat_detail_voice_button` **must stay absent** (B-04). Four Maestro flows still
`assertVisible` it (`02-chat-client.yaml:175`, `03-chat-after-aproval-client.yaml:179`,
`04-delivery-screen-chat-delivery-man.yaml:92`, `07-chat-dm-blank.yaml:128`). Those flows have been
stale since B-04 shipped and Maestro is not in CI. **Do not resurrect the mic to satisfy them** — the
Dart test wins. Flag the four flows to the E2E owner; do not edit them in this lane.

### 7.2 New

| Identifier | Element |
|---|---|
| `order_chat_track_cta` | white `Track` pill in the navy strip |
| `order_chat_quick_reply_row` | the row container (`container: true`, `explicitChildNodes: true`) |
| `order_chat_quick_reply_home` | "I'm home" pill |
| `order_chat_quick_reply_door` | "Call me at the door" pill |
| `order_chat_quick_reply_thanks` | "شكراً" pill |

Intent-keyed, not index-keyed, so the ids survive reordering and locale changes. No identifier for
the voice play disc — it is not interactive (§4.4).

---

## 8. RTL

The whole board is drawn LTR. Nothing in it breaks mirrored **if** these are respected:

1. **Bubble tails.** Already directional (`BorderRadiusDirectional`, `chat_message_bubble.dart:148-160`)
   and must stay so at 18/6. `topStart/topEnd/bottomEnd = 18`, `bottomStart = 6` for incoming and the
   mirror for outgoing.
2. **Bubble alignment.** `AlignmentDirectional.centerStart/centerEnd`
   (`chat_message_bubble.dart:124-126`) — unchanged.
3. **Text inside bubbles** keeps `AutoDirectionText` (UAX#9 first-strong). This is what makes the
   Arabic quick reply legible inside an English thread and vice-versa.
4. **The meta line is the one deliberate LTR island** (`chat_message_bubble.dart:565-566`) so the
   order is always `time → status`. Keep the `Directionality(ltr)` wrapper; the new `· Read` word is
   localized text, so put the *word* outside the isolate or the Arabic will render LTR. Concretely:
   `Row[ Directionality(ltr, child: time), Text('·'), Text(readLabel) ]`.
5. **Quick-reply row.** `SingleChildScrollView(scrollDirection: horizontal)` starts at the *leading*
   edge automatically under RTL — do **not** add `reverse: true`. Pills use
   `EdgeInsetsDirectional`. The Arabic pill in an English thread must **not** be force-LTR
   (plan §5 #26).
6. **Top bar.** `DirectionalIcons.back(context)`; avatar and trailing circle are laid out by a plain
   `Row`, which mirrors for free. The star + number: wrap the *number* in an LTR isolate so `4.9`
   never renders as `9.4`.
7. **Strip.** `JeebNavySurfaceCard` margins via `EdgeInsetsDirectional`; the `Wrap` mirrors for free;
   the price string keeps its LTR isolate.
8. **Composer.** `suffixIcon` is a *trailing* slot in Flutter's `InputDecoration` and mirrors
   automatically — the attach glyph and send circle land on the leading edge in Arabic, which is
   correct.

Existing RTL coverage that must stay green: `order_chat_pinned_summary_labels_test` M10/M11 and
`chat_dm_header_parity_test` D2.

---

## 9. Conflicts with locked decisions — refused, with reasons

**C2 — the mic in the composer. REFUSED.**
`test/features/chat/chat_composer_no_mic_b04_test.dart:102` asserts
`find.byIcon(Icons.mic_none)` finds nothing. The board's Ø38 navy circle *is the send slot* — there
is no send button anywhere on the board — so this is "replace send with a mic", not "add a mic".
Build the circle as **send** (`Icons.send`, `sendButtonKey`, `sendIdentifier`) and keep the attach
glyph the board also draws. Note in the PR.

**C1 — the pinned strip's vocabulary. PARTIALLY REFUSED.**
`order_chat_pinned_summary_labels_test.dart` pins four strings: heading = the human order reference
(`ORD-…` / `#XXXXXX`), link = `"View summary"`, cash = `"Pay cash on delivery"`, status = the
canonical `deliveryStage*` vocabulary, unresolved = `"Pending"`. The board's
`Medicine · In transit · $8 cash` uses the **item name** as the heading, **drops** the View-summary
link and **inlines** the cash reminder.
Resolution (per §7.2 and plan risk #11): take the board's **shape** — navy r14, shadow, live dot,
one line, white `Track` pill — and keep all four strings. The item name already has a home:
`order_chat_request_description` in the disclosed block. The cash reminder and the link stay in the
disclosed block, where `chat_header_a11y_test` already requires them to be.

**The counterpart's ★ is NOT the C3 conflict.** C3 blocks screen 12's courier star because
`DeliveryTrackingInfo.fromTrackingJson` nulls `rating` and
`test/delivery_tracking_jeeber_parse_test.dart:44-64` asserts it. Chat reads
`OrderChatSummary.rating`, a different DTO from a different repository, which really is populated.
Rendering it here is not a privacy-guard violation — **but do not import the tracking model to do it.**

**The call button. REFUSED on data, not on policy.** No phone number reaches the chat surface at all.
The trailing circle renders the existing dispute affordance.

**D41/D44, `kJeebCommissionRate`, D56, D52, D20, accept-sheet tense** — none of them appear on this
screen. No commission/fee copy is added here; the `chat_fee_banner` (Jeeber-only balance notice) is
untouched.

**Deleted features** — nothing here resurrects the in-app role switch, the email/password funnel or
client-side search. The quick-reply row is a new affordance, not a revival.

---

## 10. Density note (R1/R12)

Chat is the one screen on the board where the empty lower half is produced by the data, not by a
spacer. Concretely, what must land for the thread to *look* like the render:

* gutters **24** everywhere (they are 16 today),
* bubble gap **~8–10** (`Spacing.twoXSmall` top and bottom of each row),
* list top padding **16**,
* the strip and the top bar at **14** vertical margins,
* **no** full-bleed slabs above the thread except the (transient) accepted/removed banners.

Today's chrome is three stacked full-bleed strips; the design is one inset card. That single change
is most of the perceptual difference.

---

## 11. Test impact

### Will break — legitimately (the design genuinely changed)

| Test | What breaks | Correct fix |
|---|---|---|
| `chat_header_contrast_test.dart:63-153` "binding — pinned summary" | `decoration.color == surfaceContainerHigh` → `primary`; `border.bottom == outline` → no border; status-chip `Container` gone; heading/price ink `onSurface` → `onPrimary`; expand icon `onSurfaceVariant` → `onSecondaryContainer`; link ink `primary` → `onPrimary` | rewrite the binding block against the navy roles; **keep the shape of the test** |
| `chat_header_contrast_test.dart:235+` layer-2 measured rows | the header background row changes from `surfaceContainerHigh` to `primary` | add rows: white-on-navy 15.6:1, periwinkle-on-navy 4.59:1. Both pass — do not lower a threshold |
| `chat_header_contrast_test.dart:155-184` "no foreground is alpha-faded" | should **still pass** | it is the reason §2.1 forbids `rgba(255,255,255,.7)`. If it fails, the implementation is wrong, not the test |
| `chat_dm_header_parity_test.dart:133-154` D2 back chevron | `Icons.arrow_back_ios` → `Icons.arrow_back` (`DirectionalIcons.back`) | update the expected pair to `arrow_back` / `arrow_forward`. The directional *intent* is unchanged and still asserted |
| `chat_dm_header_parity_test.dart:156-173` D3 incoming timestamp | the board **shows** `9:24` on the incoming bubble (HTML line 35); the test asserts exactly one `09:41` | change to `findsNWidgets(2)` and add an assertion that only the sender's bubble carries a status node. **This reverses a documented decision (D3) on the design's authority — call it out explicitly in the PR** |
| `chat_dm_header_parity_test.dart:99-131` D1 avatar | `find.byType(ClipOval) findsOneWidget` / `find.byType(Image) findsOneWidget` | `JeebAvatar` must not add a second `ClipOval`/`Image`; if it does, tighten the finder to a descendant of `chat_detail_avatar` rather than relaxing the count |

### Must stay green — if one of these goes red, the proposal is wrong

* `chat_composer_no_mic_b04_test.dart` — the whole B-04 refusal.
* `order_chat_pinned_summary_labels_test.dart` (14 cases) — all four pinned strings, `friendlyReference`,
  role-aware party naming, the 2-line description clamp, and the **`lessThan(260)` height bound at
  line 364-367**. The navy restyle adds a shadow (no layout height) and removes two capsules; verify
  the expanded strip still measures < 260 at width 360.
* `chat_header_a11y_test.dart` — collapsed shows *only* reference/status/price; expand reveals the
  rest; 48dp targets; `"<field>: <value>"` announcements. **Adding `order_chat_track_cta` to the
  collapsed row is safe** — the test asserts `findsNothing` only for eta/tier/cash/jeeber_name/
  view_link/description.
* `chat_header_overflow_test.dart` (11 cases) — the bounded-slot architecture at
  `chat_screen.dart:770-809` is untouched. The quick-reply row is a **new non-flexible child of the
  same Column**, so re-run this suite: it may need `kChatComposerReserve` (currently 120) raised by
  the row's height when the row is visible. Prefer making the row's height part of the reserve over
  weakening the bound.
* `chat_screen_m1plus_widget_test.dart`, `chat_picker_binding_test.dart`, `voice_note_bubble_widget_test.dart`
  (keeps `Icons.play_arrow_rounded`), `chat_image_bubble_source_test.dart`, `chat_undated_band_contract_test.dart`,
  `order_chat_jm025_test.dart`, `chat_history_load_error_test.dart`, `chat_empty_state_overflow_test.dart`.
* `test/core/theme/*` — untouched; Wave 0 is frozen.

### New tests to add

* `JeebQuickReplyRow` widget + RTL smoke (kit lane).
* Screen-level: the quick-reply row is **absent** in the broadcasting/compose phase (the
  broadcast-hijack guard, §4.1) and present on accepted.
* `order_chat_track_cta` is absent when `summary.deliveryId` is empty or `onTrackOrder` is null.
* The system chip appends ` · HH:mm` only when `hasServerTimestamp`.

### Goldens

None committed for this feature (the 6 committed PNGs belong to 18 and the 24-sheet). No regeneration.

---

## 12. Deliberate non-changes

* `OfferAcceptedBanner` — pinned by `chat_header_contrast_test:186-229` to the success roles and has
  no counterpart on the board (it is transient and dismissible). Left alone.
* `ChatFeeBanner` — Jeeber-only balance notice, not on the board.
* `JeeberRemovedBanner` — improves for free: Wave 0 re-tinted `errorContainer` from the `#B00020`
  slab to `#FFDAD6`/`#410002`.
* `OfferCardBubble` / `ConfirmDeliveryActionSheet` — broadcasting-phase and delivery-confirm surfaces,
  outside this screen's frame.
* `_ChatHeaderSlot` / `kChatHeaderMaxViewportFraction` / `kChatPinnedCtaReserve` — the overflow
  architecture is load-bearing and test-pinned. Restyle inside it, never around it.
* `lib/features/live_tracking/presentation/widgets/order_summary_pinned_header.dart` — the
  **tracking-surface** rendering of the same pinned widget. It shares the `order_summary_*`
  identifiers but belongs to screen 12's lane; it must not be edited from here, and the two must not
  be merged in this wave.

---

## 13. l10n (integrator batch — EN key + `@key` + real AR + getter + call site)

| Key | EN | AR |
|---|---|---|
| `chatMessageReadLabel` | `Read` | `تمت القراءة` |
| `chatQuickReplyImHome` | `I'm home` | `أنا في المنزل` |
| `chatQuickReplyCallAtDoor` | `Call me at the door` | `اتصل بي عند الباب` |
| `chatQuickReplyThanks` | `شكراً` | `شكراً` |
| `chatQuickReplyRowA11y` | `Quick replies` | `ردود سريعة` |
| `chatSystemChipWithTime` | `{event} · {time}` | `{event} · {time}` |
| `chatCounterpartRatingA11y` | `Rating {value} out of 5` | `التقييم {value} من 5` |

`chatQuickReplyThanks` is intentionally Arabic in **both** locales — the note's "one-tap quick
replies incl. Arabic" and the DS's bilingual pairing. It satisfies the parity gate (AR value ≠ key)
but it is a visible product choice: **confirm with the owner**, and if refused, ship
`Thanks` / `شكراً`.

Reused, no new key: `orderSummaryTrack`, `orderChatPayCashOnDelivery`, `orderChatViewSummaryLink`,
`orderSummaryValuePending`, `deliveryStage*`, `chatOfferAcceptOnlyOne`, `chatBroadcastTtlLabel`,
`chatBackA11y`, `chatAvatarA11y`, `chatAttachA11y`, `chatSendA11y`, `orderChatFieldValueA11y`.

---

## 14. Build order inside this lane

1. Inventory identifiers (§7.1) into the PR description **before** the first edit.
2. `chat_app_bar.dart` → `JeebTopBar.identity` (+ rating pass-through from `ChatScreen`).
3. `order_chat_pinned_summary.dart` → navy shell, re-toned inks, `Track` pill. Re-run
   `order_chat_pinned_summary_labels_test`, `chat_header_a11y_test`, `chat_header_contrast_test`.
4. `chat_message_bubble.dart` + `chat_bubble_timestamp.dart` → `JeebChatBubble`, waveform, meta line.
5. `system_message_bubble.dart` + `chat_date_separator.dart` + `broadcast_ttl_indicator.dart` +
   `chat_offer_only_one_footer.dart` → `JeebSystemChip` / accent.
6. `chat_composer.dart` → the single pill.
7. `chat_cubit.sendQuickReply` + `chat_quick_reply_bar.dart` + the mount in `chat_screen.dart`.
   Re-run `chat_header_overflow_test` **last** — it is the suite the new row can break.
8. `dart analyze --fatal-infos .` vs baseline · full `flutter test` · `tool/check_design_tokens.sh` ·
   `l10n_parity_check.sh`.
