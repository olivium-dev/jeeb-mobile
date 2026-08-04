# 08 · Tier catalog — apply report

Lane: `08-tier-catalog` · branch `feat/redesign-24-migration` · 2026-08-03
Status: **partial** — the catalog is fully implemented and layout-verified, but the screen cannot
compile (so no lane test can run) until the pending `tierCatalog*` l10n batch is applied. Same
blocking class lane 07 reported.

> Supersedes the earlier BLOCKED-ON-WAVE-1 report on this file: the Wave-1 kit has since landed
> (31 files in `lib/core/widgets/jeeb/`), and the file path was corrected.

## Path correction actually taken

The per-screen instruction set (`per-screen-revised/08-tier-catalog.md`) rebuilds
`tier_selection/presentation/tier_selection_screen.dart` behind a NEW `/tier-catalog` route. That is
**superseded** by the 🛑 STOP block (`00-MIGRATION-PLAN.md:22`), `screen-repo-map.md:15,29-31` and
the lane prompt: `tier_selection_screen.dart` is dead code (devtool-only importer) and the live tier
picker is a **section of `/request-type`**. So:

* `tier_selection_screen.dart` — **not touched**; no `/tier-catalog` route; `/tier-selection` not
  resurrected. The route wiring request in the previous version of the wiring file is explicitly
  **withdrawn** there.
* Screen 08 landed as the picker section of `/request-type`, on top of lane 07's shell.

That reading decides the whole lane. `02-PLAN-ENHANCED.md:24` scopes 08 as "dollar figures →
relative price meter, every tier gains an SLA chip and a vehicle line, **and selection is a navy
fill — not a radio**", explicitly against "the live picker inside `request_type_screen.dart`". The
tier rows therefore move from `JeebTierRow.compact` (07) to `JeebTierRow.catalog` (08); everything
else lane 07 built — top bar, `Deliver to` card, docked `Continue`, every frozen identifier — is
kept as-is. The section is not a second tier list: there is exactly one.

## What shipped

