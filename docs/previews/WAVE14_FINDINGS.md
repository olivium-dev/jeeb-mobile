# Wave 14 (client_offers + jeeber_request_feed) — defects surfaced

7 written, 1 skipped (FeedResumeRefetcher — `build` does side effects then
`return widget.child`). Recorded, not fixed.

## F01

OfferWindowTimer: Light-scheme urgency is effectively silent: at T-30s the ONLY thing that changes is the fill (same `offersWindowRemaining` copy template, same `Icons.timer_outlined`, same geometry, no Semantics liveRegion), and that fill steps from `surfaceContainerHighest` #E5E1E5 (luminance .762) to `warningContainer` #FEF3C7 (.893) — a 1.16:1 change. The urgent band is in fact CLOSER to the white page (1.11:1) than the neutral band it replaces (1.29:1), so the last 30 seconds of the offer window are announced by a hue shift alone. Only visible by flipping between the `Threshold · 0:31` and `Urgent · 0:30` previews.

## F02

OfferWindowTimer: The expired state is two different designs in one widget. `AppTheme.light()` never got an M3 tonal `errorContainer` — it is the legacy Material 2 #B00020 with WHITE `onErrorContainer`, so the expired band renders as a solid dark-red slab at 7.33:1 against the page, next to neutral/urgent bands sitting at 1.29:1 and 1.11:1. `AppTheme.dark()`'s errorContainer is a restrained #930A0A at 1.98:1. Same state, alarm in light and a quiet tint in dark; surfaced by the EN light vs AR RTL dark pair of the matrix.

## F03

OfferWindowTimer: `Icon(size: Sizes.medium)` opts out of the accessibility contract the rest of the band honours: `applyTextScaling` defaults to false and nothing in `AppTheme` registers an `iconTheme`, so at the 200% ceiling the countdown label scales 12pt -> 24pt while the timer glyph stays exactly 16x16. Same defect already noted on `DeliveryEtaBadge`, so it is systemic rather than local to this widget.

## F04

OfferAcceptSheet: 200% text overflows the sheet and clips BOTH CTAs — a real, reachable dead end. /Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile/.claude/worktrees/widget-previews-pilot/lib/features/client_offers/presentation/widgets/offer_accept_sheet.dart:249 is a plain Column with mainAxisSize.min and no scroll fallback, and showModalBottomSheet(isScrollControlled: true) grants height without adding scrolling. Measured sheet height at 390pt wide: idle 328 → 564pt from 1.0 to 2.0 text (fine); with the BR-10 capacity banner 468 → 924pt, which on an 844pt phone throws 'A RenderFlex overflowed by 160 pixels on the bottom' (80px in AR, whose copy is shorter), and on a 320×568 phone overflows by 516px. What gets clipped is the bottom of the stack — the Confirm and Cancel buttons — so a large-text customer who loses the accept race sees an error they can neither retry nor dismiss. Even the no-error 'Long name · LBP fee' state is 836pt at 200%, 8px short of an 844pt phone, i.e. there is no headroom left for any error state. (Heights come from flutter test, whose substituted font is wider than production Inter, so treat them as an upper bound — but the 320pt case is far past font-metric slack.)

## F05

OfferAcceptSheet: `chatOfferAccepting` is dead copy: it is translated in both ARBs ('Accepting…' / 'جاري القبول…') and never rendered. offer_accept_sheet.dart:368-370 passes `text: state.isSubmitting ? l10n.chatOfferAccepting : l10n.chatOfferAccept` to OmdsLoadingButton, but that widget renders OmdsButtonLoading (a spinner) *instead of* `text` whenever isLoading is true (omds_library/lib/src/buttons/omds_loading_button.dart:99-106). Verified in the preview: while submitting, find.text('Accepting…') matches nothing and only a CircularProgressIndicator is present.

## F06

