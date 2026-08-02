# Wave 12 (kyc + delivery_status) — defects surfaced by the previews

8/8 written, 44 previews. Recorded, not fixed.

## F01

KycIdentityStep: `_ScrollForSelfieHint` (kyc_identity_step.dart:482) puts its label in a `Row(mainAxisSize: min)` with no `Flexible`, and the `Text` sets no `maxLines`, `overflow` or `softWrap`. Its only failure mode is a silent mid-word clip — and what gets clipped is the JEBV4-295 cue that exists precisely so the below-the-fold selfie section is not missed. Pinned structurally (font-independent) plus measured: 449 dp needed vs 318 given at EN 200%, 436 vs 350 at AR 100%. CAVEAT I verified rather than assumed: those pixel numbers are measured under flutter_test's fixed-width test font (every glyph a square of the font size), which roughly doubles real Arabic width — so this is a 'widest plausible label' stress proxy, not a claim that a shipping phone clips today. The structural gap is the finding; the numbers show its shape.

## F02

KycIdentityStep: The submit CTA's `kycWizardSubmitting` branch (kyc_identity_step.dart:426) is dead code. `KycWizardScreen._buildBody` returns `KycSubmittingView` for `step == KycWizardStep.submitting`, so `KycIdentityStep` is never built in that step and the 'Submitting…' label can never render. There is no honest state to preview it from, which is how the preview exposed it.

## F03

KycIdentityStep: A jeeber parked on the disabled CTA is told nothing. Since JEBV4-295 the CTA is gated on `hasSelfie && hasValidIdNumber`, but both inline id-number errors are submit-scoped (`state.submitFieldError`) — and the gate is exactly what prevents a submit from producing one. The cold-entry preview renders a dead button, `errorText: null`, and no summary of what is missing; the scroll-hint pill is the only indirect clue, and it disappears the moment a selfie is captured.

## F04

KycIdentityStep: `isRequired: true` on the id-number field (kyc_identity_step.dart:318) is inert. `OmdsTextField` reads `isRequired` only in the built-in validator branch, which the supplied `validator` bypasses, and it renders no required marker on the label — so the one field the live contract makes mandatory for every id type carries no visible required indicator. Pinned in the cold-entry test (`isRequired` true while `labelText` is the bare 'National ID number').

## F05

KycSubmittingView: 200% text lays the spinner OFF the bottom of the phone. `_SubmittingBody` (kyc_submitting_view.dart:203) is a centred Column with no scroll view, so on a 390x700 wizard body at textScaler 2.0 it overflows by 84 dp (EN) / 124 dp (AR) and the spinner's rect is Rect.fromLTRB(183, 740, 207, 764) — entirely below a 700 dp viewport, with nothing to scroll it back. On the 320 dp small-phone box the overflow is 528 dp (EN) / 344 dp (AR). Both boxes fit at 100% text, and the 800x600 default test surface hides it completely. The single element that says 'something is still happening' is the first thing to leave the screen at the accessibility ceiling.

## F06

KycSubmittingView: The live region STUTTERS for screen readers. `Semantics(container: true, liveRegion: true, label: l10n.kycSubmittingTitle, hint: l10n.kycSubmittingBody)` (kyc_submitting_view.dart:182-192) wraps a body that already renders those same two ARB keys as Text, and sets neither `excludeSemantics: true` nor `explicitChildNodes: true`, so the descendants merge into the container's own label. The announced node is label == 'Submitting your documents\nSubmitting your documents\nHang tight — we're uploading your ID and selfie. This usually takes a few seconds.' with hint == the body again: headline twice, body twice.

## F07

