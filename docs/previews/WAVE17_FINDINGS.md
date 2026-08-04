# Wave 17 (cancellation + chat + delivery_status + location) — defects

8/8 written, 45 previews. First wave using selective `matrix: true`.

## F01

CancellationSuccessSheet: `CancellationSuccessSheet.build` never reads its `result` — the whole `CancellationResult` is dead. Three materially different gateway payloads render byte-identical strings AND an identical box (proven in the test, not by eye). The consequential case: `pendingApproval: true` means a post-pickup client cancel is still AWAITING ADMIN REVIEW, and the user is shown the same unqualified 'Delivery cancelled' over a 'Done' button with no hint anything further will happen. Same for the jeeber: `strikeCount` and `restriction: 'red'` (the tier that gates a jeeber out of the feed) arrive here and are shown nowhere — this sheet is the only screen the gateway hands them to.

## F02

CancellationSuccessSheet: The success check mark inks with `colorScheme.primary` (`_SuccessIcon`, cancellation_success_sheet.dart:78) — brand navy in light, a pale lavender in dark. Every other success affordance in the app uses the semantic role `context.jeebRoles.success` (availability_card.dart:72 and :129, order_status_chip.dart:46, dispute_status_screen.dart:280, delivery_lifecycle_banner.dart:33). The single glyph carrying 'it worked' reads as chrome rather than as confirmation, in both brightnesses.

## F03

CancellationSuccessSheet: The 56 pt check icon does not text-scale: `Icon` only follows the text scaler when `IconThemeData.applyTextScaling` is set, and it is not. Measured: at 200% the title grows by >1.9x while the icon stays exactly 56 pt, so the hierarchy inverts and the confirmation glyph stops being the largest thing on the sheet.

## F04

CancellationSuccessSheet: Read from `CancellationSuccessSheet.show()` rather than exposed by a preview (a canvas cannot show a scrim): it calls `showModalBottomSheet` with the default `isDismissible: true` / `enableDrag: true`, so a scrim tap or a swipe-down pops ONLY the modal and never runs `onDone`. `onDone` is what pops the root-navigator route and then `CancellationScreen` itself — dismiss it any way other than the button and the user is left sitting on the cancellation reason-picker for a delivery that is already cancelled.

## F05

CancellationReasonGroup: Selection is carried entirely by a raw 24 dp Icon that does not text-scale: at 200% the label height doubles (24→48 dp, row 56→64 dp) while the radio glyph stays exactly 24×24. It is the ONLY visual difference between a chosen and an unchosen reason, so the signal shrinks precisely for the users who need it biggest. Pinned in test 'the radio glyph never grows with the label it marks'.

## F06

CancellationReasonGroup: Every row is announced TWICE. `_ReasonTile` wraps `OmdsSettingsRow` in `Semantics(container: true, label: label, button: true)` while the `ListTile` underneath publishes its own labelled, tappable node — so a screen-reader swipe through 4 reasons costs 8 stops and says each label twice. Verified by walking the node's descendants (test 'each row is announced TWICE').

## F07

CancellationReasonGroup: The node that owns the `cancellation_reason_<code>` identifier is flagged `isButton` but has NO `SemanticsAction.tap` — `onTap` was passed to `OmdsSettingsRow`, not to the Semantics wrapper. The identified, button-roled node is not the tappable one.

## F08

CancellationReasonGroup: It is a radio group in name only (the class doc and AC4 both call it one), but the semantics never set `isInMutuallyExclusiveGroup` and never give the rows a checked state — only `selected`. A screen-reader user hears 'Other, selected, button' with no signal that the four options are one exclusive choice. `flagsCollection.isChecked` is `CheckedState.none` on every row.

## F09

CancellationReasonGroup: An empty `reasons` list is accepted with no assert and produces a zero-height Column — the widget has no empty state of its own. The screen degrades to the prompt 'Why are you cancelling?' over a blank gap and a submit button that can never enable. Measured height == 0.0 in test 'an empty reason list renders NOTHING'.

## F10