| File | Change |
|---|---|
| `lib/features/request_type/presentation/widgets/tier_catalog_lexicon.dart` | **new.** Per-`TierId` display lexicon — emoji + `priceLevel` (4/3/2/2/1) — plus localized resolvers for name, price caption, meta line, vehicle glyph, and the SLA band rendered from `Tier.slaMinutes` (`null` → `Flexible`). |
| `lib/features/request_type/presentation/widgets/tier_catalog_section.dart` | **new.** The catalog section: periwinkle subtitle, five `JeebTierRow.catalog` rows (8px gaps), then `JeebInfoNote.muted` carrying the "Jeebers set the price" note. |
| `lib/features/request_type/presentation/request_type_screen.dart` | `_TierList` / `_TierEntry` / `_RequestTierCopy` and the local emoji lexicon deleted; body hosts `TierCatalogSection`; body top inset 20 → 12 (board's 14 between the top bar and the subtitle); class doc records that 08 lives here; the `jeeb_tier_row` / `request_type_radio_id` imports moved to the section. |
| `test/features/request_type/tier_catalog_section_test.dart` | **new**, 6 cases. |
| `test/features/request_type/request_type_deliberate_selection_test.dart` | 3 flag reads `isChecked`/`CheckedState` → `isSelected`/`Tristate`; ids, keys, intent and every other assertion unchanged. |
| `test/delivery_create_screens_test.dart` | the same two flag reads, `RequestTypeScreen` group only. |
| `docs/redesign-2026-08/wiring/08-tier-catalog.md` | rewritten for the corrected path: route request withdrawn, l10n trimmed to the 14 keys actually called (+ proposed AR + getters), one new kit request. |

Kit widgets consumed, no hand-rolled copies: `JeebTierRow.catalog`, `JeebPriceMeter` (through the
row), `JeebInfoNote.muted`. Untouched from 07: `JeebTopBar.back`, `JeebCtaButton.primary`.

## Frozen inventory — all survived byte-identically

`request_type_flash_radio` · `request_type_express_radio` · `request_type_standard_radio` ·
`request_type_on_the_way_radio` · `request_type_eco_radio` (still emitted through
`requestTypeRadioId(tier.id)`) · `request_type_continue_cta` · `request_type_back` ·
`request_type_current_location_label` · `request_type_change_location_button` ·
`Key('request-type-continue')`. `.maestro/flows/jm-024-create-flow.yaml` asserts only these ids —
unaffected. **No new identifier was added**: the catalog introduces no new interactive element (the
note is static, the meter dots are `ExcludeSemantics`'d by the kit).

## The one contract that changed, and why

`JeebTierRow.catalog`'s a11y node is `container + button + selected`, where `.compact`'s is
`inMutuallyExclusiveGroup + checked` — the kit documents the two contracts as deliberately different
(`jeeb_tier_row.dart:36-42`). Swapping the variant flips the flag two selection tests read. Both
were updated to `flagsCollection.isSelected` / `Tristate`; the intent each pins (nothing
pre-selected on first paint, the tap is deliberate, the choice survives a back-return, Continue
disabled until then) is asserted exactly as before. Nothing deleted, nothing weakened. If the owner
prefers radio semantics on this picker, the fix belongs in the kit's `.catalog` node, not here.

## Verification actually performed

* `dart analyze lib/features/request_type test/features/request_type test/delivery_create_screens_test.dart`
  → **16 issues, every one `undefined_getter`/`undefined_method` on pending l10n keys** (14 new
  `tierCatalog*` plus 07's still-pending `requestTypeMostPickedBadge`, `requestTypeChangeCta`).
  Zero other errors, zero warnings, zero lint hits. Fewer pending keys than 07 left behind: the
  catalog no longer consumes the five `tier*Summary` keys or `requestTypeTierSummarySemanticLabel`.
* `bash tool/check_design_tokens.sh` → 6 violations, **none in `request_type`** (settlement ×3,
  location, wallet, reviews — pre-existing / other lanes).
* `AppLocalizations` is hand-authored, so the screen does not compile and the three lane test files
  **could not be run**. Two throwaway probes (since deleted) reproduced the exact section tree with
  literal strings:
  * **440×956** — no exception. Note bottom **680**, `Deliver to` card bottom **810 of 956**: the
    tail ~15% stays real emptiness (07 measured 37% with one-line rows; catalog rows are two lines
    and the note is new). Tapping re-tones the row and the trailing check appears. RTL clean.
  * **Width probe** — section, rows and note all span 24→416 inside the 24px gutters under the
    `CrossAxisAlignment.start` parent (no intrinsic-width shrink).
  * **360×640 @ `TextScaler.linear(2.0)`** — 5 horizontal overflows inside `jeeb_tier_row.dart:374`
    (the meter caption starves the name row by 30px; the badge adds ~9px). Kit-internal, same class
    as 07's W-7; filed as this lane's cross-feature request. The feature only passes strings in.

## Deliberate divergences from the render

1. **No pre-selection.** The board draws Standard selected with an enabled CTA; the screen paints
   all five unselected with the CTA disabled (C-07-A, pinned by the deliberate-selection test and
   the cubit invariant).
2. **The badge sits on Flash and reads `Most picked`.** The code renders `tier.recommended` (data
   flags Flash, `tier_repository.dart:100`) and keeps lane 07's badge key rather than reverting a
   shipped decision. Both are owner questions in the wiring file.
3. **SLA chips come from data, not the board.** Express reads `≤ 3 hr` (`slaMinutes: 180`) where the
   board draws `≤ 2 hr`; Eco reads `≤ 48 hr` (`2880`) where the board draws `Today`. Rendering the
   literals would have faked the catalog.
4. **Vehicle glyph on all five rows** (C7); the board draws it on Flash alone.
5. **No `Delivery tiers` title and no `Confirm tier` CTA.** Inside `/request-type` the chrome is
   07's: the top bar says `Choose your request` and the docked CTA is `Continue` — the same gesture,
   one frozen identifier.
6. **Subtitle is 13.5/w500** (`jeebText.body` + `mutedText`), not the board's 14.5 — R3 forbids
   inventing an off-ramp size.

## Not done / handed off

* Run `test/features/request_type/` and `test/delivery_create_screens_test.dart` — blocked on the
  l10n batch.
* Kit request: `JeebTierRow.catalog` horizontal overflow at 2.0 text scale (meter + badge).
* Owner: badge tier and wording; whether this picker should keep radio semantics.
