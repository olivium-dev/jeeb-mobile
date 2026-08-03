# Wave 06 (location) — defects surfaced by the previews

7 written, 1 skipped (GoogleMapCaptureView — platform view, zero Flutter pixels).
Recorded, not fixed.

## F01

CurrentLocationStatusCard: Recovery CTA label is CUT at the 200% text ceiling: OmdsPrimaryButton pins its height to a fixed 48pt (Sizes.fourXLarge) and centres the label, but the label follows the text scaler and the pill does not. Measured on a 390pt phone at scale 2.0 in both EN and AR, the paragraph needs 80pt (getMinIntrinsicHeight) and is clamped to 48pt, so 'Open settings' / 'فتح الإعدادات' is visibly cut — on the panel whose only job is telling a blocked customer how to unblock themselves. Owned by omds_library/lib/src/buttons/omds_primary_button.dart, not by this widget.

## F02

CurrentLocationStatusCard: The 'Current Location' option label truncates at the 200% ceiling: ClientLocationOptionCard._Label is one ellipsized line inside an Expanded, so it can neither wrap nor grow the row. RenderParagraph.didExceedMaxLines is false at 1.0 and true at 2.0 (390pt phone). The test font is wider than the shipped one so the exact threshold is pessimistic, but the row structurally has no second line to give.

## F03

CurrentLocationStatusCard: The GPS recovery panel stays on screen when the option is NOT selected. CurrentLocationStatusCard._detail switches on `status` alone and never consults `selected`, and LocationSelectCubit.selectSaved does not clear currentGpsStatus — so a customer whose GPS is off who works around it by picking a saved address keeps a full error panel (error-colored icon + 'Turn on location' CTA) pinned under an option they abandoned. Reachable on the live screen; pinned as current behaviour by the 'panel stays up while the option is UNSELECTED' test.

## F04

CurrentLocationStatusCard: CurrentGpsStatus.idle renders SizedBox.shrink(), so the card shows 'Current Location' selected with no spinner, no coordinate and no explanation while LocationSelectState.canConfirm is false and the Confirm CTA is disabled. That is the first frame of every session and the permanent state of any host without a GPS resolver — the one state where the card is silent about why the flow is blocked.

## F05

CurrentLocationStatusCard: _Resolving/_Resolved pad with EdgeInsetsDirectional.only(top:, start:) and no `end`, so the status label runs flush to the card's trailing edge (measured right edge 370.0 == card right 370.0 at 390pt) while the option row above keeps 16pt of internal padding on both sides. Cosmetic, but the two rows visibly fail to align on both edges.

## F06

SavedLocationsChipRow: Chip tap targets are silently clipped to 40 pt. OmdsChip pads itself out to a 48x48 tappable box (Sizes.fourXLarge, WCAG 2.2), but _ChipRow wraps the ListView in a hardcoded `SizedBox(height: 40)`, which becomes a tight 40 pt cross-axis constraint and clamps that box back down. Measured 40x92 for the Home chip — no overflow error, just an 8 pt shortfall on every chip. This repo already ships a MinTapTarget widget + preview, so 48 is the house standard.

## F07

SavedLocationsChipRow: The chip shelf does not respond to the user text-size setting. At 200% the 'Saved locations' heading grows 16→32 pt while `SizedBox(height: 40)` stays 40, and the chip capsule grows 34→40 — exactly filling the shelf with zero slack, using the test font. Any font with a taller line box than the test font's clips the chip instead of growing it. This is the state the @JeebPreview 200% rendering exists to catch.

## F08

SavedLocationsChipRow: A failed fetch is indistinguishable from an empty account. `_load` catches everything and only clears `_loading`, leaving `_locations` null, so build returns `SizedBox.shrink()` — no error, no retry, no way for the user to tell 'we could not load your addresses' from 'you have none'. SavedLocationsScreen handles the same failure with an OmdsErrorState plus retry, and the strings (savedLocationsError / savedLocationsRetry) are already translated in both ARBs; the chip row uses neither.

