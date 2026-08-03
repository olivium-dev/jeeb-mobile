# w4 — `jeeber-onboarding` onto the Jeeb design system

**Scope:** `lib/features/jeeber_onboarding/**` (the wizard host + its six presentation widgets).
**Reference:** no render exists for these screens. Language taken from the nearest neighbour,
`screens/22-become-a-jeeber.{png,html}`, plus `03-WAVE1-KIT.md` and `00-MIGRATION-PLAN.md` §4.6.
**Status:** done. `dart analyze lib/features/jeeber_onboarding` → **No issues found**.
Owned tests green: `dm_onboarding_screen_test`, `dm_onboarding_cubit_test`,
`dio_dm_onboarding_gateway_test`, `semantics_identifier_surfacing_test`, `w2_routes_resolve_test`,
`decision_violations_test`.

---

## What the neighbour does that this flow did not

| Board (22) | Before | After |
| --- | --- | --- |
| Ø40 tonal back circle + start-aligned navy `h2` title, in the body | Material `OMDSAppBar`, **centre**-titled, elevated | `JeebTopBar.back` as the first row of the body `Column`; `Scaffold.appBar` removed |
| "Step 1 of 2" caption over `flex:1` segments, h6/gap 8, orange fill | one 12dp full-width `OMDSStepperProgress` bar, **no visible caption** | `JeebMeter.segmented` + a visible caption from the existing `dmOnboardingStepProgressLabel` |
| Outlined cards, 1.5px warm-brown stroke, r18, no shadow | photo drop area = `Material` + hairline `outlineVariant` + `surfaceContainerLow` | `JeebOutlinedCard(radius: 18, padding: zero)` |
| Navigation rows inside an outlined card | bare `InkWell` `Row` with a `Spacer` | `JeebOutlinedCard` → `JeebListRow` |
| Docked h56 navy pill, 0/24/32 | `OmdsLoadingButton` + an ad-hoc `SizedBox(20)` | `JeebCtaFooter.single` → `JeebCtaButton.primary` |
| Uppercase muted section headers | `titleSmall` + `onSurface` | `JeebSectionLabel` |

## Kit widgets adopted
`JeebTopBar` · `JeebMeter.segmented` · `JeebOutlinedCard` · `JeebListRow` · `JeebSectionLabel` ·
`JeebCtaButton` · `JeebCtaFooter` · `JeebSurfaceTone` (read, for the trailing chevron ink).

## Token work
- Type: every raw `textTheme.*` restyle replaced by `context.jeebText` — `h1` (step headline),
  `bodySmall` (subtitles, field labels, map hint, row value, progress caption).
- Ink: the step subtitle moved off `onSecondaryContainer` (**periwinkle `#777FC0`**, which fails AA
  as body text on white) onto `onSurfaceVariant` — the board's warm subtitle ink.
- Orange: the map pin moved from `colorScheme.tertiary` to **`context.jeebRoles.accent`**, the only
  sanctioned accent token; it is the single orange paint on the step. The select-location row's
  leading glyph gave up its orange and takes `JeebListRow`'s navy default, so the accent stays
  rationed to the pin and the progress fill.
- Shape: map placeholder r12 → `OmdsBorderRadius.medium` (16); photo card r20 → 18 (`tpl 1308`).
- Rhythm: 24px gutters kept, content top gap `Spacing.large`, address rows 12 → 16.

## Refusals / things deliberately NOT done
- **D20** honoured — no "Vehicle number" string was introduced anywhere (the field was already
  removed under JM-037; `decision_violations_test` re-run green).
- **No new l10n keys.** The board's progress row carries an end-side "then Selfie" hint and a
  per-step name; both need copy this app does not have, and this repo has no gen-l10n. Rendered
  from what exists (`dmOnboardingStepProgressLabel`) instead of inventing strings.
- **No `JeebInfoNote` reassurance strip** ("Review usually takes under 24 hours…"). It is new copy
  and a new claim about backend timing — not this lane's to assert.
- **No flow change.** Same three steps, same order, same CTA semantics, same navigation, same
  gateway calls. The photo step keeps its 4:5 drop area rather than becoming the board's compact
  document rows — that would be a product redesign of the step, not a re-skin.
- **Progress fill left alone.** `DmOnboardingState.completedSteps` is `step.index`, so the first
  step shows an empty bar where the board fills the current segment. Changing it is a state/meaning
  change, not styling.

## Semantics
Every existing identifier is byte-identical and still surfaces as its own node:
`dm_onboarding_back` (now carried by `JeebTopBar.identifier`, which lands on the leading circle —
the kit's documented `<screen>_back` contract), `dm_onboarding_progress`, `dm_onboarding_continue`,
`dm_onboarding_photo_upload_area`, `dm_onboarding_address_root`, the four
`dm_onboarding_address_*_field` ids, `dm_onboarding_service_area_root`, `service_area_map_pin`,
`service_area_select_location`, `dm_onboarding_location_value`. No new identifiers were added — no
new interactive element exists. Two newly-visible strings (`Step n of N`, the photo hint) are
`ExcludeSemantics`'d because the enclosing node already announces them.

## Files changed
- `presentation/dm_onboarding_screen.dart`
- `presentation/widgets/dm_onboarding_progress_header.dart`
- `presentation/widgets/dm_onboarding_step_layout.dart`
- `presentation/widgets/dm_onboarding_step_header.dart`
- `presentation/widgets/dm_onboarding_photo_upload_card.dart`
- `presentation/widgets/dm_onboarding_address_field.dart`
- `presentation/widgets/dm_onboarding_address_step.dart`
- `presentation/widgets/dm_onboarding_service_area_step.dart`

No shared file was touched, so no `wiring/w4-*.md` request was filed.

## Remaining inconsistencies vs the neighbour
1. Progress bar reads empty on step 1 (see refusal above).
2. No "then \<next step\>" end hint and no per-step name in the caption — blocked on new copy.
3. No reassurance `JeebInfoNote` — blocked on new copy.
4. Address-step inputs are still `OmdsValidatedTextField`: filled grey rounded rects, whereas the
   board's fields are outlined. OMDS-owned; nothing is added to OMDS in this migration.
5. The photo drop area is a tall 4:5 block; the board's capture affordances are compact 64×44
   thumbnail rows with a per-item state line ("Captured · looks sharp").
6. The map placeholder is still a flat `surfaceContainerHighest` slab, not an outlined card — it
   stands in for a real map raster, which the board draws full-bleed.
7. `JeebSectionLabel` uppercases "YOUR PRIMARY LOCATION" in EN; it is the only uppercase run on the
   screen (kit-correct, locale-gated, but visually singular here).
