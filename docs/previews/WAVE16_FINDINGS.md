# Wave 16 (request_type + home_client + active_delivery_jeeber) — defects

8/8 written, 43 previews. Recorded, not fixed.

## F01

RequestTierCard: Contrast (light, unselected): the two description lines are `colorScheme.onSecondaryContainer` (#777FC0, the Figma periwinkle) on the white `surface` card = 3.76:1, under the 4.5:1 WCAG AA floor for `bodySmall` (12 sp). The SELECTED card is white-on-navy at 17.1:1, so on the real screen the four tiers a customer is still comparing are the illegible ones and the one already chosen is not. Pinned in the `RequestTierCard defects` group.

## F02

RequestTierCard: Accessibility (activation): `RequestTierCard` wraps `Semantics(button: true, checked: selected, inMutuallyExclusiveGroup: true)` around `ExcludeSemantics(child: Material(InkWell(onTap: ...)))`, which strips the InkWell's `SemanticsAction.tap`. The resulting node has `actions == 0` while advertising itself as a checkable button; `tester.semantics.tap(...)` throws a StateError. A sighted tap still works (ExcludeSemantics is not IgnorePointer), but nothing can activate the tier radio through the semantics tree — screen-reader activation depends on the platform synthesising a touch, and Flutter never dispatches a tap action.

## F03

RequestTierCard: 200% text: the leading tier glyph is `Icon(size: Sizes.large)` and the radio is `SizedBox.square(Sizes.xLarge)` — both raw dp constants. At the accessibility ceiling the copy doubles (the Standard card grows 106 -> 302 dp tall) while the 20 dp glyph and the 24 dp radio, the only mark that says which tier is selected, stay exactly the same size.

## F04

RequestTierCard: Announced label: every tier is read out with a doubled full stop — "Standard. Delivered later today at a balanced rate.. Mid price • Best value." The ARB template `requestTypeTierSemanticLabel` is "{title}. {speed}. {value}." but the `tier*Speed`/`tier*Value` strings already end in a period. Composed in `_TierEntry` + the ARB, not in the card, but the preview is where it surfaced.

## F05

RequestLocationRow: 200% text deletes the current-location label, silently. `_ChangeAction` is not wrapped in `Flexible`, so it takes its full intrinsic width first and the `Flexible` label absorbs 100% of the shortfall. Measured at 390pt with the real Inter face: with the production ARB pair at textScale 2.0 the label is handed 105.7pt of the ~233pt it needs (Arabic: 124.4pt) and ellipsizes; with a slightly longer action label ('Change pickup location') it collapses to 16.0pt — the ellipsis glyph and nothing else. There is no RenderFlex overflow and no exception, so nothing in CI reports it: the label just vanishes while the action keeps every pixel it asked for. lib/features/request_type/presentation/request_location_row.dart:36 — the fix would be wrapping `_ChangeAction` in `Flexible` too, or giving the label a minimum width.

## F06

RequestLocationRow: The change-location tap target is 44pt tall, under the 48x48 Material minimum. The `InkWell` in `_ChangeAction` measures 154.9 x 44.0 at 1x — a 20pt text line plus `Spacing.small` (12) vertical padding — with no `ConstrainedBox` or `MaterialTapTargetSize` guard. Width is fine; only the height is short.

## F07

SelectableRadioGlyph: Contrast / a11y — `SelectableRadioGlyph(selected: true)` with no `ring` is invisible on any surface that is not `colorScheme.primary`. `selected` resolves ring AND dot to `onPrimary`, which is only legible over `primary`; drawn over `surface` it measures 1.00:1 in AppTheme.light() (pure white on pure white) and 1.41:1 in AppTheme.dark(), both far under the 3:1 WCAG 1.4.11 floor for graphical objects. The widget cannot observe the surface it is painted on, so nothing enforces the pairing — it holds today only because both callers (RequestTierCard:82, ClientLocationOptionCard:65) flip their card fill to `primary` in the same statement as they pass `selected: true`. Any third caller (a checklist row, a filter sheet) gets a blank card by default. The existing `ring` parameter is a working escape hatch, but the caller has to know to reach for it. Shown by the 'Selected on surface · vanishes' preview and its 'ring override' control.

## F08

SelectableRadioGlyph: Text scaling / a11y — the glyph is completely text-scale-blind. `Sizes.xLarge` (24dp box), `Sizes.threeXSmall` (2dp ring) and `Spacing.small` (12dp dot) are all fixed tokens, and neither SizedBox.square nor the two Containers opt into `applyTextScaling`. At the 200% accessibility ceiling the tier-card copy beside it roughly doubles while the glyph stays exactly 24dp (pinned by the 'glyph does not grow with text scale' test), so the trailing column stops reading as a control and becomes a dot next to the text — for the user who most needs to see selection state. Nothing clips, so no golden or overflow assertion catches it. (The same fixed-24dp observation is noted from the other side in lib/previews/location/client_location_option_card_preview.dart:32.)

## F09

SelectableRadioGlyph: Token discipline — the dot is sized with `Spacing.small` (a spacing-ramp token) rather than `Sizes.small`, in selectable_radio_glyph.dart:63-64. Both constants are currently 12.0 so it is invisible today, but it means a future adjustment to the spacing ramp silently resizes the radio dot. Everything else in the widget (`Sizes.xLarge`, `Sizes.threeXSmall`) correctly uses the size ramp.

## F10

SelectableRadioGlyph: Non-finding worth recording so nobody re-checks it: RTL is a genuine non-event here. The glyph is a concentric circle with no directional padding, so size and colours are identical under `ar` (asserted). What RTL moves is the glyph's position inside its host row, which is already covered in test/previews/location/client_location_option_card_preview_test.dart.

## F11

ClientHomeEmptyView: CTA pill cannot hold its own label at the 200% accessibility ceiling. OmdsPrimaryButton hard-codes `height: Sizes.fourXLarge` (48pt) and `_NewOrderButton` never overrides it, so the pill — and the 48pt tap target — is unchanged at 2x while the label is not: the height the label needs goes from 40pt at 1x to 120pt at 2x (80pt in Arabic) inside that same 48pt box. Nothing clips and nothing throws; the label simply paints outside the button. Pinned by 'DEFECT: the CTA pill stays 48 pt while its label needs more'.

## F12

ClientHomeEmptyView: The empty state's only action falls below the fold on real devices, and the widget has no scroll of its own to hint at it. It relies entirely on the host ListView in ClientHomeScreen._ReadyLayout (unlike its sibling JeeberFeedEmptyView, which owns a SingleChildScrollView). Measured against the slot the pending tab actually gets: on a 320x568 phone the CTA's top is 72pt past the fold at DEFAULT text size; at 200% on a 390pt phone it is 125pt past; at 320+200% the subtitle starts 124pt and the CTA 380pt below the fold, leaving only the illustration and the top of the title on screen. Pinned by 'DEFECT: at 320 pt the CTA is below the fold at 1x text'.

## F13

ClientHomeEmptyView: A null `onNewOrder` renders a full-strength, tappable, screen-reader-announced button that does nothing. `_NewOrderButton` passes `onTap: () => onPressed?.call()` — non-null whatever the host did — and never sets `isEnabled: false`, so OmdsPrimaryButton paints the primary fill, keeps its GestureDetector live, and the wrapping Semantics(button: true) still announces a button; the tap is absorbed silently. The wired and unwired states are pixel-identical (asserted), which is the problem: on a surface whose only affordance is this CTA, a host that forgets the callback ships a dead end rather than a disabled control.

## F14

ClientHomeEmptyView: The illustration is the absolute token `Sizes.twoHundredLarge` (200pt), not a fraction of the frame and not text-scaled: it is 51% of a 390pt width and 63% of a 320pt one, and at 200% text it is the only band on the surface that does NOT grow — so it monopolizes the shrinking above-fold area exactly when the copy and CTA need it most.

## F15

RepliesCard: 200% text: `_RepliesActions` overflows a 390 dp card by 208 dp in EN and 94 dp in AR (measured in the preview's own box; the 800 dp default test surface hides it). It is an end-aligned Row of two `IntrinsicWidth` pills with no Wrap/Flexible/FittedBox — at 100% the pills are 100.6 dp + 201.2 dp, at 200% the row needs ~566 dp against ~358 dp of content width. Because `MainAxisAlignment.end` puts the negative remaining space in FRONT of the row and RenderFlex clips hard-edge, `Accept` is clipped off the leading edge entirely (left in EN, right in AR) and `Check Offers` is cut at the other end — the card is left with no fully reachable action at the accessibility ceiling. Pinned in `test/previews/home_client/replies_card_preview_test.dart`.

## F16

RepliesCard: `_OfferAvatar` hardcodes `initial: 'J'` (replies_card.dart:281). The card never receives the offerers' names, so every offerer without a profile picture renders as the same letter — three offerers become three identical 'J' circles. This is not preview-only: the empty/absent `profilePicUrl` path is a real production path, and the stack claims to identify people it cannot tell apart.

## F17

RepliesCard: `RepliesCard`'s own class doc opens with "Layout: title + tier badge, destination, …" but `_RepliesHeader` builds only the title and the avatar stack — no `ClientHomeTierBadge` anywhere. A Flash reply and a Standard reply are pixel-identical on this tab, while the sibling `PendingRequestCard` renders the badge from the same `request.tier` field.

## F18

RepliesCard: `offerCount == 0` collapses the entire avatar cluster to `SizedBox.shrink()`, but the card has no empty branch of its own — it still renders both `Accept` and `Check Offers`. A row with zero offer evidence invites the sender to accept an offer that does not exist (reachable whenever the list row omits `offerCount`, which defaults to 0, or an offer is withdrawn between the list read and the render).

## F19

RepliesCard: AR-RTL-dark rendering: `_RepliesHeader` paints the order id — the card's primary identifier — in `colorScheme.secondaryContainer`, a BACKGROUND role used as ink. The light scheme hand-pins that token to navy so it looks fine (~17:1), but the dark scheme is generated by `ColorScheme.fromSeed` and the same token lands at ~2:1 on the dark surface, below even the 3:1 large-text floor. Already pinned by the sibling suite (`test/previews/home_client/replies_tab_preview_test.dart`, 'DARK: the order id is a container colour used as ink') so I did not duplicate the assertion — flagging it because `RepliesCard` is the owner of the defect, not `RepliesTab`.

## F20

RecentDeliveryCard: Localized CTA starves the text column at every phone width. OmdsPrimaryButton has a null `width`, so as a non-flex Row child it takes its intrinsic label width first and Expanded gets the remainder. Measured at 1x: button 144.8 pt EN / 186.0 pt AR, leaving a text column of 165.2 pt EN / 124.0 pt AR at 390 pt, 135.2 / 94.0 at 360 pt (S22), 95.2 / 54.0 at 320 pt. The shortest realistic fixture in the repo ('Mini-market run', intrinsic 211.5 pt; 'Hamra, Beirut', 161.2 pt) is therefore ALREADY ellipsized on every phone in English, and both lines are clipped at every width in Arabic — ~3 characters on a 320 pt device. Widget tests never see this: their 800x600 viewport leaves ~575 pt of column.

## F21

RecentDeliveryCard: Arabic at 200% text loses the card's entire content. At 390 pt the AR label 'إعادة الطلب' scales to a 340 pt button; icon 24 + gaps 24 + 340 = 388 pt against 358 pt of content width, so RenderFlex overflows by 30 px and the Expanded text column collapses to 0.0 pt width. Both the title and the destination render at zero width — the card shows only the replay icon and the button. (EN at 200% does not overflow but leaves just 53.2 pt of text.) Confirmed by pumping at 390 pt with textScaler 2.0; reproduces on all five fixtures because it is chrome, not content.

## F22

RecentDeliveryCard: An empty destinationLabel renders as a blank line with no fallback copy. `DioClientHomeRepository._parseRecentDelivery` (lib/features/home_client/data/dio_client_home_repository.dart:667) emits `destinationLabel: ''` whenever the row has no `dropoff.address`/`dropoffAddress`, while the title still degrades gracefully to `Delivery #CC42E6`. _RecentDeliverySubtitle renders that '' verbatim: a 0 x 16 pt Text plus its 4 pt gap, so the card keeps its full 80 pt height and simply shows a gap where the address belongs. Pinned by the 'Degraded payload' preview and its specifics test.

## F23

RecentDeliveryCard: The re-order CTA has no button role for screen readers. Dumping the semantics tree gives `SemanticsNode(actions: [tap], label: "Re-order")` with no isButton flag: OmdsPrimaryButton only wraps its GestureDetector in `Semantics(button: true)` when an `identifier` is passed, and RecentDeliveryCard passes only a widget `Key`, never `identifier`. TalkBack/VoiceOver announce the card's only action as tappable text rather than a button. (Hit target itself is fine at 144.8 x 48 pt.)

## F24

GpsPermissionBanner: CTA label overflows at 200% text — the banner's ONLY recovery affordance is clipped. OMDSOutlinedButton lays its label out as the lone non-flex child of a Row, so the Text is measured against an unbounded width and never wraps. Measured RenderFlex overflow: 75 px for 'Allow location' and 47 px for 'Open settings' at 390 dp (label wants 393/365 dp against 318 dp available), 117 px at 320 dp, 74/46 px for the Arabic labels. Everything else in the band reflows correctly; the button is the piece that does not.

## F25

GpsPermissionBanner: The leading Icons.location_off_outlined is pinned at Sizes.large (20 dp) and does not respond to text scale — measured 20x20 at both 1.0 and 200% while the title beside it doubles. The one glyph that says 'location is off' becomes a footnote exactly for the users who asked for larger text.

## F26

GpsPermissionBanner: _Cta's `Align(alignment: AlignmentDirectional.centerStart)` is inert: OMDSOutlinedButton wraps its Row in a `Center` with no widthFactor, so under the loose constraints it gets, the button expands to the FULL band width (measured 358 dp of 358 dp inner at 390 dp, 288 dp at 320 dp) with a centred label. The widget reads as if it renders a compact leading-aligned pill; it ships a full-bleed button.

## F27

GpsPermissionBanner: Band height at 200% text: 836 dp (EN) for the settings variant at 390 dp and 956 dp at 320 dp — larger than a small phone's whole viewport. In the production list composition the band is 756 dp, which pushes the delivery stepper it is warning about entirely off-screen. The growth itself is the correct degradation (no clipping), but the banner is not dismissible, so at 200% the screen is effectively the banner only.

## F28

GpsPermissionBanner: Minor / placement constraint: the banner's inner Column is mainAxisSize.max, so handed a BOUNDED height it stretches to fill it (a 216 dp band renders 600 dp tall in a 600 dp box, CTA stranded at the bottom). It is only correct today because production always mounts it as a ListView child; dropping it into a fixed-height slot would deform it.

## F29

DeliveryStatusStepper: 200% text clips the advance CTA's label: `OmdsLoadingButton` hard-codes `height: Sizes.fourXLarge` (48 dp) around a plain centred `Text`, so at 2x the label wraps to two lines inside a box that stays 48 dp tall and the second line is cut off — no ellipsis, no growth, and no RenderFlex overflow stripe to warn anyone. Measured at 390 dp: 'Mark as Picked' needs >48 dp of paragraph height in the 310 dp button; Arabic 'تحديد كـ: تم الاستلام' is worse (max intrinsic width 588 dp vs 310 available). Pinned by `DeliveryStatusStepper previews · 200% text the CTA label outgrows its fixed 48 dp button`.

## F30

DeliveryStatusStepper: Stage labels have no `maxLines`, no ellipsis and no `FittedBox` in a bare `Expanded`, i.e. 310/5 = 62 dp per column on a 390 dp phone. At 200% text 'In Transit' needs 158 dp for a single word, so the label breaks MID-WORD and the label row grows from 32 dp to 160 dp, taking the whole card from 220 dp to 420 dp. Arabic hits it earlier — 'تم الاستلام' already lays out on three lines at 1x in the render test's font. Pinned by `… stage labels break mid-word in their 62 dp column`.

## F31

DeliveryStatusStepper: `done` never reads as done. `_stateAt` maps `index == currentIndex` to `current`, and `done` IS the current index, so the final stage renders in the ACTIVE styling (tertiary #D73B00 accent, bold `onSurface` label) rather than the completed one; combined with `showCheckmark: false` on `OmdsStepIndicator`, a finished delivery shows four completed stages and a fifth that still looks like work in progress. Side by side, the `Done` and `At door` cards differ only in which circle is accented, not in 'in progress' vs 'complete'.

## F32

DeliveryStatusStepper: a11y, minor: while `isTransitioning` the `mark_delivered_advance_cta` node keeps `isButton: true` but loses its tap action (`OmdsLoadingButton` drops `onTap` when loading). A screen reader announces a button that does nothing for the duration of the transition POST — there is no `enabled: false` / busy signal on the node. (The inertness itself is correct and is now pinned, with the idle card as the control.)

