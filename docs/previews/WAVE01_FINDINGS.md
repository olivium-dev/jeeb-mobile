# Wave 01 (chat) — defects surfaced by the previews

Eight widgets previewed; these are problems in the WIDGETS, found because the
preview matrix renders every state in AR-RTL-dark and at 200% text, not just
EN light. None were caught by the existing test suite.

## F01

ChatConnectionBanner: Dark-mode contrast failure on the `connected` status: `_decoration` pairs bg `scheme.secondaryContainer` with fg `scheme.onPrimary` — the only branch that does not use its own `on*` partner. Measured on `AppTheme.dark()`: bg #444559 vs ink #252B61 = 1.40:1 (WCAG AA needs 4.5:1); the label and icon are effectively invisible. `onSecondaryContainer` (#E0E0F9) would give 7.23:1. Light theme is 17.13:1, which is why this has gone unnoticed — the AR-RTL-dark rendering of the preview matrix is what surfaces it. lib/features/chat/presentation/chat_connection_banner.dart:63-69

## F02

ChatConnectionBanner: At 200% text the 'slim indicator strip' becomes a wall. The pending badge `Text` is a bare Row child (not `Flexible`), so it keeps its full intrinsic width (~257px of the 358px content row) and starves the `Expanded` label into an ~85px column that wraps to a dozen lines. Measured at 390x logical width with the real bundled Inter: 'Offline + full outbox' grows 56px -> 496px tall in EN and 336px in AR; 'Offline + one pending' grows to 336px EN / 576px AR; 'Reconnecting + outbox' to 136px. With Flutter's default (square-glyph) test font the same states hard-throw `A RenderFlex overflowed by 132 pixels on the right`, so any golden or widget test that renders this banner at large text without loading Inter will fail on overflow rather than on height.

## F03

ChatConnectionBanner: The long-copy status is the trigger, and it is a copy/design mismatch: `chatStatusOffline` is a full sentence ("You're offline. Messages will send when you reconnect.") used in the same one-line slot as one-word labels ('Connected', 'Connecting…'). Combined with the unconstrained badge it is what produces the 496px strip; the label has no `maxLines`/`overflow` to cap it.

## F04

ChatConnectionBanner: The status icon is pinned to `Sizes.medium` (16px) and does not respond to `textScaler`, so at 200% text a 16px icon sits beside 28px type — the icon, which is the fastest-read part of a status strip, shrinks to a third of the glyph height.

## F05

