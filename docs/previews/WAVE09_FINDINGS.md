# Wave 09 (live_tracking) — defects surfaced by the previews

8/8 written, 45 previews. Recorded, not fixed.

## F01

OrderSummaryPinnedHeader: Vertical overflow, unguarded: `order_summary_jeeber_name` is the only Text in the header with no maxLines and no overflow (the price beside it is maxLines:1+ellipsis, and both facts in _HeaderFactStrip are clamped). At the 200% text ceiling a three-part name ('Abdulrahman Al-Muhandis Al-Trabulsi') wraps unbounded and the pinned header needs 732 dp of height, against 444 dp for the identical row containing 'Kamal Hajj'. Isolated by measurement: swapping the huge SYP price back to 12.50 USD still measures 732 dp, so the name is the sole cause. On a phone this eats the viewport and pushes the stepper and map off screen. tracking_header_overflow_test.dart cannot see it because it pumps a 914 dp-tall A33 surface, so 732 dp fits and takeException() stays null.

## F02

OrderSummaryPinnedHeader: Item summary has no bidi handling. `Text(info.itemSummary!)` at order_summary_pinned_header.dart:105 is a bare Text with no textDirection, so an Arabic request ('٢ كيلو تفاح من سبينيس') typed by the customer renders with an LTR paragraph base inside the English UI. The sibling strip that shows the SAME field on the chat surface routes it through AutoDirectionText (UAX#9 first-strong) — order_chat_pinned_summary.dart's `order_chat_request_description` — so the two surfaces disagree about the same string.

## F03

OrderSummaryPinnedHeader: Item summary is the only field in the header with no Semantics(identifier:). jeeber name, price, tier, ETA and the cash label each have one; the itemSummary Text (line 105) has none, so Maestro/e2e cannot assert on the D71 item line at all.

## F04

OrderSummaryPinnedHeader: Price is unformatted and unlocalized: `_formatPrice` is `price.toStringAsFixed(2)` plus the bare ISO code, so a Syrian-lira amount renders '1234567.89 SYP' — no thousands separator, no Arabic-Indic digits in the AR rendering, and a code rather than a symbol. The chat sibling's equivalent fixture is '1,250,000 L.L.', so the two customer-facing summaries format the same money differently.

## F05

OtpAtDoorCard: Dead entrance animation: OtpAtDoorCard.build wraps the card in an AnimatedSlide whose offset is a hard-coded `const Offset.zero`. Implicit animations only run on a value CHANGE (ImplicitlyAnimatedWidgetState sets the initial value directly in initState and only forwards the controller from didUpdateWidget), and this offset can never change — so the "T-MOB-017 AC4: Slides in when status transitions to at_door" behaviour its own doc comment claims does not happen. The card pops into place, and the AnimatedSlide is pure cost. lib/features/live_tracking/presentation/widgets/otp_at_door_card.dart:27-33.

## F06

OtpAtDoorCard: The CTA does not grow with text. OmdsLoadingButton hard-codes `height: Sizes.fourXLarge` (48 pt) and centres the label, so the tap target ignores textScaler. Measured at 200% in the preview harness: button rect 48 pt tall, label rect 40 pt tall — 4 pt of clearance top and bottom, in EN and AR alike. It does not clip today, but there is no room left for a longer translation or for Android's display-size multiplier on top of font scale. This is in OMDS, not in the card, so it is a report-not-fix.

## F07

OtpAtDoorCard: The card has no height ceiling and no scroll fallback. `_CardContent` is a plain Column (mainAxisSize.min) sitting in a fixed slot of the tracking screen's own Column. Measured heights at 390 pt wide (widget-test font, so a worst case — the real Inter face reads shorter): 320 pt at 1.0 with a code vs 724 pt at 200%, i.e. ~2.3x. At 320 pt wide and 200% it wants 812 pt against the ~568 pt such a phone has, and overflows in both locales; at 390 pt only EN overflows, because the Arabic copy is materially shorter (276 pt / 588 pt vs 320 pt / 724 pt). Nothing in the widget degrades — it paints overflow stripes over the map at the exact moment the customer needs the code.

## F08

OtpAtDoorCard: At 320 pt and 200% the inline code panel fills the entire 272 pt of available width (its Spacing.xLarge horizontal padding, doubled by the card's own, does not scale with text) and HandoverCodeDisplay has no FittedBox or wrap escape — an all-numeric string has no break opportunity. Measured with the widget-test font, so this is the ceiling rather than a reproduction on-device; the 4-digit contract survives, but the panel has no headroom for a fifth glyph.

## F09

OrderTrackingStepper: RTL: the OMDS progress bar does not mirror. `_StepperPainter` (omds_stepper_progress.dart) draws `drawLine(Offset(0, y) -> Offset(width * progress, y))` in raw canvas coordinates and never reads Directionality, while the step row above it is a `Row` and mirrors normally. In Arabic at step 2 of 4 the labels run right-to-left but the fill still grows from the LEFT edge, so the ink sits under the two steps that have NOT happened and the two completed steps sit over bare track. Pinned by the test 'AR mirrors the step row but NOT the progress fill' (paints matcher + label positions).

## F10

OrderTrackingStepper: 200% text: every step label overflows its column and is ellipsized silently, at the SHIPPING width, not just on compact devices. Four `Expanded` columns of a 390pt phone are 97.5pt; at textScaleFactor 2.0 the widest unbreakable word in each of 'Ordered', 'Picked', 'In transit', 'Delivered' exceeds that (and 80pt at 320pt). `maxLines: 2` cannot rescue 'Ordered'/'Delivered' because they are single words, and `TextOverflow.ellipsis` means there is no overflow stripe and no exception to notice it by. Pinned by two tests.

## F11

OrderTrackingStepper: Terminal state never reads as complete: `_StepNode.isDone` is `i < currentStep`, so the final step can only ever be `isActive`. A delivered order renders three `check_circle` ticks plus one `radio_button_checked` ring — the same glyph the in-transit state shows in that column — while the bar underneath is 100% full. Pinned by 'a delivered order still renders its last step as active, never as done'.

## F12

OrderTrackingStepper: Off-by-one framing in the bar: `completedSteps: currentStep + 1` counts the CURRENT step as complete, so a brand-new order (step 0, nothing has happened) already shows a quarter-full progress bar. Probably intended, but it is the convention the whole component rests on and it is undocumented at the call site; the 'Ordered' preview is there to make it visible.

## F13

TrackingNoShowSheet: No scroll fallback: the sheet's body is a plain Column(mainAxisSize.min) with no SingleChildScrollView, and `show()` uses isScrollControlled: true, which caps the sheet at the screen height and no more. Measured heights under `flutter test` (monospaced substitute font, so pessimistic): 390 pt wide = 376 pt at 100% / 824 pt at 200%; 320 pt wide = 424 pt / 904 pt. A scratch probe reproduced the hard failure — 'A RenderFlex overflowed by 304 pixels on the bottom' at 320 pt / 200% in a 600 pt viewport. On the 568 pt phone the app still supports, a customer at the accessibility ceiling cannot reach the bottom-most 'Keep waiting' CTA at all. The widget's own doc comment already concedes the body is not scroll-safe ('EXEMPT: OmdsBottomSheet lacks a `show` static factory with a scroll-safe body'), but nothing compensates for it here.

## F14

TrackingNoShowSheet: CTA labels are clipped, not wrapped: OmdsPrimaryButton fixes its pill at 48 pt (Sizes.fourXLarge) for every text scale and centres the label inside it, so a label that needs two lines is clamped instead of growing the button. Measured at 200% text: one line is 40 pt, yet 'Choose another offer' / 'Keep waiting' report exactly 48 pt — i.e. the paragraph is being cut by the pill. With the production Inter face this bites at the 320 pt width (248 pt of usable label width vs ~280 pt needed); with the wider test font it already bites at 390 pt. There is no ellipsis and no auto-shrink, so the user sees a sliced label on the primary recovery action. Fix belongs in OMDS or in a maxLines/FittedBox at the call site, not in the preview.

## F15

TrackingNoShowSheet: The no-show copy is not in the ARB. All five strings come from LiveTrackingL10n._pick() feature-local EN/AR maps (the file documents this as temporary pending integrator-owned keys trackingNoShowTitle/Body/ReassignCta/RebroadcastCta). The AR RTL rendering therefore looks correct only because someone hand-wrote the Arabic inline — the strings are invisible to the translation pipeline and to any third locale. Layout-wise RTL is clean: EdgeInsets.all + crossAxisAlignment.stretch means there is nothing directional to mirror, and the AR text is shorter than EN (592 pt vs 824 pt at 200%), so Arabic is the easier case here, not the harder one.

## F16

TrackingGoogleMap: TrackingGoogleMap has no fallback for a map that cannot come up. `build()` returns a bare `GoogleMap` — a platform view — with no placeholder, no loading state and no error state of its own. Under `flutter test` and in the preview canvas (a generated Flutter web app whose index.html never loads the Google Maps JS API; this repo ships no `web/` target) the map band lays out and paints nothing at all. On device the same shape means a Maps SDK that fails to initialise leaves a silent empty rectangle; only TrackingMapSurface's `surfaceContainerHighest` container keeps it from being a hole in the screen.

## F17

TrackingGoogleMap: `trackingCamera` hardcodes `LatLng(33.8938, 35.5018)` (Beirut downtown) as the last-resort frame, and nothing on the surface marks that frame as a guess. The `Nothing known` preview shows the consequence: a confidently-centred city view with zero relationship to the delivery. It is also an un-configurable Lebanon-specific constant — any delivery outside Beirut opens on the wrong city until the first fix or polyline arrives.

## F18

TrackingGoogleMap: `lost` and `awaitingFirstFix` are pixel-identical at this widget's level: both draw no marker and keep the route, so 'we never had the courier' and 'we had the courier and lost them' are indistinguishable. The widget's own doc concedes the explanatory copy lives one layer up in CourierPositionNotice, which only TrackingMapSurface stacks on. Any caller that mounts TrackingGoogleMap directly — which is a supported public constructor — silently ships the phantom-pin fix without the honest half of it.

## F19

TrackingGoogleMap: The widget contributes no accessibility surface of its own: no Semantics wrapper, no label, and `zoomControlsEnabled: false` + `myLocationButtonEnabled: false` leave pinch/drag as the only way to change the view. The `Semantics(identifier: 'tracking_map', image: true, label: …)` that makes this reachable to a screen reader is on TrackingMapSurface, not here, so it is lost for any direct caller — the same layering gap as the position notice.

## F20

TrackingMapSurface: OVERFLOW at the width the screen ships at. CourierPositionNotice is bottom-anchored by _MapBody._stacked in a PositionedDirectional band of 390 - 2*Spacing.medium = 358 pt, but OmdsChip lays its label out in a Row with mainAxisSize.min and no Flexible/maxLines/overflow (omds_library/lib/src/layout/omds_chip.dart:123-149), so the Text is measured with an unbounded main axis and is never wrapped, ellipsized or clipped. At 390 pt every visible-notice state except the shortest overflows, in BOTH locales. Measured in flutter_test font metrics: stale 3 min EN 57 px / AR 19 px; lost 5 min EN 270 px / AR 175 px; lost 100 min EN 295 px / AR 200 px. 'No signal from the Jeeber' (the sub-minute copy) is the only one that fits, which is the control that rules out 'the band is just too narrow for any chip'.

## F21

TrackingMapSurface: The same chip overflows at the 200% text ceiling even on a wide (800 pt) surface, so this is not only a narrow-phone problem — it is the accessibility ceiling failing at any width. The placeholder chrome itself is sound at 200% (asserted as a control), so the failure is attributable to the chip, not to the surface.

## F22

TrackingMapSurface: Testing gap that hid the above: the existing suite for this widget (test/features/live_tracking/tracking_position_status_test.dart:482) pumps TrackingMapSurface onto the default 800x600 test surface, where the same chip fits with ~400 pt to spare. The phantom-pin affordance has therefore only ever been verified at a width no user has.

## F23

TrackingMapSurface: Contrast, inherited rather than newly measured: _MapPlaceholderMark inks Icons.navigation_outlined with scheme.onSurfaceVariant at UIConstants.opacityMedium over surfaceContainerHighest — the identical recipe test/previews/location/capture_map_viewport_preview_test.dart already measures at 2.88:1 in the light scheme, under the 3:1 WCAG 1.4.11 asks of a graphical object (dark passes at 3.67:1). I did not add a duplicate contrast assertion for it here.

## F24

DeliveryTrackingPanel: Stepper labels are clipped at 200% text on a real phone frame. `OMDSLabeledStepperProgress` lays its three labels out in a bare `Row(mainAxisAlignment: spaceBetween)` with no Flexible/Expanded and no ellipsis (/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile/.claude/worktrees/omds-main/omds_library/lib/src/indicators/omds_stepper_progress.dart:229). The panel is a `FractionallySizedBox(widthFactor: 0.78)`, so it gets 304pt inside a 390pt frame; at 200% text the labels overflow by 257pt and 'In transit' is pushed entirely off the panel. No existing test sees this because the default flutter_test surface is 800pt wide, where the panel measures 624pt and everything fits. Pinned by the 'stepper labels run past the panel at 200% text' test.

## F25

DeliveryTrackingPanel: The distance unit is never translated. `distanceLabel` arrives pre-formatted from the gateway and is pasted into the localized frame `trackingDistanceAway`, so the Arabic line renders as `يبعد عنك 128.6 km` — an English unit inside an Arabic sentence. Only the frame is localizable today; the ETA line next to it does translate its unit (`دقيقة`), so the two disagree.

## F26

DeliveryTrackingPanel: The deadline line's cost at large text is unbounded. `if (info.deadline != null)` adds a fourth line, and the panel's `Column` has no clip, no scroll and no `maxLines` anywhere: measured at 390pt/200% text, the three-line block wants 276pt and the four-line block 404pt. Any host that gives this panel a fixed slot has to absorb a 46% jump that only appears on rows that carry a Q-061/D18 deadline.

## F27

CourierPositionNotice: LAYOUT / 200% TEXT — the notice cannot wrap or ellipsize; past its band it simply overflows. `OmdsChip` (omds_library/lib/src/layout/omds_chip.dart:140) puts the label in a bare `Text` inside `Row(mainAxisSize: MainAxisSize.min)` with no Flexible/Expanded, no maxLines and no TextOverflow — and a Row hands non-flex children UNBOUNDED main-axis constraints, so the label lays out at full intrinsic width whatever the box says. Measured under the test font: exactly one line at every width (16px tall at 1.0x, 32px at 2.0x) even when that line wants 1225px. In production `TrackingMapSurface._stacked` gives the row 358px on a 390px phone (PositionedDirectional start/end: Spacing.medium), so the longest copy overflows the map surface instead of reflowing. It fails hardest on exactly the copy that matters most — the `lost` sentence that is the only on-screen explanation for a pin that just vanished. Reproduced as a real RenderFlex overflow ("overflowed by 323 / 708 pixels on the right") and pinned by a characterization test in the preview test file. Fixing it requires touching courier_position_notice.dart or OmdsChip, so I left both alone.

## F28

CourierPositionNotice: COPY BUG — `Stale · no age reported` renders "Jeeber's location is 0 min old". `_label` (courier_position_notice.dart:79-88) guards a null/sub-minute age on the `lost` branch only (`positionLostNoticeNoAge`) and passes `minutes ?? 0` on the stale branch. The widget's own doc comment says that fallback exists because "0 min ago" "reads as a glitch and undercuts the one row the customer has to trust" — the stale rung has no equivalent guard. Reachable from the wire: `parsePositionStatus` honours an explicit `positionStatus:"stale"` without requiring `secondsSinceUpdate`, which is what a gateway mid-deploy or a field-dropping proxy sends.

## F29

CourierPositionNotice: A11Y — the leading icon does not scale with text. `Icon(size: Sizes.small)` hard-codes 12px, which also overrides OmdsChip's own `IconTheme(size: 18)`, and `applyTextScaling` is off. Measured 12x12 at both 1.0x and 2.0x while the label grows 16px -> 32px, so at the 200% ceiling the freshness icon is roughly a third the height of the sentence it qualifies — and it is already the smallest icon of any chip in the design system.

## F30

CourierPositionNotice: L10N — this copy never reaches the ARB. `positionStaleNotice`, `positionLostNotice` and `positionLostNoticeNoAge` live in LiveTrackingL10n's hand-authored `_pick(en, ar)` map (live_tracking_l10n.dart:91-105), not in app_en.arb/app_ar.arb, and unlike the other interim strings in that file they are absent from its own "delete this file once the integrator adds …" list — so they are invisible to gen-l10n and to the translator workflow, and nothing will flag them when the file is eventually deleted. Consequence visible in the AR renderings: one fixed form "دقيقة" for every count ("…قبل 1440 دقيقة") where the app supplies CLDR plurals for comparable counters elsewhere.

