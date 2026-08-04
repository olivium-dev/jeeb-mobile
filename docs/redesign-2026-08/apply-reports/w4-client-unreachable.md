# w4 · client-unreachable — apply report

**Status: done.** No render exists for this screen; the reference was the journey neighbour
`screens/12-live-tracking.png` (+ `.html`) and the already-migrated
`lib/features/live_tracking/presentation/live_tracking_screen.dart`.

## Files

| File | Change |
|---|---|
| `lib/features/client_unreachable/presentation/client_unreachable_screen.dart` | re-skinned onto the kit |
| `lib/features/client_unreachable/presentation/client_unreachable_l10n.dart` | **new** — feature-local EN/AR resolver (the `live_tracking_l10n.dart` precedent) |
| `test/client_unreachable_screen_test.dart` | **new** — 4 tests; the screen had zero coverage |
| `docs/redesign-2026-08/wiring/w4-client-unreachable.md` | **new** — 6 ARB keys requested |

Nothing outside `lib/features/client_unreachable/` was edited. No shared file, no kit file, no
pubspec, no route, no DI.

## What the neighbour does, and what this screen did

12 is a top-aligned column of blocks under an in-body Ø40 back circle + `h2` title: stepper, map
card, a **white outlined** courier card, a **`surfaceContainerHigh` muted** door-code strip, then
~40% real white emptiness, then a docked split footer. One orange moment (the active stepper node
and the courier marker). No red anywhere — the two escalating actions, `Report no-show` and
`Open dispute`, are a brown text button and an outline pill.

client-unreachable was a Material `OMDSAppBar` over a full-bleed `Spacing.medium` (16px) pad, a
`Card` filled `colorScheme.errorContainer` with a centred 40px `colorScheme.error` glyph and
centre-aligned `theme.textTheme` copy, two `OmdsPrimaryButton(variant: outlined)`, a bare `Spacer`,
and a docked `OmdsPrimaryButton` whose `backgroundColor` was `colorScheme.error` — the largest
red fill on any screen in this journey.

## What changed

1. **`OMDSAppBar` → `JeebTopBar.back`** (in-body, pad `14/24/0`, Ø40 `surfaceContainerHigh` circle,
   direction-aware glyph, `h2` title). New id `client_unreachable_back` per the kit's
   `<screen>_back` contract. Same edge behaviour (`Navigator.maybePop`).
2. **`Card(color: errorContainer)` → `JeebInfoNote.error`** — the stacked form (`title` + `text` +
   `Icons.phone_disabled` glyph), r16, kit padding/gap/type. **Same colour role** (`errorContainer`/
   `onErrorContainer`), so this adopts Wave 0's soft `#FFDAD6` tint instead of the legacy slab
   without re-classifying the state. Raw `theme.textTheme.titleMedium`/`bodyMedium` and the manual
   `Sizes.fourXLarge` icon size are gone — the kit owns all three.
3. **`OmdsPrimaryButton` ×3 → `JeebCtaButton`** — `.outline` (h50, 1.5px `colorScheme.outline`,
   13.5/w600 navy) for the two recovery actions, `primary` (h56 navy pill, `jeebText.button`,
   `JeebShadows.ctaNavy`) for the docked edge, wrapped in `JeebCtaFooter.single` (pad `24/0/24/32`).
4. **Layout rhythm** — 24px gutters (`Spacing.xLarge`) replacing the 16px all-round pad; 16px above
   the first block; 20px between the note and the first action, 12px between the two actions. The
   bare `Spacer` became `Expanded(SingleChildScrollView)` so the white space is still real emptiness
   at 1.0x (R1) but 200% text scale cannot overflow — the same construction 12 uses and comments.
5. **Six inlined English strings → `ClientUnreachableL10n`**, EN byte-identical, AR supplied. The
   screen previously rendered English to Arabic users. ARB keys requested in `wiring/`.

## Refusals / deliberate non-changes

- **No orange.** Every board screen carries one accent moment, but this screen's only candidate is
  the "15 minutes to respond" window — and there is no timer in state, no countdown field, nothing
  live. Painting an accent there would imply a running clock the app cannot honour (§7.6 / no
  invented data). Left absent.
- **The red destructive fill is gone, and that is intentional.** The kit has no destructive CTA
  variant, and the board draws this journey's escalating edges (`Report no-show` / `Open dispute`)
  with no red at all. The warning is carried by the error-toned note above it and by the label.
- **Flow untouched.** Same three actions, same order, same copy meaning, same `pop(true)`, same
  inert `onTap: () {}` stubs on the two recovery actions (they were never wired — the devtool
  catalog entry documents this). Nothing added, nothing removed, nothing reordered.
- All four pre-existing `Semantics(identifier:)` values are byte-identical; the test pins them.
- File keeps its `ORPHAN (JEBV4-227)` marker — zero routes reference it; the only importer is
  `lib/devtool/catalog/entries/batch_02_entries.dart`, which still analyzes clean.

## Known remaining inconsistencies vs the board

- The `error`-toned note is the largest coloured area on the screen; nothing on 12 (or on the board)
  is peach. `muted` or `outlined` would sit closer to the design language, but that would
  re-classify a state the re-skin brief says not to touch. Flagged for the owner.
- Two stacked equal-width outline pills is not a shape the board draws — it draws at most one
  outline pill per surface. Collapsing them would remove an affordance, so they stay.
- The two outline pills keep their `Icons.phone` / `Icons.chat` leading glyphs; the board's outline
  pills carry no glyph.
- The screen has no navy surface at all (no hero, no stepper, no map) — it is white + one tint +
  one navy pill. That is honest for its content, but it is quieter than any neighbour.

## Verification

```
dart analyze lib/features/client_unreachable test/client_unreachable_screen_test.dart  → No issues found!
flutter test test/client_unreachable_screen_test.dart                                  → 4 passed
flutter test test/devtool/catalog_network_guard_test.dart                               → 2 passed
flutter test test/decision_violations_test.dart                                         → 4 passed
bash tool/check_design_tokens.sh   → 3 pre-existing violations, none in this lane's files
```