ChatMessageBubble: FAILED-SEND GLYPH IS INVISIBLE IN DARK MODE. `_StatusIcon` draws the failed branch in `Theme.of(context).colorScheme.error`, but a failed message is by construction always a SENDER bubble, whose fill is `colorScheme.primary`. Measured contrast of error-on-primary: 1.01:1 in AppTheme.dark() (#FFB4AB on #BCC2FF) and 2.34:1 in AppTheme.light(). The one glyph that tells a user their message never left is effectively unreadable in dark and below the 3:1 non-text floor in light. Surfaced by the 'Status ladder' preview's AR RTL dark rendering. (lib/features/chat/presentation/widgets/chat_message_bubble.dart, _StatusIcon failed branch, ~line 636)

## F06

ChatMessageBubble: READ TICK FAILS CONTRAST IN DARK MODE. The read branch uses `context.omdsColorTokens.infoColor`, a fixed brand blue (#2196F3) that does NOT flip with brightness, while the bubble underneath it (`colorScheme.primary`) does. Measured 1.83:1 in dark vs 5.48:1 in light — the blue-on-blue double tick nearly vanishes exactly when the rest of the UI inverts. Same preview card. (chat_message_bubble.dart, _StatusIcon read branch, ~line 626)

## F07

ChatMessageBubble: HARDCODED ENGLISH IN THE ARABIC ACCESSIBILITY LABEL. `_PhotoBubble` (line 217), `_ImageBubble` (line 284) and `_VoiceBubble` (line 392) each build `final authorLabel = isSender ? 'You' : 'Jeeber';` from Dart literals and pass it into the localized template. Confirmed against the live semantics tree in the ar locale: the node label reads `صورة من You`. The visible bubble is fully localized; only the spoken label leaks English, so it is invisible to every screenshot-based review and only shows up in a screen reader. Surfaced by the 'Image with no local bytes' preview in AR.

## F08

ChatMessageBubble: THE 70% WIDTH CAP DOES NOT RELAX AT LARGE TEXT SCALES. `_DirectionalBubble` pins maxWidth to `MediaQuery.size.width * 0.7` irrespective of textScaler, so at 200% text the same ~230-char message is still squeezed into a ~273 px column. Measured natural height of the 'Longest plausible message' preview at 390 px wide: 456 px at 1.0x, 1744 px at 2.0x — roughly four and a half phone screens of scrolling for one message. Legible, and a thread is scrollable so nothing clips, but the cap is worth widening (or relaxing above some scale) for large-text users.

## F09

ChatDateSeparator: Duplicated screen-reader announcement: ChatDateSeparator wraps OmdsDateChip in Semantics(label: ...) but never excludes the child's semantics, so the inner Text contributes a second copy. The merged node for the 'Older date' state reads identifier: "chat_detail_date_separator", label: "March 8, 2026\nMarch 8, 2026" — TalkBack/VoiceOver says the date twice. Confirmed by dumping the semantics tree; the test matches the label with a RegExp so the defect is not baked in as the contract.

## F10

ChatDateSeparator: 200% text destroys the chip shape: measured at 390pt width with 'September 28, 2025', the chip is a centered 239x40 pill at 1x but becomes exactly 390x88 at x=0 at 2x — full-bleed, touching both screen edges, label wrapped to two lines. Cause: OmdsDateChip defaults margin to EdgeInsets.symmetric(vertical: 16) and ChatDateSeparator passes no horizontal margin; the chat ListView padding is also vertical-only, so nothing upstream restores a gutter. No RenderFlex overflow is thrown, which is why nothing currently catches it.

## F11

ChatOfferOnlyOneFooter: lib/features/chat/presentation/widgets/offer_card_bubble.dart:86 — the Decline+Accept Row inside _OfferActions overflows horizontally at EVERY phone width. Measured with the real theme + real ARB: 167 px overflow at 320 pt (EN), 127 px at 360, 97 px at 390, 57 px at 430; AR overflows too (81 px at 320, 41 at 360, 11 at 390). It only fits from ~460–500 logical px up. This is the card the previewed footer sits under, so it shows up in every offer-stack preview at phone width.

## F12

ChatOfferOnlyOneFooter: The same Row overflows even with only the Accept button (a declined offer, onDecline: null): 21 px at 320 pt EN. And at 200% text it overflows at every phone width regardless: 189 px at 320, 149 px at 360, 119 px at 390 (EN); 132/92/62 px (AR).

## F13

ChatOfferOnlyOneFooter: Harness gap that let the above ship: testPreviewsRender()/pumpPreview() in test/previews/preview_test_harness.dart pump in the default 800×600 viewport and ignore JeebPreview.size, so a preview declared at Size(390, …) is actually asserted at 800 px wide. offer_card_bubble_widget_test.dart has the same blind spot — 800 px is wide enough that the overflow never fires. Preview render tests currently cannot catch device-width layout bugs unless the preview constrains its own width (this preview does, for the narrow state).

## F14

OrderChatPinnedSummary: Unknown tier ids leak the raw wire token to the user. `_tierLabel` (lib/features/chat/presentation/widgets/order_chat_pinned_summary.dart:196-197) ends in `default: return widget.summary.tierId;`, so any tier the app does not know is painted verbatim in the tier chip. Verified by rendering `tierId: 'same_day_priority'` in the ARABIC UI: the chip painted the literal ASCII string `same_day_priority`. Note the asymmetry inside the same class - `_statusLabel` has an honest localized floor (`deliveryStageMatched`) for unrecognised wire values, and an EMPTY tier already falls back to the localized `orderSummaryValuePending`; only a non-empty unrecognised tier has no fallback. Given how often mobile has been catching up to newer gateway contracts, a new tier id shipping server-side puts untranslated English snake_case in an Arabic user's header.

## F15

OrderChatPinnedSummary: Expanded, the strip has no height ceiling and does not scroll. Measured on the 390 dp canvas: 204-272 dp at 1x but 368-452 dp at textScale 2.0 (widget-test font, so an upper bound vs real Inter) - over half of an 844 dp phone viewport, sitting directly above the message list. Nothing overflows and nothing is clipped, so this is NOT the run-22 'BOTTOM OVERFLOWED' class returning: the two-line description clamp and the collapsed-by-default choice are both doing their job. It is a note that at 200% text the disclosure is an either/or - see the locked fields OR see the conversation - with no middle state.

## F16

JeeberRemovedBanner: Icon drifts to the vertical middle once the text wraps. `jeeber_removed_banner.dart:30` uses a bare `Row(...)`, so `crossAxisAlignment` defaults to `.center`. Measured at 320 dp: the text block starts at y=12 while the Icon's top is y=32 — the info icon sits mid-paragraph instead of on the first line. Invisible at 390 dp / 1.0 text scale (one line), guaranteed at small-phone width and at any text scale that forces a wrap. Fix is `crossAxisAlignment: CrossAxisAlignment.start` on the Row.

## F17

JeeberRemovedBanner: The icon does not participate in text scaling. `Icons.info_outline` is pinned to `Sizes.large` (measured 20 dp) and stays 20 dp at a 2.0 text scale while the paired `bodyMedium` copy doubles — measured banner height goes 84 dp → 224 dp at 390 dp wide with the icon unchanged. At the accessibility ceiling the only non-text affordance in the band becomes proportionally tiny; it needs `MediaQuery.textScalerOf(context).scale(Sizes.large)` if it is meant to read as part of the sentence.

## F18

JeeberRemovedBanner: The 'Under fee notice' state shows two saturated full-bleed bands sharing an edge with no divider or gap: `ChatFeeBanner` (`secondaryContainer` = #0B1351 navy in light, #444759 in dark) sits flush on this banner (`errorContainer` = #B00020 light / #930A0A dark). Both are reachable together for a Jeeber viewer, and the seam is the only thing distinguishing a neutral fee notice from an error notice.

## F19

ChatComposer: lib/features/chat/presentation/widgets/chat_composer.dart:121-125 — the field's TextEditingController is re-synced ONLY by a BlocListener on a composerText *transition* (`listenWhen: prev.composerText != curr.composerText`), never on mount. A ChatComposer mounted over a ChatCubit that already holds text renders an EMPTY field with the 'Type a message' hint showing, while the send pill is ENABLED. Probed directly: seed `ChatState(composerText: 'draft x')` → `EditableText.controller.text == ''`, `find.text('Type a message')` matches, and `ChatComposerIconButton.onPressed != null` on the send key. Reachable in production because chat_screen.dart:811 mounts it conditionally (`if (state.isComposerVisible)`, i.e. `phase != ConversationPhase.closed`): any phase flip to `closed` and back (load / refresh / push all re-read phase) unmounts and remounts the composer with a fresh empty controller, so the user's draft disappears from the field but survives in the cubit — and tapping the still-lit send pill posts text they can no longer see. Not fixed here (production code was off-limits); the previews work around it with a post-frame `composerChanged` (_TypeOnMount), which is why that helper exists.

## F20

ChatAppBar: test/chat_dm_header_parity_test.dart:87 `_transparentPng` is a CORRUPT PNG and its D1 test is therefore vacuous. The IDAT length field reads 0x0000000D while only 10 bytes of deflate data follow (verified: the canonical 67-byte 1x1 PNG declares 0x0000000A), so the image never decodes. The test survives only because it asserts widget types after a single `pump()` — before the async decode fails. Under `pumpAndSettle` the failure is real and destructive: the failed decode is cached process-wide, so the SECOND and every later test in the same file that resolves this provider gets an ErrorWidget in place of the photo, which lays out at 1148x28 inside the 104dp leading slot and throws `A RenderFlex overflowed by 1092 pixels on the right` from chat_app_bar.dart:101. The preview uses re-encoded, CRC-correct bytes instead; the existing fixture should be replaced the same way or D1 is not actually pinned.

## F21

ChatAppBar: The back affordance visibly changes size when a Jeeber is matched. `_ChatBackButton` sets `iconSize: Sizes.large`, and `Sizes.large` is 20.0 (omds spacing.dart:58) — but the pre-match header falls through to `OMDSAppBar._buildBackButton`, which uses the Material default 24dp, as does the trailing `order_chat_open_dispute` action. Flipping between the 'Broadcasting' and 'Matched' previews shows the chevron shrink from 24 to 20 while the report icon beside it stays 24. Reads as an accidental token pick (`large` for an icon size), not a design decision.

## F22

ChatAppBar: At the 200% text ceiling the avatar initial exactly fills its disc, with zero margin, and clips above it. `OmdsProfileAvatar._buildPlaceholder` puts a text-scaled `Text` (fontSize size/2.5 = 19.2) inside a fixed 48dp `Container(shape: circle)`. Measured at 390dp width: the glyph box goes 19.4x27 at 1.0x, 38.7x48 at 2.0x — exactly the 48dp disc — and is clamped/clipped to 48x48 at 3.0x. The disc never grows, and because Flutter's AppBar clamps only its TITLE to 1.34x (`_kMaxTitleTextScaleFactor`), the initial ends up scaling ~1.8x next to a name that scaled 1.34x, so the two are visibly out of proportion in the 'EN 200% text' rendering of every fallback-avatar state.

