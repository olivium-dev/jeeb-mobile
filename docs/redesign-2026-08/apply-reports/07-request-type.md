# Apply report — 07 · Request type

Lane: `07-request-type` · branch `feat/redesign-24-migration` · 2026-08-03
Status: **partial** — all 10 tasks implemented; the screen cannot compile or be test-verified
until the l10n batch (W-4 + W-4b) is applied by the integrator.

## What shipped

| File | Change |
|---|---|
| `lib/features/request_type/presentation/request_type_screen.dart` | rebuilt shell: `JeebTopBar.back` replaces `OMDSAppBar`; `CustomScrollView` + `SliverFillRemaining(hasScrollBody: false)` + `Spacer()` body; tier rows via `JeebTierRow.compact`; footer via `JeebCtaButton.primary`; screen-local `_bodyPadding` / `_footerPadding`; `_SectionHeading` deleted; `_RequestTierCopy` re-typed to `(title, summary)`; `_tierIcon` → `_tierMark` emoji lexicon |
| `lib/features/request_type/presentation/request_location_row.dart` | rebuilt as the filled `Deliver to` card (surfaceContainerHigh, r16, pin + address block + bare orange `Change`); constructor stays source-compatible and gains `addressLabel` / `qualifierLabel` / `changeCtaLabel`; trailing chevron and the `directional_icons` import removed |
| `lib/features/request_type/presentation/request_tier_card.dart` | **deleted** (superseded by `JeebTierRow.compact`) |
| `test/delivery_create_screens_test.dart` | Task-9 edits, `RequestTypeScreen` group only |
| `test/features/request_type/request_type_deliberate_selection_test.dart` | one-line helper retarget, see W-3 below |
| `docs/redesign-2026-08/wiring/07-request-type.md` | refreshed: W-1/W-2 closed, W-3 superseded, promotion note voided, W-7 added |

Kit widgets consumed (no hand-rolled copies): `JeebTopBar.back`, `JeebTierRow.compact`,
`JeebCtaButton.primary`.

## Frozen inventory — all survived byte-identically

`request_type_flash_radio` · `request_type_express_radio` · `request_type_standard_radio` ·
`request_type_on_the_way_radio` · `request_type_eco_radio` (still emitted through
`requestTypeRadioId(tier.id)`) · `request_type_continue_cta` · `request_type_current_location_label`
· `request_type_change_location_button` · `Key('request-type-continue')` ·
`explicitChildNodes: true` on the location card · the `_onContinue` and `_LocationSection._onChange`
bodies · the `state.status != loaded → SizedBox.shrink()` footer guard.
One new identifier, as authorized: **`request_type_back`**.

## Verification actually performed

`dart analyze lib/features/request_type test/features/request_type test/delivery_create_screens_test.dart`
→ **8 issues, all `undefined_getter`/`undefined_method` on the eight pending l10n keys**
(`tier{Flash,Express,Standard,OnTheWay,Eco}Summary`, `requestTypeMostPickedBadge`,
`requestTypeChangeCta`, `requestTypeTierSummarySemanticLabel`). Zero other errors, zero warnings,
zero lint hits. This is the same pending-l10n class the other migrated lanes carry (e.g.
`lib/features/home_client/presentation` reports 5 of them today).

Because `AppLocalizations` is hand-authored, the screen does not compile until W-4b lands, so the
three named test files **could not be run**. Instead a throwaway probe
(`test/features/request_type/tmp_layout_probe_test.dart`, since deleted) rendered the exact body /
footer structure with literal strings. Results:

* 440×956 viewport — no exception; `Deliver to` card bottom lands at **600 of 956**, i.e. the
  lower **37%** is real emptiness (board says ~39%). `SliverFillRemaining` + `Spacer` compose
  correctly; no intrinsics failure.
* All five `Semantics` identifiers plus `request_type_back` and `request_type_continue_cta`
  surface as their own queryable nodes through the new tree.
* `tester.widget<JeebCtaButton>(find.byKey(const Key('request-type-continue'))).isEnabled` reads
  back correctly.
* RTL (`TextDirection.rtl`) renders with no exception.
* 360×560 at `TextScaler.linear(2.0)`: top bar, `Deliver to` card and CTA are all clean; the
  **badged** `JeebTierRow.compact` overflows horizontally by 64px. Removing the badge makes it
  clean, so the defect is the kit's inflexible `_Badge` in `_CompactBody`'s title Row → filed as
  **W-7**. Not fixable from the feature side (the badge string is passed *into* the kit).

## Deliberate divergences from the render (all pre-approved or newly flagged)

1. **No pre-selection.** The render depicts Flash selected with an enabled navy CTA; the screen
   paints all five rows unchecked with a disabled CTA on first paint (C-07-A; pinned by
   `request_type_deliberate_selection_test.dart`).
2. **Badge sits on Flash, not Standard.** `tier.recommended` is synthesized client-side as Flash
   (`tier_repository.dart:100` and the fake). The code renders from the flag and never hardcodes a
   tier; flipping it is the owner decision already filed (W-6).
3. **Address card is one line.** The board shows `Home — Achrafieh, Beirut` / `Current location`;
   the flow has no resolved destination at this step (it is chosen on the NEXT screen), so
   `addressLabel`/`qualifierLabel` are left null and the card renders `Current Location` alone.
   Marked with a `TODO(redesign-24)` at the call site — omitted, not faked.
4. **Pin is navy, not `#E02020`.** Raw hex is banned in `lib/features`; flagged for the design
   owner in the wiring file.
5. **No `JeebPriceMeter`.** `02-PLAN-ENHANCED.md` lists 07 as a consumer; the 07 HTML/render
   contain zero meter dots (C-07-G). Documented divergence, already in the wiring file.

## Test edit that departs from the instruction set

The instruction set says `request_type_deliberate_selection_test.dart` must pass **unchanged**,
because W-3 asked the kit to compose `OmdsPrimaryButton` internally. The frozen kit paints its own
pill instead and its own doc prescribes `tester.widget<JeebCtaButton>(...)`. One helper
(`:92-93`) was retargeted from `OmdsPrimaryButton` to `JeebCtaButton`; the `Key`, the assertion and
its intent are untouched, and nothing was weakened or deleted. Recorded in the wiring file as
"W-3 SUPERSEDED — do NOT change the kit".

## Not done / handed off

* Run `test/features/request_type/`, `test/delivery_create_screens_test.dart` and
  `test/semantics_identifier_surfacing_test.dart` — blocked on W-4/W-4b.
* On-device check that 🟦 renders acceptably for Standard (plan §9-7) — needs a device; the
  fallback is a shared 07/08 decision, not a unilateral swap.
* W-7 (kit badge overflow), W-6 (badge placement / "Most picked" wording) and the dead
  `selectable_radio_glyph.dart` are owner/kit-lane items, all filed in the wiring file.