CancellationReasonGroup: With a multi-line label the radio floats at the vertical CENTRE of the paragraph (ListTile centres its leading slot because `isThreeLine` is never set), not beside the first line the reader starts on. Harmless at today's ≤24-char labels; visible the moment a longer reason or translation ships.

## F11

SystemMessageBubble: Dead fallback branch, reachable degradation instead: `_copyFor` falls back to the generic ARB copy on `payload == null`, but NOTHING can hand it a null — `DeliveryChatMessage.offerAccepted` takes a required payload and the only decoder (lib/features/chat/data/chat_message_codec.dart:216) builds it via `SystemOfferPayload.fromWire`, which resolves a missing `winnerJeeberName`/`jeeberName` to the EMPTY STRING (`... as String? ?? ''`), never to null. So a partially-populated gateway row takes the NAMED branch with `name: ''` and, because the runtime loader substitutes with a plain `replaceFirst('{name}', '')`, the pill renders "'s offer was accepted" in EN and a trailing-space "تم قبول عرض " in AR. Pinned by the 'Offer accepted · nameless payload' preview and its render test.

## F12

SystemMessageBubble: Hardcoded/untranslated copy on the `system` kind: that branch returns `message.text` verbatim, so every system notice the chat-service writes ships to Arabic users in whatever language the gateway chose. Asserted in the test — pumping in `Locale('ar')` still finds the English server sentence. Inherent to a pass-through channel, but it means the AR half of this widget is only localized for two of its three code paths.

## F13

SystemMessageBubble: RTL/bidi gap: SystemMessageBubble renders its copy with a bare `Text`, while every sibling body in chat_message_bubble.dart (lines 192/250/308) uses `AutoDirectionText` for first-strong direction detection. Measured: an Arabic `system` notice inside an English thread resolves to `TextDirection.ltr`, so its sentence-final '.' is laid out on the wrong side of the sentence. The two offer kinds are unaffected (their copy always matches the UI locale); only the server pass-through kind can carry the opposite script. Pinned by the 'an Arabic server notice keeps the AMBIENT direction' test, written so it fails loudly if the widget is ever brought in line.

## F14

SystemMessageBubble: The pill has no max-width token and no `maxLines` — its only bound is the 16 dp gutters. Measured at 390 dp with the bundled font, a long registered name ('Abdulrahman Al-Muhandis Al-Trabulsi') gives text of 326x48 (three lines, in a 358x56 pill) at 1x and 326x160 (five lines) at 2x. Width is pinned by the gutters in both, so the whole 2x cost is height: a ~3.3x taller row mid-thread. There is no overflow stripe — it degrades by growing — but `OmdsBorderRadius.pill` was drawn for one line, so at that size the chip reads as a rounded paragraph rather than as chrome.

## F15

SystemMessageBubble: Minor addressability bug: the `Key('chat-system-<id>')` lives on the outer Padding, so the empty-text early return (`if (text.isEmpty) return const SizedBox.shrink()`) drops the key along with the widget. A collapsed system row is therefore not addressable by key from a widget test or a Maestro flow — you can only assert its absence, never distinguish 'correctly collapsed' from 'never built'. The 'Empty + unsupported collapse' preview carries a third, real notice specifically to make that distinction visible.

## F16

ChatBubbleTimestamp: No `.toLocal()`: `chat_bubble_timestamp.dart:46` formats `sentAt` exactly as handed to it, while both sibling call sites of the same `DateFormat.Hm` skeleton convert first (`delivery_stage_indicator.dart:136`, `jeeber_feed_card.dart:749`). A UTC instant renders the UTC hour with no signal — 21:05 UTC on 11 June shows as 21:05 instead of 00:05 the next day in Beirut. Only `ChatMessageCodec.sentAtOf` keeps the live paths correct; the widget trusts its caller completely.

## F17