## F09

SavedLocationsChipRow: The row reads once in initState and can never re-read. There is no didUpdateWidget and no refresh seam, so a location saved after first build cannot appear until the whole picker is rebuilt. Pinned in the test: pumping a second preview with a different repository leaves the previous repository's chips on screen. This is exactly what the (unused) onLocationSaved callback appears to have been intended for.

## F10

SavedLocationsChipRow: Three constructor params are declared and documented but never read in build: onLocationSaved, pendingLatLng, pendingAddress. The class doc promises 'tapping a chip commits the point... the save-this-location bottom sheet may be offered' — the bottom sheet does not exist in this widget. Related: nothing anywhere in lib/ constructs SavedLocationsChipRow, so the widget currently ships unreferenced.

## F11

SavedLocationsChipRow: Home/Work chips discard SavedLocation.label. The seam seeds an address the user named 'Office'; the chip captions it 'Work' because _chipLabel returns the localized category for the home/work cases and only honours `label` for `other`. The manage screen lists the same address as 'Office', so the two surfaces name one address differently.

## F12

SavedLocationsChipRow: Long `other` labels neither truncate nor ellipsize: OmdsChip's Text sets no maxLines/overflow and the horizontal ListView gives unbounded width, so a 47-char label ('Beirut Souks — Parking Level B2, Weygand Street') just grows the chip off the viewport. With the 10-address cap there is also no scroll affordance of any kind — no fade, no count — so a user with ten saved addresses sees the same first two chips as a user with two.

## F13

CaptureMapViewport: Overflow at 200% text in any host shorter than ~108pt: the label is a plain Text with no maxLines/TextOverflow and the Column has no clip, no scroll and no minimum height, while the 56pt Icon (Sizes.fiveXLarge) does not scale. A 390x96 strip overflows by 12px and a 160x160 thumbnail by 28px — both look perfectly healthy at 1x. Confirmed by `flutter test`, not inferred.

## F14

CaptureMapViewport: Narrow hosts break in Arabic too: the shorter string 'معاينة الخريطة' still overflows the 160pt square by exactly 28px at 200%, so this is a layout defect, not a translation-length one.

## F15

CaptureMapViewport: `Container(color:, alignment: center)` shrink-wraps unbounded height, so CaptureMapViewport dropped into a ListView/SingleChildScrollView collapses from a map band to an 88pt strip (icon 56 + Spacing.small 12 + one 20pt line) with no exception and no overflow stripe. AddressDetailFormScreen only escapes this because _PinPreview wraps it in SizedBox(height: Sizes.eightXLarge * 2); nothing in the widget's API signals that the height is the caller's problem.

## F16

CaptureMapViewport: Icon contrast fails WCAG 1.4.11 in the LIGHT scheme: onSurfaceVariant at UIConstants.opacityMedium (0.60) composited over surfaceContainerHighest is #938080 on #E5E1E5 = 2.88:1, under the 3:1 asked of a graphical object — and the 56pt icon, not the 14pt label, carries 'this is a map'. The label itself is fine (7.23:1) and the dark scheme passes the icon (3.67:1), so it is the opacity fade in light mode that costs it.

## F17

CaptureMapViewport: surfaceContainerHighest sits 1.29:1 from surface in light (1.50:1 in dark), so the placeholder has no visible edge against a Scaffold. Harmless on the capture screen (full bleed) and handled on the address form (which draws its own outlineVariant hairline), but any third caller that drops it onto surface without a border gets an edgeless block.

## F18

AddEditLocationSheet: Category row overflows below the accessibility ceiling: `_CategoryRow` (lib/features/location/presentation/widgets/add_edit_location_sheet.dart:214) is a bare `Row` of three `OmdsChip`s with no Wrap, no scroll and no Flexible, so its width is fixed copy against a 350 pt box. Measured at 390 pt wide: overflows by 39 px at 1.5x text, 117 px at 2.0x EN, 158 px at 2.0x AR. 1.5x is an ordinary Android font-size setting, not the ceiling.

