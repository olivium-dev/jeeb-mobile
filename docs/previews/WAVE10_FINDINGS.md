# Wave 10 (jeeber_onboarding) — defects surfaced by the previews

8/8 written, 43 previews. Includes a DATA-correctness defect, not just layout:
every home base is recorded at (0, 0). Recorded, not fixed.

## F01

DmOnboardingProgressHeader: RTL: the progress FILL does not mirror. OMDSStepperProgress's _StepperPainter draws from Offset(0, h/2) to Offset(width * progress, h/2) on a raw Canvas (omds_library/lib/src/indicators/omds_stepper_progress.dart:154-167), and Flutter does not flip canvas coordinates for text direction. Pinned by test: in locale 'ar' the fill line is from.dx == 0, to.dx == 114.0 on a 342 pt track — byte-identical to English. Because the header's EdgeInsetsDirectional padding DOES mirror (asserted as the control: the track rect is identical in both locales), everything around the bar flips and only the fill does not, so an Arabic Jeeber sees the bar appear to EMPTY as they advance through the wizard.

## F02

DmOnboardingProgressHeader: Step 1 of 3 renders a completely empty bar. DmOnboardingState.completedSteps is step.index, which is 0 on the photo step, so _StepperPainter takes its `if (progress > 0)` early-out and paints nothing but the track (asserted via paintsExactlyCountTimes(#drawLine, 1)). This contradicts the doc comment on DmOnboardingStep in dm_onboarding_state.dart:5-7, which states 'The progress bar fills `index + 1 / values.length`' — that would be a third of the bar. The state implementation wins; the entry state a Jeeber sees first announces 'Step 1 of 3' over a bar with zero progress.

## F03

DmOnboardingProgressHeader: The full-bar branch is dead code today. DmOnboardingProgressHeader.buildWhen watches prev.isSubmitted != curr.isSubmitted and completedSteps short-circuits to totalSteps when isSubmitted is true, but nothing in DmOnboardingCubit ever emits isSubmitted: true — the service-area step sets coverageReady and hands off to the KYC wizard instead (dm_onboarding_cubit.dart:83-97). A grep across lib/ finds isSubmitted referenced for DM onboarding only in the state class and the header's buildWhen. The bar therefore tops out at 2/3 and never reaches 100% in the shipping app.

## F04

DmOnboardingServiceAreaStep: `_SelectLocationRowBody` (dm_onboarding_service_area_step.dart:232) puts the chosen-place value in a bare `Text` inside a `Row` — no Flexible/Expanded, no maxLines, no ellipsis — so it overflows instead of truncating. Measured with production Inter: a 47-char geocoded label is 105 pt over at 390 pt, and the ordinary 25-char seam address 'Sassine Square, Ashrafieh' is already 17 pt over at 320 pt (iPhone SE / small Android), pushing the disclosure chevron off the trailing edge. At 200% text the same ordinary address is 181 pt over at 390 pt.

## F05

DmOnboardingServiceAreaStep: `_HomeBaseMapPin` pins the map placeholder to a hard `Sizes.elevenXLarge` (100 pt) box under a `ClipRRect` while its contents (40 pt icon + 8 pt gap + wrapping caption) scale with text size. At 200% text the column overflows by 28 pt in EN and 68 pt in AR, clipping 'Tap Location to set your home base' — the only string on the step that tells the user how to satisfy the Continue gate.

## F06

DmOnboardingServiceAreaStep: The disabled Continue declares no disabled state to assistive tech. `_ContinueButton` passes `isEnabled: false` only to `OmdsLoadingButton` (which spends it on a 60%-alpha fill) and wraps the CTA in `Semantics(identifier: 'dm_onboarding_continue', button: true)` that never sets `enabled:`. The rendered node has `flags: [isButton]` with no `hasEnabledState` in either the gated or the ungated state, so a screen reader announces a plain 'Continue, button' that silently does nothing, and no copy anywhere on the step says a location is required. The gate is a colour.

## F07

DmOnboardingServiceAreaStep: Every home base recorded today is labelled with the literal field label. `_pickHomeBase` records `DmOnboardingHomeBase(lat: 0, lng: 0, label: l10n.dmOnboardingServiceAreaLocationFieldLabel)` on BOTH branches — after `capture-location` pops and in the no-router fallback — so the shipped state renders 'Location … Location' on the selector row plus 'Location' under the pin (three identical strings; 'الموقع' three times in Arabic), and the submitted coordinates are (0, 0) in the Gulf of Guinea. Side effect: the layout only passes 200% text because that stub label is one short word.

## F08

DmOnboardingServiceAreaStep: The step has no error surface of its own. When the coverage probe throws, `DmOnboardingError.submitFailed` is emitted but the only listener is `DmOnboardingScreen`'s SnackBar, so the step's failed frame is indistinguishable from its success frame (spinner gone, Continue live, nothing said). Lifting this step into any other host silently loses its only failure feedback.

## F09

DmOnboardingServiceAreaStep: The step stays fully interactive during the coverage probe: the map pin and the 'Select location' row keep their tap targets while `isSubmitting` is true, so a Jeeber can re-pin the home base while the check for the previous base is still in flight, and the result will be applied to a base that is no longer shown.

## F10

DmOnboardingStepHeader: Subtitle fails WCAG AA in the light theme: DmOnboardingStepHeader paints it with `theme.colorScheme.onSecondaryContainer` (the periwinkle #777FC0) on the white `surface` = 3.76:1, under the 4.5:1 floor for `titleSmall` (14px/w500). This is not a new judgement call — `test/core/theme/color_role_contrast_test.dart` already carries a guard named 'the OLD periwinkle-on-white pairing was genuinely failing', which exists because every other label role was migrated off this exact pairing to `onSurfaceVariant` (#5C4038, 9.35:1). This widget is a surviving caller of the pattern that migration removed. Dark theme is unaffected. Fix is one word: `onSecondaryContainer` -> `onSurfaceVariant` in dm_onboarding_step_header.dart:34.

## F11

DmOnboardingStepHeader: The step header is not a heading to assistive tech. The class is named StepHeader and paints a `headlineSmall` extra-bold navy title, but neither Text sets `header: true` and no ancestor adds it — `getSemanticsData().flagsCollection.isHeader` is false. TalkBack/VoiceOver heading navigation therefore skips the only element on the onboarding step that names the step.

## F12

DmOnboardingStepHeader: The title/subtitle gap is a raw logical 4 (`Spacing.twoXSmall`) and does not follow the text scaler. Measured identical (4.0) at 1.0 and at 2.0, so at the 200% accessibility ceiling a 48px headline and a 28px subtitle still sit 4pt apart and read as one clump.

## F13

DmOnboardingStepHeader: At the 200% text scale the header alone consumes more than the step's whole scrollable area. Measured at 390pt: 148pt -> 620pt (4.2x, super-linear, because both lines scale and both then wrap further); on the 320pt compact device with the KYC selfie copy, 168pt -> 660pt. `DmOnboardingStepLayout` leaves roughly 650pt above its pinned Continue button on a 390x844 phone, so at 200% the user scrolls past the header before seeing any of the step's own content. It scrolls rather than overflowing, so this is ergonomics, not breakage — but neither Text sets `maxLines`/`overflow`, so a future caller who hosts this in a bounded box gets an overflow stripe instead.

## F14

DmOnboardingStepHeader: `subtitle` is `required` with no empty-string branch, so a step with no supporting line (or an ARB value a translator left blank) still gets the 4pt SizedBox, a full empty line box, and an empty node in the semantics tree. Minor, but the fix (`if (subtitle.isEmpty)`) is smaller than the defect.

## F15

DmOnboardingPhotoUploadCard: BoxFit.cover with no alignment discards over half a landscape capture: `Image.memory(photo.bytes, fit: BoxFit.cover)` passes no `alignment`, so a 16:9 source covering the 4:5 card is scaled to the HEIGHT and painted 760pt wide inside a 342pt card — 55% of the frame gone, 27.5% off each side, centred (measured in the test from the decoded fixture and the measured box). For a step captioned "Upload a clear photo for you", a Jeeber standing off-centre in a sideways shot is cropped out of their own identity photo, with no crop UI in the step and nothing on the card indicating anything was removed.

## F16

DmOnboardingPhotoUploadCard: Nothing gates the resolution of an accepted capture: `PhotoCompressor` has a 2 MB BYTE ceiling and no pixel floor, so a 24×30 gallery thumbnail is accepted and upscaled ~14× into the 342pt card (measured: box.width / source.width > 10). The card renders it as the normal filled state — no resolution warning, no retake — and the card is the only place a Jeeber could notice before the reviewer on the far end gets the same 24×30 of detail.

## F17

DmOnboardingPhotoUploadCard: The empty drop area has no perceivable boundary in EITHER theme, and light is the worse one. Measured on the real schemes: `outlineVariant` vs the page is 1.29:1 in light and 1.98:1 in dark, and the `surfaceContainerLow` fill vs the page is 1.06:1 / 1.08:1 — all far below the 3:1 WCAG 1.4.11 asks of a component boundary. The default EN light rendering is the weakest, which inverts the usual habit of only scrutinising the dark rendering. The entire "this is tappable, put a photo here" affordance therefore rests on the 32pt plus icon.

## F18

DmOnboardingPhotoUploadCard: That plus icon opts out of the 200% text ceiling: `Icons.add` is pinned to `Sizes.twoXLarge` and measures exactly 32.0×32.0 at BOTH 1× and 2× text scale (measured via `platformDispatcher.textScaleFactorTestValue`). At the accessibility ceiling the previews already assert, the only visual cue in the empty state stays 32pt inside a 342×427.5 card while every label around it doubles.

## F19

DmOnboardingPhotoUploadCard: The Semantics label never reads the state: `label: l10n.dmOnboardingPhotoUploadHint` is fixed at build time, so after a photo is chosen the card still announces "Tap to add a photo" (asserted), and the `Image.memory` carries no semantics of its own — there is no second announcement to correct it. A screen-reader user gets no confirmation the photo was accepted and no way to tell the box is no longer empty. (Localization itself is fine: AR resolves to "اضغط لإضافة صورة", nothing is hardcoded English.)

## F20

DmOnboardingPhotoUploadCard: A height-bounded host silently collapses the drop area: today's step puts the card in a `SingleChildScrollView` so the height is unbounded, but bound it (landscape viewport, an `Expanded` without a scroll view, a future confirm-your-photo sheet) and `AspectRatio` resolves from the height instead — 144×180, 42% of the 342pt content column, sitting hard against the leading edge because the step's column is `CrossAxisAlignment.start`. The ratio is defended and the purpose is lost; there is no overflow stripe and no exception to notice it by.

## F21

DmOnboardingPhotoUploadCard: `Image.memory` has no `errorBuilder`, and the cubit's default compressor can hand it undecodable bytes. `DmOnboardingCubit` defaults to `HalvingPhotoCompressor`, whose own doc comment in `lib/features/photo_attachment/domain/photo_compressor.dart` states it "does not re-encode, it STRIDE-COPIES every second byte, which turns a >2 MB JPEG into an undecodable blob" — chat already switched away to `PassthroughPhotoCompressor` for exactly this reason, DM onboarding did not. A real >2 MB camera capture therefore reaches this card as garbage and the card has no fallback to the drop area or a retake. Flagged from the code path, NOT from a preview: an undecodable `Image.memory` resolves outside the fake-async zone, so a preview of it would make the render assertion non-deterministic. This is what forced the previews to ship real decodable PNG fixtures instead of the repeated-byte payloads the widget tests use.

## F22

DmOnboardingPhotoStep: a11y: DmOnboardingPhotoUploadCard builds its Semantics(label: dmOnboardingPhotoUploadHint) OUTSIDE the BlocBuilder that swaps '+' for the image, so the drop-area still announces 'Tap to add a photo' after a photo is on file — a screen-reader user is never told the required step is satisfied (pinned by the test 'the drop-area still says "Tap to add a photo" once filled').

## F23

DmOnboardingPhotoStep: a11y: the blocked Continue declares no enabled state at all — the CTA's semantics node has isEnabled == Tristate.none because OmdsLoadingButton just drops the GestureDetector callback and the wrapping Semantics(button: true) never sets enabled:false. Assistive tech announces an ordinary button; the only cue is a 60%-alpha fill, and no copy anywhere in the step says a photo is required.

## F24

DmOnboardingPhotoStep: contrast (WCAG 1.4.11): the drop-area — the single biggest tap target on the screen — is delimited by outlineVariant on surface at 1.29:1 light / 1.98:1 dark, against the 3:1 asked of a control boundary, with a surfaceContainerLow fill only 1.06:1 from the page. Only the '+' glyph (8.9:1) actually marks the card.

## F25

DmOnboardingPhotoStep: contrast (WCAG AA): DmOnboardingStepHeader inks the subtitle with colorScheme.onSecondaryContainer (light indigo) on the white scaffold = 3.76:1, under 4.5:1 for 14pt titleSmall text. Light mode only — dark measures 14.29:1 — so the EN light rendering of every preview shows it.

## F26

DmOnboardingPhotoStep: The filled card renders Image.memory(fit: BoxFit.cover) inside a fixed 4:5 AspectRatio with no crop/rotate/zoom control, so a landscape capture loses its edges (the 3:1 fixture keeps roughly the middle third); the only recovery is to reshoot, and tapping the image silently reopens the source sheet with no 'replace/remove' affordance.

## F27

DmOnboardingPhotoStep: DmOnboardingError.photoPickFailed leaves NO trace on this step: the state renders pixel-identically to empty, because the only surface is the host screen's one-shot SnackBar (JEBV4-13 P1-5) which is acknowledged immediately. After a denied permission the user is back at an unexplained '+' with no inline retry.

## F28

DmOnboardingPhotoStep: Minor/ceiling: OmdsLoadingButton is a fixed 48pt box that does not scale with text. At the 200% ceiling the 'Continue' label is 40 of those 48pt (EN) — it clears today's copy with 8pt to spare, but any longer localized label or a taller scale clips inside the button.

## F29

DmOnboardingAddressStep: Typed text is write-only and never comes back. DmOnboardingAddressField builds OmdsValidatedTextField with a placeholder + onChanged and NO controller (lib/features/jeeber_onboarding/presentation/widgets/dm_onboarding_address_field.dart:46), so the value goes into DmOnboardingCubit and nothing ever restores it. Address → Continue → service-area → Back (the app bar's back button steps the wizard back through the cubit, dm_onboarding_screen.dart:225) re-mounts the step with four EMPTY boxes over a cubit that still holds the address. Two consequences: the jeeber sees lost work, and DmOnboardingSubmission is built from cubit state, so any field they do not re-type is submitted with its old value. Pinned by the test 'a draft in the cubit never reaches the fields'.

## F30

DmOnboardingAddressStep: The placeholder is twice the size of its own label and is truncated at 1.0 text scale. OmdsValidatedTextField defaults input+hint to headlineLarge w700 (32 pt bold) while DmOnboardingAddressField renders the label above it in bodyLarge (16 pt) — the example is shouted, the field name whispered. At 390 pt wide the hint gets a 302 pt single-line box; measured under flutter test, 'Jasmine Tower, Apartment 12B' asks for 896 pt and 'برج الياسمين، شقة 12B' for 672 pt. The test font is ~1.5x wider per glyph than Inter, so those are upper bounds, but the truncation survives the correction and happens before the 200% rendering is reached.

## F31

DmOnboardingAddressStep: Continue is never gated on this step. DmOnboardingAddressStep passes no `enabled` to DmOnboardingStepLayout, so the CTA is fully tappable with all four fields empty and next() advances the wizard — the address reaches DmOnboardingSubmission as four empty strings. Every other step in this wizard gates itself (photo, home base). Pinned by 'Continue is tappable with an entirely empty address'.

## F32

DmOnboardingAddressStep: The service-area coverage-probe spinner leaks onto this step's Continue. isSubmitting lives on the shared wizard state and _OnboardingBackButton._onBack is not gated on it, so pressing Back while the probe is in flight renders THIS step with a spinning, disabled CTA it is not responsible for and no explanation — and when the probe resolves the wizard jumps to KYC from under the jeeber. Pinned by the 'Coverage probe in flight' group.

## F33

DmOnboardingAddressStep: Shipped English hints read as untranslated Figma sample data. app_en.arb has dmOnboardingAddressCountryHint = 'Daraya' (a town, not a country — it is the AR sample value left in the EN file), dmOnboardingAddressStateHint = 'Iklim el kharoub' (transliterated Arabic, inconsistent casing) and dmOnboardingAddressStreetHint = 'main street' (lowercase, unlike every other hint). Only the Address hint reads like English product copy. Visible in every EN rendering of these previews.

## F34

DmOnboardingAddressField: Longest SHIPPED hint is truncated on a normal phone, at 100% text. OmdsValidatedTextField styles the placeholder headlineLarge/w700 (32sp) while DmOnboardingAddressField styles its own label bodyLarge (16sp) — the placeholder is twice the size of the thing naming it. Measured on a 390pt canvas reproducing DmOnboardingAddressStep's Spacing.xLarge gutters: the field is 342pt wide and leaves 302pt of text box, room for ~17 Latin characters. `dmOnboardingAddressAddressHint` = 'Jasmine Tower, Apartment 12B' is 28, so it renders 'Jasmine Tower, Ap…' (InputDecorator hint is maxLines:1 + TextOverflow.ellipsis). Arabic ('برج الياسمين، شقة 12B') truncates the same way. The example copy the ARB entry exists to give the jeeber is never readable — worse at 200% text.

## F35

DmOnboardingAddressField: a11y: the focusable input node is labelled with the HINT, not the label. Dumping the semantics tree for one field yields FOUR nodes: a static text node 'Address'; a wrapper node (flags isTextField, identifier 'dm_onboarding_address_field', label 'Address') from the widget's own Semantics(); and inside it the real input node (isTextField, focus/tap actions) whose label is 'Jasmine Tower, Apartment 12B'. So (a) isTextField is announced on two nested nodes, (b) a screen-reader user who focuses the input hears the example address instead of 'Address', and (c) the identifier integration drivers target sits on the non-focusable wrapper. Semantics() here has no `container`/MergeSemantics and no `excludeSemantics`, so nothing merges.

## F36

DmOnboardingAddressField: The field is write-only — no seam to display a stored value. DmOnboardingAddressField passes neither `controller` nor `initialValue` to OmdsValidatedTextField, so the internal TextEditingController always starts empty. DmOnboardingCubit keeps setStateField/setCountry/setStreet/setAddress values, but nothing can put them back on screen: leaving the address step and returning re-mounts four blank fields over non-empty cubit state. (This is also why no filled-state preview exists — adding the seam would be a production change.)

## F37

DmOnboardingAddressField: Dead validation affordance: `validations` is never passed either, so OmdsValidatedTextField's _validateInput can never set _errorText. The error border/errorText branch is unreachable for all four address fields — the address step has no field-level validation at all, only whatever the Continue button gates on.

## F38

DmOnboardingStepLayout: A11Y (this widget): `_ContinueButton` builds `Semantics(identifier:, button: true)` and never passes `enabled:`. Measured on the gated preview the node is `flags: isButton, label: "Continue"` with no tap action and NO `hasEnabledState` — so a disabled Continue is announced by TalkBack/VoiceOver as an ordinary tappable button and the tap silently does nothing. Visually the gate is also only a 60%-alpha fill (same label, same 342x48 box, no border change), so the disabled state has exactly one affordance and it is contrast-only. lib/features/jeeber_onboarding/presentation/widgets/dm_onboarding_step_layout.dart:79-88.

## F39

DmOnboardingStepLayout: A11Y (this widget): while `isSubmitting`, OmdsLoadingButton replaces the label with a spinner, so the semantics node becomes `flags: isButton, identifier: dm_onboarding_continue, role: loadingSpinner` — the LABEL is gone entirely and nothing announces the transition (no live region, no 'Submitting…'). Measured: 0 'Continue' text matches, 1 CircularProgressIndicator. A screen-reader user focused on the CTA hears its name disappear with no reason given.

## F40

DmOnboardingStepLayout: TEXT-SCALE CEILING (this widget): the CTA height is hard-pinned at 48 px (`Sizes.fourXLarge`) and never grows with the text scaler. Measured EN label height: 20 px @1.0x, 40 px @2.0x, exactly 48 px @2.5x, and 342x48 (the button's whole box) @3.2x. From 3.2x up the label's render box stays pinned at 342x48 while glyphs grow, so 'Continue' is silently clipped — no ellipsis, no overflow stripe, no exception. 2.0x (what the preview matrix renders) is the last honest scale.

## F41

DmOnboardingStepLayout: PRODUCTION OVERFLOW (sibling widget, exposed by the service-area body fixture and then verified against the real widget): at 200% text `DmOnboardingServiceAreaStep`'s `_HomeBaseMapContent` Column overflows its fixed 100 px (`Sizes.elevenXLarge`) map box by 148 px in BOTH en and ar, because the placeholder line 'Tap Location to set your home base' wraps. The same pump also raises a second overflow — `_SelectLocationRowBody`'s Row by 103 px on the right (dm_onboarding_service_area_step.dart:232). Only the empty/unpinned state overflows; a short pinned label ('Beirut') fits.

## F42

DmOnboardingStepLayout: MINOR (this widget): `_ScrollableContent` pads `top` only, so a body scrolled to its end sits flush against the CTA — no bottom gutter, no fade, no affordance that content continued. Most visible on the address form, which is 672 px against a 776 px viewport at 200% text before the keyboard takes any of it.