OfferAcceptSheet: The in-flight Confirm button is silent to a screen reader. offer_accept_sheet.dart:361 hardcodes `label: l10n.chatOfferAccept` regardless of state and line 365 wraps the visual button in ExcludeSemantics, so the spinner contributes no semantics at all. Measured with tester.getSemantics while state.isSubmitting: label = 'Accept Offer', hasTapAction = false. A VoiceOver/TalkBack user is therefore told there is an 'Accept Offer' button, taps it, and gets nothing — no progress, no state change, no announcement — on precisely the screen (B-01 accept-exactly-ONE) where the app most needs to say 'this is in flight, do not go accept another offer'. `chatOfferAccepting` already exists as the string for this and would fix both this and the previous finding if used as the Semantics label.

## F07

OfferSortBar: OfferSortBar overflows its production slot at the 200% text ceiling. The offers ListView hands the bar a tight 358 dp on a 390 dp phone (client_offers_screen.dart:230 pads by Spacing.medium each side); measured with the bundled Inter face the row is 238 dp at 1x but 395 dp at 2x — ~37 dp over on a 390 dp phone, ~67 dp over on the 360 dp S22 (328 dp slot). The trailing 'Top rated' chip, the only control that reaches the rating sort, is what goes past the edge, and in the app (no clip) that paints a RenderFlex overflow stripe across the offers panel. A11y.maxTextScaleFactor clamps the OS slider to exactly 2.0, so this is the ceiling the app promises to survive, not an extreme.

## F08

OfferSortBar: Nothing in OfferSortBar's chain can absorb that growth: the label and both chips are non-flexible children of a plain Row (no Flexible, no Wrap, no horizontal scroll), OmdsChip wraps a bare Text with no maxLines and no overflow policy, and MinTapTarget only ever grows a child. So the row's width is unconditionally its content's width. The sibling widget in the same feature already has a dedicated large-text guard (test/features/client_offers/offer_card_overflow_test.dart, 200% at S24 width); the sort bar has no equivalent — production change out of scope here, so it was not added.

## F09

OfferCard: Fee pill silently truncates a REALISTIC price. _FeePill is maxLines:1 + ellipsis (offer_card.dart:650), so at 390pt phone width `LBP 1,335,000.00` (a $15 delivery at the 2026 peg) is already clipped at 130% text, and `LBP 250,000.00` clips at 200%. The headline price on the accept-ONE decision surface reads 'LBP 1,335,0…'. The cash-on-delivery line below has no maxLines and wraps, so the same card can show a truncated price above an untruncated one. Measured via didExceedMaxLines, EN and AR, at 390 and 360pt.

## F10

OfferCard: The ETA chip loses its text in Arabic but never in English. `وقت الوصول 12 دقيقة` ellipsizes inside _MetaChip (maxLines:1, offer_card.dart:688) at 200% text on 390pt and already at 130% on 360pt; the English '12 min ETA' never truncated in any tested combination. At 360pt/200% the vehicle label (سيرًا على الأقدام) goes too. ETA is one of the two facts the client compares offers on, and it is the first thing Arabic users lose. The chips sit in a Wrap, but each chip clips its own label rather than wrapping to a second line.

## F11

OfferCard: An ordinary two-word name truncates at the 200% accessibility ceiling. 'Nadine Khoury' (13 chars) ellipsizes at 390pt/200% in _NameTapTarget (maxLines:1, offer_card.dart:565); same for 'محمد الحاج'. The name row has a full line to itself and the card grows vertically anyway (292pt → ~500pt), so allowing 2 lines would cost nothing — and identity is exactly what is being chosen at this moment.

## F12

OfferCard: OfferCard.isAccepting is dead in the shipped app. client_offers_screen.dart:293 passes `isAccepting: false` unconditionally (B-01: the JM-029 confirm sheet owns the in-flight spinner), so the 'Accepting…' label + OmdsButtonLoading branch is never reachable in production while still being asserted by test/offer_card_test.dart. Previewed and documented rather than deleted, but it is live-looking dead API.

## F13

OfferCard: No RenderFlex overflow exists anywhere in this widget (checked EN/AR x 100/130/200% x 390/360pt) — which is why offer_card_overflow_test.dart's 'expect(takeException(), isNull)' passes while three separate strings are being silently clipped. That test cannot see this class of failure; the canvas shows it instantly.

## F14