## F19

AddEditLocationSheet: RTL clips a different chip than LTR — and the wrong one. Once the row overflows the run packs from the left in both directions, so English loses the trailing 'Other' chip while Arabic loses the LEADING chip, المنزل (Home), which is the category selected by default in Add mode. Measured at 2.0x AR: the المنزل label spans x=355..499 in a 390 pt viewport.

## F20

AddEditLocationSheet: The primary CTA label is clipped by its own pill. `OmdsPrimaryButton` pins `height: Sizes.fourXLarge` (48) while the label wraps freely, so at 2.0x text the 'Add new location' paragraph asks for 160 pt of height inside a 48 pt box (90 pt at 1.5x) and is cut to its first line. The sheet title above it wraps to three lines correctly — only the fixed-height button clips.

## F21

AddEditLocationSheet: The Cancel button overflows too: the inner `Row` of `OMDSOutlinedButton` (omds-flutter/omds_library/lib/src/buttons/omds_outlined_button.dart:82) reports 'RenderFlex overflowed by 18 pixels on the right' at 2.0x EN.

## F22

AddEditLocationSheet: Copy/a11y: the sheet heading and the save CTA render the SAME string — `_SheetTitle` and the `OmdsPrimaryButton` are both fed `l10n.savedLocationsAddNew` / `l10n.savedLocationsEdit`, so every rendering says 'Add new location' twice, a screen reader announces the heading and the button identically, and the form offers no 'Save' verb. The ARB already ships `actionSave` ('Save' / 'حفظ') for that slot.

## F23

AddEditLocationSheet: Coordinates are seeded with unformatted `double.toString()` in `initState`, so a pin dropped at full GPS precision puts 17 characters ('33.88691234567891') into a half-sheet-wide `Expanded` field; at 2.0x text the leading digits — the only ones that identify the city — are what scroll out of view.

## F24

ClientLocationOptionCard: Unselected card has no visible boundary: `Material(color: selected ? primary : surface)` (client_location_option_card.dart:36) paints `scheme.surface`, which is byte-identical to `scaffoldBackgroundColor` in BOTH AppTheme.light() and AppTheme.dark() (measured 1.00:1). The only thing delimiting the control is the `outlineVariant` hairline at 1.29:1 (light) / 1.98:1 (dark) — under the 3:1 WCAG 1.4.11 requires of a control boundary. An unselected option reads as loose text rather than a tappable choice, worst in dark mode.

## F25

ClientLocationOptionCard: The label is hard-clamped to one line: `_Label` sets `overflow: TextOverflow.ellipsis` with no `maxLines` (client_location_option_card.dart:86), and the card has no height constraint, so a label that does not fit is truncated and the card never grows — measured 350x66 at 1x and 350x82 at 200% text regardless of label length. The two localized option labels survive 200% with real Inter, but `_SavedAddressCard` in client_location_screen.dart:559 deliberately mirrors this styling for user-entered address labels, and a realistic one ('Sassine Square, Ashrafieh — Building 12, 3rd floor, blue door') is already ellipsized at 1x/390pt.

## F26

ClientLocationOptionCard: Reusable widget with a hardcoded semantics identifier: `identifier: 'client_location_option_current'` (client_location_option_card.dart:29) is baked into every instance even though `label` and `selected` are parameters. Two cards on one screen publish the same identifier — the 'Pair in one group' preview shows `find.bySemanticsIdentifier('client_location_option_current')` matching 2 nodes, while test/delivery_create_screens_test.dart:190 asserts `findsOneWidget` on it. Any reuse for a second option silently breaks that contract test and makes the id useless for automation.

## F27

ClientLocationOptionCard: The selection indicator does not scale with text: `SelectableRadioGlyph` is a fixed `SizedBox.square(dimension: Sizes.xLarge)` = 24pt (selectable_radio_glyph.dart:27). At 200% text the label line is 40pt tall next to the same 24pt radio, so the only glyph that communicates checked/unchecked shrinks relative to everything else for exactly the users who need it largest.