ChatBubbleTimestamp: The default ink is unreadable on any filled bubble. `color ?? onSurfaceVariant.withValues(alpha: opacityHigh)` is a surface role; composited over `colorScheme.primary` it measures 1.65:1 in the light theme (#5C4038 at 87% over #0B1351) against a 4.5:1 AA floor for 11pt text, and worse in dark where `ColorScheme.fromSeed` makes both roles pale. `chat_message_bubble.dart:574` escapes this only by passing `color:`; the widget carries no assert and no contrast-aware fallback, so one omitted optional argument ships an invisible clock. Pinned in the test's contrast group.

## F18

ChatBubbleTimestamp: The Arabic clock is not localized at all. Measured: `DateFormat.Hm('ar')` renders '12:34' — byte-identical to English — because intl 0.20.2 ships no `ZERODIGIT` in the generic `ar` date symbols (only `ar_EG` has one). The widget's 'locale-aware, never a string-built clock' claim therefore buys nothing in the app's only non-English locale, and adding an `ar_EG` locale would silently switch digit systems with no code change. Related: `chat_date_separator_preview.dart:62` documents the opposite expectation ('must show ... Arabic-Indic digits') for the same locale, so that doc comment is wrong.

## F19

ChatBubbleTimestamp: The widget's only layout opinion is dead on one of its two callers. `Align(AlignmentDirectional.centerEnd)` does mirror (verified: the clock moves left of the bubble centre in AR), but `chat_message_bubble.dart:565` wraps the meta row in `Directionality(textDirection: TextDirection.ltr)`, so inside the message bubble the clock never mirrors however Arabic the thread is. Only the offer card exercises the directional contract.

## F20

DeliveryStageIndicator: Stepper labels overflow and cannot shrink. `OMDSLabeledStepperProgress` lays its four step labels out in `Row(mainAxisAlignment: spaceBetween)` with no Expanded, no Flexible and no maxLines (omds_library/lib/src/indicators/omds_stepper_progress.dart:229). Against the 350 dp the indicator gets on a 390 dp phone, the render suite measures `A RenderFlex overflowed by 84 pixels on the right` — the yellow/black stripe — on the delivery status screen. The test's fallback font is wider than the bundled Inter so 1x is likely safe on device, but the 200% rendering doubles every glyph and no font survives that. Pinned by the test `the stepper label Row has no flex and overflows when narrow`.

## F21

DeliveryStageIndicator: The cancelled state contradicts itself. `lifecycle == cancelled` forces `completedSteps` to 0 and makes `_isReached` false for every stage, so all four dots go `outlineVariant` and the stepper track empties — but `stageTimestamps` is untouched, so rows that DID happen still print `at 09:12` / `at 09:31` underneath a dot claiming the milestone was never reached. The card asserts 'this never happened' and 'this happened at 09:31' simultaneously.

## F22

DeliveryStageIndicator: Cancellation has no word on this widget. The ARB already carries `deliveryStageCancelled` ("Cancelled" / "تم الإلغاء") and `DeliveryStageIndicator` never references it; cancellation is communicated only by four dots turning grey — meaning by colour alone, invisible to anyone who did not see the card a moment earlier. In production `DeliveryLifecycleBanner` carries the sentence several rows above, so the indicator itself is silent.

## F23

DeliveryStageIndicator: A reached milestone with no timestamp renders as done AND waiting. `_isReached` comes from stage ordering while the caption comes from the `stageTimestamps` map, so when the gateway sets `stage: delivered` without backfilling the intermediate entries (offline jeeber syncing once, admin-forced transition), the first three rows draw as reached — primary dot, primary label — with the `Waiting…` pending caption under them.

## F24

DeliveryStageIndicator: Timestamps are time-of-day only, so a delivery that crosses midnight reads as going backwards. `_formatTime` is `DateFormat.Hm` with no date component, so a real late-night order renders 23:47 → 23:58 → 00:12 → 00:35 top to bottom with nothing indicating two days elapsed. Same defect, worse: a parcel matched yesterday 10:00 and delivered today 10:05 is indistinguishable from one that took five minutes.

## F25

DeliveryStageIndicator: `_StageDot`'s hollow-ring branch is dead. The Container sets `color: color` unconditionally and then `border: filled ? null : Border.all(color: color, width: 1.5)` — same colour as the fill — so the unreached dot is a solid `outlineVariant` disc, never an outline. Reached vs pending is therefore carried by hue alone (primary vs outlineVariant) with identical shape, which is the pairing to check hardest in the dark rendering.

## F26

DeliveryStageIndicator: The active pulse is clipped by its own box for the top of its range. The halo is `Sizes.medium * (1.0 + value * 0.6)` = up to 25.6 dp, inside a `SizedBox(width: Sizes.xLarge, height: Sizes.xLarge)` = 24 dp whose Center/Stack pass loosened 0..24 constraints down. Everything past value ≈ 0.83 is clamped to 24 dp, so the ring stops growing before the animation does. (Constraint arithmetic from the source, not a measured frame — the previews freeze the ticker.)

## F27

DeliveryStageIndicator: Every stage name renders twice per card — once in the stepper's label row, once in the milestone row below it. Visually redundant, and a screen reader announces each of the four milestones twice. Pinned by the test `each stage label renders twice`, which is also why `expectedText` pins timestamps rather than labels: `find.text('In transit')` can never be findsOneWidget here.

## F28

DeliveryJeeberCard: Nothing clamps: neither the name nor the vehicle Text in _JeeberRow sets maxLines or overflow, so long content wraps and the card grows without limit. Measured card height for a full legal name + a long KYC vehicle label: 202 dp at 100% text, 742 dp at 200% text on a 390 dp phone, 1366 dp at 200% on a 320 dp phone — roughly two screens for one card. No RenderFlex overflow is ever raised (it grows rather than clipping), so both scrolling call sites degrade quietly, but the card cannot be dropped into a fixed-height slot.

## F29

DeliveryJeeberCard: The rating chip is not inside an Expanded/Flexible, so it takes its intrinsic width first and the Expanded name column pays for it. At 200% text on 390 dp the card WITH a chip is 278 dp tall carrying the SHORTER name ('Karim H.') while the card WITHOUT one is 206 dp carrying the longer 'Kamal Hajj' — i.e. the same name wraps only when the jeeber happens to have a rating. A report that 'the name is cut off for some drivers and not others' is this layout, not bad data. Pinned by 'the rating chip costs the name column its width budget'.

## F30

DeliveryJeeberCard: Blank display name is only half-handled. _initial() guards the empty string and paints '?' in the avatar disc, but the name Text has no fallback, so the card renders '?' over a completely empty first line above the vehicle label. That reads as a broken card rather than as 'we don't have their name yet', and nothing on the card distinguishes the two. Pinned by 'a blank display name yields "?" over an EMPTY name line'.

## F31

DeliveryJeeberCard: The rating chip is not localized in content. deliveryJeeberRating is the identical '{rating} ★' in app_en.arb and app_ar.arb, and the value comes from rating.toStringAsFixed(1), so the Arabic UI shows Western digits plus a literal star ('4.5 ★'). The chip as a whole does mirror correctly under RTL (verified: avatar leads, chip trails in both directions), but the numeral system and the star glyph are locale-independent by construction.

## F32

CaptureLocationPin: Anchor is ~3.3 pt off the coordinate it claims. The widget lifts the glyph by `-Sizes.large` (20) — exactly half of `Sizes.threeXLarge` (40) — which puts the icon's BOX bottom on the host centre, and its doc comment reads that as 'its TIP sits at the viewport centre'. The Material `location_on` path bottoms out at y=22 of the 24-unit grid, so at 40 pt the drawn spike ends ~3.3 pt above the box edge: the pin marks a point ~3 pt NORTH of the coordinate `CaptureLocationScreen` returns from its CTA. Visible in `captureLocationPinAnchorCrosshair`, which draws the target under the pin; not assertable in a widget test because the test font substitutes a solid block for the glyph outline.

## F33

CaptureLocationPin: It paints 20 pt outside its own layout box with no clip, and nothing in its API says so. The layout box is 40x40 but the painted region starts 20 pt above it, so any caller that does not put it in a Stack/Center over a map silently overdraws its neighbour. `captureLocationPinInlineOverdraw` puts it in a Column: 20 pt of glyph lands inside the row above, and the test confirms NO exception is thrown — the box fits, only the paint escapes, and the framework only reports the former.

## F34

CaptureLocationPin: A clipped host under 80 pt loses part of the pin's head, silently. Painting starts 40 pt above the anchor (20 pt of box + 20 pt of lift), and a centred pin puts the anchor at half the host's height. `captureLocationPinCompactBand` (a 48 pt ClipRRect thumbnail — the obvious next caller for a saved-address row) loses exactly 16 pt off the top with no overflow stripe, no exception and no debug output. The shipping `AddressDetailFormScreen` band is safe only by accident: `Sizes.eightXLarge * 2` = 160 leaves 40 pt of margin, and neither widget records that 80 pt is the floor.

## F35

CaptureLocationPin: The drop shadow is `colorScheme.shadow` in BOTH schemes — #000000, which M3 does not tone for dark. Composited at `UIConstants.opacityLow` it measures 2.59:1 against the light map fill but 1.31:1 against the dark one, so the halo that is the only thing lifting a saturated pin off a busy map tile does effectively nothing on a night map. The pin's own ink is fine either way (5.66:1 light, 7.28:1 dark), so this is a separation problem, not a colour one.

## F36

LocationSearchBar: Picking a suggestion leaves a FALSE empty state: LocationPickerCubit.selectSearchResult emits {searchQuery: <address>, searchResults: [], isSearching: false}, which is exactly the triple build() reads as 'nothing matched' — so the bar renders 'No matching addresses' directly under the address the user just chose. Pinned by the 'Just selected · false empty state' preview and by the tap test on the five-match preview.

## F37

LocationSearchBar: A FAILED search is indistinguishable from zero results: _runSearch catches, emits LocationPickerError.searchFailed and leaves searchResults alone; the screen turns the error into a transient snackbar (location_picker_screen.dart:110) and the bar keeps showing 'No matching addresses' after it fades. The bar has no way to say 'we could not search'.

## F38

LocationSearchBar: A result with address == null is offered to the user as raw coordinates ('33.8938, 35.5018' — location_search_bar.dart:155), and the fallback Text carries no textDirection, so under an Arabic paragraph bidi reorders the pair and the LONGITUDE is painted first. Verified by RenderParagraph.getBoxesForSelection in the AR test: the latitude box sits to the right of the longitude box.

## F39

LocationSearchBar: The input ignores the user's text-size setting: OmdsSearchBar wraps its TextField in SizedBox(height: UIConstants.textFieldHeight = 48). Measured 48 pt at both 1x and 200% while the hint's own height grows — at 200% the typed text is clipped to a 48 pt box.

## F40

LocationSearchBar: _ResultsList is shrinkWrap: true + NeverScrollableScrollPhysics inside a Column, so a tall list cannot give height back. On the 390x460 canvas box, five suggestions at 200% text cut the space under the bar from 128 pt to 28 pt. Here the stand-in below is Expanded and merely shrinks; LocationPickerScreen's Column (step badge, bar, draft card, two button rows) has no flexible child to absorb it.

## F41

LocationSearchBar: Tapping the clear button fires onChanged('') TWICE: OmdsSearchBar._clearSearch calls widget.onChanged('') and then widget.onClear(), and LocationSearchBar wires onClear to () => onChanged('') (location_search_bar.dart:51). On the picker screen that is two searchAddress('') calls, two emits and two rebuilds per tap. Asserted in the test (changes == ['', '']).

## F42

LocationSearchBar: `query` does not fill the field — OmdsSearchBar renders only what its controller holds, and `query` merely gates the dropdown. The constructor requires `query` but leaves `controller` optional, so a caller who passes only `query` gets an empty-looking field with a populated dropdown hanging under it. LocationPickerScreen keeps the two in step by hand from a BlocListener (location_picker_screen.dart:117); nothing in the widget enforces it.