RequestCard: RTL layout break: the header Row at lib/features/jeeber_request_feed/presentation/request_card.dart:278 overflows by 9.0 pt in Arabic at 390 pt width and NORMAL text scale. It is `[_TierChip, Spacer, _CountdownBadge]` with no flex on either real child, so when the Arabic tier label + 'Expires in {n}s' run long there is nothing to shrink and the countdown is clipped. The identical English card is clean, which is why no existing test catches it.

## F15

RequestCard: Overflow at real phone width in plain English: the metadata Row at request_card.dart:477 overflows by 60 pt with a six-figure LBP amount. It is two `MainAxisSize.min` badges plus a fixed 16 pt gap — no Expanded, no Flexible, no ellipsis — so it wants 384 pt in a 324 pt column ('≈ 4500000.00 LBP' alone is 248 pt). LBP is the home-market currency, so this is every card in a Lebanese feed, not an edge case.

## F16

RequestCard: Silent label clipping on the action buttons: each OmdsPrimaryButton gets (324-12)/2 = 156 pt, minus 32 pt of internal padding = 124 pt of label room, inside a container pinned to Sizes.fourXLarge (48 pt). Measured: 'Accept' = 85x20 (fits), but 'Accepting…' = 124x40 — it WRAPS TO TWO LINES at normal text scale on a 390 pt phone, and the Arabic 'جارٍ القبول…' does the same. The label has no maxLines and `Center` reports no RenderFlex overflow, so nothing warns; at 200% text every label is clamped to the 48 pt pill and its tail is cut off.

## F17

RequestCard: 200% text is broken on every state, not just the long-content one: header row overflows 137–297 pt and the metadata row 183–382 pt across all six previews. The card's natural height also grows from 270 pt to 458 pt, so the fixed-height action row is the only part that does not scale.

## F18

RequestCard: The expired (G3 linger) card has no expired styling at all. With secondsRemaining: 0 the card is visually identical to a live one apart from the two button fills dimming and the timer reading '0s' — same surface, same border, same fully saturated tier chip. A Jeeber mid-scroll gets no glanceable signal that the row is dead.

## F19

RequestCard: Weak disabled affordance on the Decline button. It is the OmdsButtonVariant.outlined variant, whose disabled state keeps a transparent fill and only fades its 1.5 pt border to 45% alpha, while the filled Accept button dims a solid fill. Side by side in the canvas — and especially in the dark AR rendering — 'this button is dead' is a substantially weaker signal on Decline than on Accept, even though _actionsLocked disables both together.

## F20

RequestCard: `request.currency` is rendered as the raw ISO 4217 code the gateway sent, never localized and never mapped to a symbol, so the Arabic rendering splices Latin 'LBP'/'USD' into RTL text mid-string via the requestFeedEarnings '≈ {amount} {currency}' template.

## F21

JeeberFeedCard: Arabic Ignore/Offer row overflows at DEFAULT text size on real phones. `_IncomingActions` (jeeber_feed_card.dart:552) is a `Row(mainAxisSize: min)` that never wraps; the Arabic labels ('تجاهل' / 'تقديم عرض') are wider than the English ones. Measured RenderFlex overflow on the trailing edge: AR 72 pt @320, 32 pt @360 (the Galaxy S22 this project tests on), 2 pt @390. EN is clean at 360/390 but overflows 31 pt @320. The trailing edge of the 'Offer' button a jeeber must tap is clipped off-screen.

## F22

JeeberFeedCard: At the 200% text ceiling the same row overflows even on a 390 pt phone: 115 pt (EN) / 198 pt (AR); at 360 pt it is 145 pt (EN) / 228 pt (AR). Separately, the AR expired-status row (`_ExpiredStatus`, hourglass + 'منتهي الصلاحية') overflows by 90 pt @390 / 120 pt @360 at 200% — a state that is clean in English at every size.

## F23

JeeberFeedCard: The accepted-action pill is NOT content-hugging at phone width, which is the exact defect the `IntrinsicWidth` in `_AcceptedAction` (jeeber_feed_card.dart:712) is commented as preventing. `IntrinsicWidth` clamps to the incoming constraint, and 'Heading to drop off' has an intrinsic width of ~268 pt — wider than the 266 pt content column at 390 pt and the 236 pt column at 360 pt — so the pill renders gutter-to-gutter. It hugs only on the 800 pt surface `test/jeeber_feed_card_test.dart` measures it on, and only with the shorter 'Order picked' label.