## F28

ClientLocationAddRow: Label truncation, not reflow: lib/features/location/presentation/widgets/client_location_add_row.dart:63 passes `overflow: TextOverflow.ellipsis` with NO `maxLines`. That does not mean "wrap then ellipsize" — an ellipsis with no line limit caps the paragraph at the first line. Measured in the preview at phone width: row 390x64, label paragraph 326x24 (one line) with `getMaxIntrinsicWidth` > allotted width, i.e. the tail is dropped. Any translation of `clientLocationNewOption` wider than the ~326dp text budget silently loses its end. If single-line is the intent, `maxLines: 1` should be explicit; if reflow is the intent, the row needs to allow a second line.

## F29

ClientLocationAddRow: The truncation is worst exactly where accessibility needs it least: the trailing `_AddButton` is a fixed `Sizes.fourXLarge` (48dp) box plus a `Spacing.medium` (16dp) gap that do NOT scale with text, while the label cannot reflow. Pinned by test at 200% text on a 288dp row (320dp-class phone): the label's intrinsic width exceeds its allotted width, so the row's only visible affordance text is what gets cut for low-vision users. (Screen-reader users are unaffected — the ARB `addSemanticLabel` is announced separately.)

## F30

ClientLocationAddRow: Dead parameter: `_AddButton` (lib/features/location/presentation/widgets/client_location_add_row.dart:73-99) takes a required `onTap` and never uses it — `build` renders a plain `Container`, and the only gesture handler is the outer `InkWell` at line 36. `_RowContent` threads `onTap` down purely to feed it. The analyzer does not flag it (the field is 'used' by the constructor), but it reads as if the circle were independently tappable.

## F31

GpsDeniedState: NO SCROLL VIEW — the widget is Center > Padding > Column(min) with no SingleChildScrollView, so any host shorter than its content overflows and clips instead of scrolling, and the 'Open Settings' CTA (the only control on the surface) is the first thing off the bottom edge. Measured in test: 390x200 map card overflows by 80px at default text; 740x360 landscape overflows by 28px at 200% text.

## F32

GpsDeniedState: OVERFLOWS A FULL SCREEN BODY AT 200% TEXT ON A 320pt PHONE — content demands 572pt against 538pt of available body (RenderFlex overflow of 36px). This is not a cramped host: it is the whole screen of the narrowest supported device at the accessibility ceiling the project's goldens already assert.

## F33

GpsDeniedState: The 56pt icon (Sizes.fiveXLarge) does not follow the text scaler while every line of type doubles — pinned by a test asserting 56pt at both 1.0 and 2.0. It reads visibly undersized in the EN 200% renderings and is dead weight in exactly the slot where the column has run out of room.

## F34

GpsDeniedState: A11Y: the CTA carries no button role. OmdsPrimaryButton is a bare GestureDetector — semantics has hasAction(tap)=true, label='Open Settings', flagsCollection.isButton=false — and GpsDeniedState wraps it in nothing, unlike CaptureLocationScreen's own pin CTA which wraps its OmdsPrimaryButton in Semantics(identifier:, button: true). A screen reader announces the label with no hint it is activatable.

## F35

GpsDeniedState: A11Y: with onOpenSettings omitted (the default constructor) the CTA's isEnabled tristate is Tristate.none, not Tristate.isFalse, and it exposes no tap action — so assistive tech is told nothing at all rather than 'unavailable'. Visually, OMDS's disabled treatment (brand fill at 45% alpha, label at 90% alpha, deliberately legible per P0-X01) still reads as an enabled button, so the surface looks live and silently swallows taps.

## F36

GpsDeniedState: No max content width: the only horizontal constraint is 24pt of padding a side, so at 740pt (landscape / tablet) the body renders as one ~690pt centred line instead of a readable measure.