KycSubmittingView: The screen cannot tell a healthy submit from a hung one, and offers no way out. The view takes no arguments and reads nothing off the cubit, so all four wired states render an identical frame (pinned: the headline's rect is the same in every state). After the eight-request budget is spent there is no retry, no cancel, no elapsed-time hint and no error branch on screen — no ButtonStyleButton, no InkWell, no GestureDetector — so every remaining recovery (submit future, CDN-upload timeout, onJeeberRoleGranted) is invisible to the user staring at the spinner that 'sat for minutes' on rev2.

## F08

KycCaptureTile: Captured-state label pill cannot wrap or ellipsize and is silently clipped. `_PreviewBody` puts the label Text in a `PositionedDirectional(start:, bottom:)` with no `end`/`width`, so RenderStack measures it under UNBOUNDED width. At 200% text the real ARB Arabic label `kycSelfieStepTitle` ('التقط صورة شخصية') lays out 352 dp wide inside a 350 dp tile and its right edge lands at 397 vs the tile's 370 — chopped mid-word by the Stack's default Clip.hardEdge. No overflow stripe, no exception: `tester.takeException()` is null, so nothing flags it in debug. The widest English label ('Take a selfie') clears the same edge by only ~30 dp of text (~20 dp once the pill's 12 dp trailing padding is counted). Fix is a `maxLines: 1, overflow: TextOverflow.ellipsis` plus a bounded width on the pill — the caller cannot work around it. lib/features/kyc/presentation/widgets/kyc_capture_tile.dart:135-152

## F09

KycCaptureTile: `isProcessing` is tested BEFORE `hasPhoto` in `build`, so a retake over an existing capture blanks the photo the jeeber already took: while the picker is open the tile shows the same bare spinner as a first capture. The only visual difference between 'replacing your photo' and 'taking your first one' is the container border (1 dp `outline` vs 1.5 dp `outlineVariant`). Pinned by the `Retake in flight · photo hidden` preview. lib/features/kyc/presentation/widgets/kyc_capture_tile.dart:64-68

## F10

KycCaptureTile: Both processing states drop the tile's only visible text — `OmdsLoadingState` replaces the camera glyph AND the slot label, and it is constructed with no `message`. `find.byType(Text)` finds nothing. With three identical tiles stacked in `KycIdentityStep` (front / back / selfie), a sighted user cannot tell which slot is busy; the `Semantics` label survives, so this reads worse visually than it does for a screen reader. lib/features/kyc/presentation/widgets/kyc_capture_tile.dart:65

## F11

KycCaptureTile: The tile pins its height and has no width of its own, and its two bodies disagree about a LOOSE width constraint: the captured `Stack` (all children positioned) expands to the maximum while the `_PlaceholderBody` `Column` shrink-wraps to icon+label. Measured under a plain Scaffold body on a 390 dp box: empty = 144 dp wide, captured = 390 dp. The same slot would visibly change width the moment a photo landed. Only `KycIdentityStep`'s `crossAxisAlignment: CrossAxisAlignment.stretch` hides this today — dropping the tile into a Wrap, a Row without Expanded, or any non-stretch Column reintroduces it.

## F12

KycCaptureTile: The `errorBuilder` fallback for undecodable bytes gives the user no signal. A grey box with a generic `Icons.image_outlined` glyph, still labelled as if captured, is indistinguishable from a legitimately dark photo — there is no 'this photo could not be read, retake it' affordance. This is not an edge case in practice: `StubPhotoPickerService` (the default picker in the MVP build, in widget tests and in Maestro flows) returns a solid 0xC0 fill, so this fallback is what a stub-driven run of the whole KYC wizard actually renders.

## F13

KycIdAlignmentGuide: RTL: the four corner brackets do not mirror. PositionedDirectional moves the tick BOXES to the correct side in Arabic (verified: the start tick's rect goes from frame.left+13 in EN to frame.right-13 in AR), but _CornerPainter takes `isStart` as a synonym for "left" and never reads a TextDirection — and a canvas is not flipped for RTL. The painted elbows are identical in both directions (both draw (0,0)->(24,0) and (0,0)->(0,24)), so in Arabic every bracket is anchored to its INNER edge and points into the frame instead of hugging its corner. Pinned in both directions in the test's 'KycIdAlignmentGuide corner brackets' group.

## F14

KycIdAlignmentGuide: `title` is never painted. It is handed to Semantics only, so the visible guide has no heading at any width and `kycIdAlignmentGuideTitle` is copy no sighted user ever reads (the production state renders exactly one Text, the caption).

## F15

KycIdAlignmentGuide: The caption is announced twice by a screen reader. Semantics(container: true, label: title, hint: caption) has no explicitChildNodes/excludeSemantics, so the caption Text is merged into that node: the node's label is 'Align your ID inside the frame\nPlace the card flat, fill the frame, and avoid glare.' and its hint repeats the same sentence (childrenCount == 0).

## F16

KycIdAlignmentGuide: `caption` is required but nothing rejects an empty string: an empty caption paints zero pixels while still laying out 12 pt (Spacing.small) plus a blank ~16 pt line band under the frame, and sets an empty Semantics hint — an unexplained gap that reads as a layout bug rather than as missing copy.

## F17

KycIdAlignmentGuide: The frame does not scale with the user's text size while the caption does. It is locked to maxFrameWidth (240) at the ID-1 ratio, so on a 320 pt phone at 200% text the caption wraps to eight lines (320 pt of text) under an unchanged 240 x 151 rectangle — the guide needs ~483 pt of height, pushing the capture tiles it is meant to introduce well out of the first viewport.

## F18

KycIdAlignmentGuide: On a tablet the guide is marooned: KycIdentityStep never wraps itself in ResponsiveBody (the widget whose own doc says to wrap any body that should respect responsive constraints, and which would clamp it to a 600 pt column), so on an 834 pt body the caption paragraph runs more than twice the width of the 240 pt frame it describes.

## F19

KycIdAlignmentGuide: The ID-1 rectangle and the card-flat wording are hardcoded, but KycIdType also admits passport and residency, and the step passes this guide the same national-ID title/caption and the same 85.6x54 frame for all three. There is no passport/residency guide copy in the 1534-key ARB to preview — a passport data page is not ID-1 shaped.

## F20

KycLivenessPromptCard: CONTAINER HAS NO PERCEIVABLE EDGE: kyc_liveness_prompt_card.dart:39 fills the card with `scheme.primaryContainer.withValues(alpha: 0.6)` and gives it no border and no elevation, so that fill IS the card's only boundary. Measured contrast of the composited fill against the scaffold it sits on: 1.162:1 in light (#FFDBD1 at 60% over white = #FFE9E3) and 1.444:1 in dark (#3C4279 at 60% over #131318 = #2C2F52). Both are far under the 3:1 WCAG 1.4.11 asks of a non-text boundary; the card reads as loose text, not as a container. The alpha is what spends it — the opaque token is already only 1.288:1 light / 1.982:1 dark, and 60% removes a further ~44% / ~40% of that. Note the INK is not the problem (onPrimaryContainer measures 14.71:1 / 9.92:1 over the composited fill), so the fix is the fill or an outline, not the text colour. This also quietly undercuts the tone-pair decision documented in app_theme.dart:67-88, which chose #FFDBD1/#3A0B01 so the container would read.

## F21

KycLivenessPromptCard: DANGLING 12 dp GAP ON AN EMPTY LIST: `const SizedBox(height: Spacing.small)` (kyc_liveness_prompt_card.dart:52) is emitted BEFORE the `for` loop rather than inside it, so it survives when `prompts` is empty. `prompts` is a plain List with no assert and no non-empty precondition. Measured at 390 dp: card.bottom - title.bottom = 28.0 (Spacing.medium 16 + Spacing.small 12) where 16 is correct, giving a 64 dp card around a 20 dp line of text. Same shape as the WAVE05 PendingCountdownCard dangling-gap finding. Today's only caller hardcodes two cues, so this is latent rather than shipping — it lands the moment the cue list becomes server-driven.

## F22

KycLivenessPromptCard: CUE ICON DOES NOT SCALE WITH THE TEXT IT LABELS: `Icon(prompt.icon, size: Sizes.large)` (kyc_liveness_prompt_card.dart:83) is a raw 20 dp constant. Measured 20.0x20.0 at BOTH textScale 1.0 and 2.0, while the cue text beside it grows past 2x (row text height 60 -> 200 in the same pump). At the 200% accessibility ceiling the glyph is roughly a quarter of the height of the line it belongs to, and because the row uses `CrossAxisAlignment.start` it pins to the top of the whole wrapped block rather than optically to the first line — so on a multi-line cue the bullet floats above its own sentence.

## F23

DeliveryDetailsCard: Unclamped text growth: no `maxLines`/`overflow` anywhere in `_DetailRow`, so address lines grow the card without bound. Measured at 390 dp wide, the 'Longest content' state is 574 dp at 1x but 1918 dp at 200% text (1966 dp in Arabic at 200%) — over three phone screens for one card. Because the screen stacks DeliveryJeeberCard and the action bar BELOW it (delivery_status_screen.dart:263-267), a 200%-text user must scroll past three screens of address to reach Contact/Cancel. Sibling widgets in this app clamp (OrderChatPinnedSummary clamps its description to two lines for exactly this class of bug).

## F24

DeliveryDetailsCard: Empty `primary` renders a blank row. `_DetailRow` guards the sub-line with `secondary != null && secondary!.isNotEmpty` (delivery_details_card.dart:125) but applies no guard to `primary`. A `DeliveryAddress(label: '')` — a pickup the gateway has not geocoded yet — mounts a labelled row with an empty Text under it, so the card reads as broken rather than as pending. The asymmetry is visible in the 'Unresolved pickup' preview and pinned by the `find.text('') findsOneWidget` assertion in the test.

## F25

DeliveryDetailsCard: User-supplied addresses use a plain `Text`, so they take the ambient Directionality instead of their own first-strong direction. An Arabic address in an English UI is laid out with an LTR base direction (left-aligned, trailing Arabic comma placed on the wrong edge) and vice-versa. This repo already ships `AutoDirectionText` (lib/features/chat/presentation/widgets/auto_direction_text.dart) and uses it for exactly this — chat bubbles, the pinned order summary, customer_profile and delivery_man_profile headers — but delivery_details_card.dart does not. Visible in the 'Arabic addresses in EN UI' preview.

## F26

DeliveryDetailsCard: The icon disc does not scale with text. `Container(width: Sizes.twoXLarge (32), height: 32)` holding an `Icon(size: 18)` is fixed, while the label/value/sub-line beside it scale with the text scaler. At 200% text a 32 dp disc sits beside a ~150 dp-tall text column, and because the Row is `crossAxisAlignment: .start` the disc detaches from the value it marks. Arguably intentional for icons, but it is the one part of the row that does not respond to the accessibility setting.

## F27

DeliveryLifecycleBanner: The widget documents itself as a "Single-line banner" but it is not one at accessibility text scales: at 200% text the band grows from 64 dp to 144 dp at 390 dp width, and to 184 dp (4 wrapped lines) at 320 dp. It degrades by wrapping rather than overflowing — no RenderFlex stripe — but any caller that sizes a fixed-height slot for it on that doc comment will clip it. lib/features/delivery_status/presentation/widgets/delivery_lifecycle_banner.dart:8-9

## F28

DeliveryLifecycleBanner: The status icon does not scale with text. `Icon(icon, color: foreground)` (line 54) takes the default 24 dp and lib/core/theme/ never sets `IconThemeData.applyTextScaling` (grep for applyTextScaling/iconTheme in lib/core/theme returns nothing), so at the 200% rendering a 24 dp glyph labels 28 pt copy — the icon reads as a decoration rather than the status marker it is.

## F29

DeliveryLifecycleBanner: The `Row` at line 52 keeps the default `crossAxisAlignment: center`, so as soon as the sentence wraps the icon floats to the vertical middle of the text block instead of holding the first line. Measured at 320 dp / 200% text: icon centre at y=92 against a text block starting at y=12 — 68 dp below the line it marks. `CrossAxisAlignment.start` (with the icon nudged to the line box) is the usual fix.

## F30

DeliveryLifecycleBanner: No screen-reader affordance for what is a state-change announcement: the banner has no `Semantics` wrapper, no `liveRegion: true` and no header semantics. It appears on a push-driven status screen at the moment a delivery goes terminal, so a sighted user sees the delivery flip to Delivered/Cancelled and a TalkBack/VoiceOver user is told nothing until they re-scan the screen. (Found reading the source while building the a11y previews, not from the rendering — the preview matrix does not surface semantics.)

## F31

DeliveryEtaBadge: Icon opts out of text scaling: `Icon(Icons.timer_outlined, size: 16)` has no `applyTextScaling`, and nothing in `AppTheme` registers an `iconTheme` to turn it on (Flutter's default is false). At the 200% ceiling the label goes 11→22pt, the value 14→28pt and the pill 44→64pt tall, while the timer glyph stays exactly 16 — measured identical at 1.0x and 2.0x. It is the only element of the pill that ignores the accessibility contract the rest of it honours.

## F32

DeliveryEtaBadge: The pill is a different colour family in each scheme. It fills with `colorScheme.primaryContainer`, which `AppTheme.light()` overrides to the brand ORANGE container (#FFDBD1, hue 13°) but `AppTheme.dark()` derives from the NAVY seed (#3C4279, hue 234°). So the ETA pill — one of the few coloured fills on the delivery screen — is orange in light and blue in dark. Contrast is fine at both ends (13.28:1 and 7.23:1), so this is identity, not legibility; only a side-by-side rendering (the matrix's AR RTL dark variant) shows it.

## F33

DeliveryEtaBadge: The badge exports all layout pressure to its sibling and absorbs none. Neither `Text` sets `maxLines` or `overflow`, and at its only call site (the header `Row` in `_Body` of delivery_status_screen.dart) it is the non-flexible child beside an `Expanded` "Delivery #id" caption — so it is laid out first against unbounded width and can never shrink. With real Inter metrics at 200% on a 320pt phone (280pt row) the pill takes 213pt, leaving the caption 67pt: it wraps into six stacked fragments and drags the header from 44pt to 192pt tall, taller than the stage indicator under it. Nothing overflows, but the header stops reading as a header. (The caption's own missing `maxLines`/`ellipsis` is in the screen, not the badge; the two together are what produce this.)

## F34

DeliveryEtaBadge: The layout ceiling is a phrase, not a number: "Arriving now" makes the pill 175pt wide on a 350pt row (200% → 284pt), while the largest ETA the offer composer can even produce (120 min, `OfferEtaBand.defaultBand()` caps at 120) makes it only 140pt (200% → 213pt). Anyone tuning this widget for a 3-digit number is tuning for the wrong state — and the Arabic strings measure the same, not less, because the wider AR label ("الوصول" vs "ETA") cancels the narrower AR value ("يصل الآن" vs "Arriving now").