## F24

JeeberFeedCard: The footer never produces the single Figma row (56560:1523). `_CardFooter`'s `Wrap(alignment: spaceBetween)` reads as 'tier chip at the start, action at the end', but the tier-chip child measures the FULL content width (266 of 266 at 390 pt; 676 of 676 at 800 pt), so it takes a run to itself, the action area is always pushed onto a second run below it, and the chip's visible pill paints centred (193–257 within a 92–358 run) instead of start-aligned.

## F25

JeeberFeedCard: PRE-EXISTING FAILING TEST on main, same root cause as the previous finding: `test/jeeber_feed_card_test.dart:331` ('accepted-action pill is end-aligned (right-flush in LTR)') fails today — expected `cardRect.right - pillRect.right` < 40.0, actual 538.8. Not caused by this change; no production file was touched. The sibling test 'accepted-action pill is content-hugging' passes only because it uses the short label on an 800 pt surface.

## F26

PendingOfferRow: Dark mode erases the price. `_PriceText` paints the money string in `colorScheme.secondaryContainer` — a container FILL role used as a foreground. Light hand-authors that role as navy (#0B1351 on white = 17.13:1), which is why it went unnoticed; dark derives it from the seed (#444559 on #131318 = 1.98:1), under even the 3:1 large-text floor. The row's primary datum is the one element that disappears in the AR RTL dark rendering. The M3 pair for that fill, `onSecondaryContainer`, measures 14.29:1.

## F27

PendingOfferRow: At 200% text the price is the only thing that yields. `_PriceEtaRow` gives the price an `Expanded` and the ETA a bare `Text` with no `Flexible`, so the ETA is served first at full intrinsic width. Measured at 390dp: the LBP price wants 353.6dp and is given 150dp in EN; in AR ("1440 دقيقة" costs 242dp vs "1440 min"'s 196dp) it wants 385.9dp and is given 104dp. This is not only the extreme fixture — a plain "$18.00" wants 225.2dp of the 153dp it gets in AR at 200%.

## F28

PendingOfferRow: At 200% text the Withdraw label overruns its button. `OmdsLoadingButton` pins height to `Sizes.fourXLarge` (48dp) regardless of text scale, so "Withdraw offer" — which wants 393.4dp of the 358dp available — soft-wraps to two ~40dp lines inside a box that never grows, and the paragraph is constrained back to 48dp. The button also swells from an intrinsic 197dp pill to the full 358dp, so `Align(centerEnd)` stops meaning anything at the accessibility ceiling.

## F29

PendingOfferRow: The terminal status badge clips with no ellipsis. `_StatusBadge` uses `maxLines: 1` and no `overflow`, so at 200% text "Request declined" (wants 392dp, given 334dp) is cut mid-word with nothing to signal the loss — unlike the price, which at least ellipsizes.

## F30

PendingOfferRow: Two placeholder strings are user-visible, in both locales. The awaiting label renders `jeeberFeedStatusPending` → "Pending" / "قيد الانتظار", not "Awaiting customer decision"; a lost offer renders `requestFeedActionDeclinedSnack` → "Request declined" / "تم رفض الطلب" — a snackbar string about a jeeber declining a *request*, shown to a jeeber whose *offer* the customer did not pick. Both are documented as deliberate (the Semantics id is the asserted contract, the ARB keys are integrator-owned), but they ship as the visible copy today.

## F31

PendingOfferRow: Light mode: the awaiting label measures 3.76:1 (`onSecondaryContainer` #777FC0 on white), under the 4.5:1 AA floor for a 12sp labelMedium. Dark is fine at 14.29:1, so this one only fails in the default reading.

## F32

PendingOfferRow: The row's `Column` is `MainAxisSize.max`. Inside a `ListView.builder` (its only production caller) height is unbounded so it shrink-wraps, but dropped into any bounded-height parent the row stretches and its trailing `Divider` floats to the bottom of the box. It is why the preview host has to wrap the row in a shrink-wrapping `Column` to render the real 141dp row instead of a 600dp artefact.

