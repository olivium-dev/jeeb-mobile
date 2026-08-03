# w3 — `cancellation` onto the Jeeb design system

**Screen:** `/orders/:id/cancel` — `lib/features/cancellation/presentation/cancellation_screen.dart`
**Render:** none (one of the 46 screens the board never drew). Reference = neighbour **10
request-summary** (`screens/10-request-summary.png` / `.html`) plus the house conventions in
`order_history`, `wallet_hub`, `mutual_rating` and `prohibited_item_report`.
**Scope:** re-skin only. No flow change, no new step, no removed affordance, no copy meaning change.

---

## 1. What the neighbour does, and what this screen did

| | 10 request-summary (redesigned) | cancellation (before) |
|---|---|---|
| Header | in-body Ø40 tonal back circle + start-aligned 20/w700 navy title | Material `OMDSAppBar` (elevation, `headlineSmall`, no `<screen>_back` id) |
| Gutters | 24px, content starts ~16 under the bar | `Spacing.medium` (16) symmetric |
| Body | one outlined card, 1.5px warm-brown stroke, soft 16–20 radius, generous internal rhythm | flush `OmdsSettingsRow` radio list, no card, no outline |
| Selection | fill swap (navy) + Ø22 accent disc with a white check | leading `radio_button_checked/unchecked` glyph only |
| Type | token ramp throughout | `textTheme.titleMedium` / `titleLarge` |
| CTA | full-width navy pill docked at the foot over an empty lower band | `OmdsPrimaryButton` inside the padded body column |
| Orange | rationed — two `Edit`/`Change` text links only | absent entirely |

## 2. What changed

**`cancellation_screen.dart`**
- `OMDSAppBar` → in-body `JeebTopBar.back(identifier: 'cancellation_back', title: …)`, mounted as
  the first child of the body `Column` with `Scaffold(appBar: null)`. New id follows the frozen
  `<screen>_back` shape; OMDS's back button carried no identifier, so nothing was displaced.
- Body → `Expanded(SingleChildScrollView)` on the 24px gutter
  (`fromSTEB(24, 16, 24, 24)`), with the submit action lifted out into a docked
  `JeebCtaFooter.single` sibling (`docked` = `24/0/24/32`). Same order, same actions.
- Prompt: `textTheme.titleMedium` → `context.jeebText.titleProminent` (17/w700). Deliberately not
  `h2` — the top bar already owns the screen's 20/w700 line — and deliberately not
  `JeebSectionLabel`, which would uppercase a sentence-case question.
- Submit: `OmdsPrimaryButton` → `JeebCtaButton.primary` inside the **unmoved**
  `Semantics(identifier: 'cancellation_submit_cta', container: true, button: true)`.
  The in-flight state keeps the existing label swap (`deliveryActionCancellingLabel`) rather than
  `isLoading:`, because the kit spinner **replaces** the label and that would silently drop shipped
  copy.
- "Other" field: `OmdsTextField` kept (the kit ships no text field) with
  `borderRadius: UIConstants.borderRadiusLarge` so it matches the 16px card radius — the same
  correction screen 18 / prohibited-item made.

**`widgets/cancellation_reason_group.dart`**
- `OmdsSettingsRow` per reason → `JeebOutlinedCard` per reason with
  `state: selected ? JeebCardState.selected : JeebCardState.normal`. That *is* the board's
  single-select language: white + 1.5px brown outline, swapping to a solid navy fill (never a
  thicker border, so rows never jitter). 8px peer gap; the last card carries none.
- The card body is its own widget so it reads the **card's** `JeebSurfaceTone` (navy when selected)
  — label ink is `tone.titleInk`, never a hand-picked colour.
- Label type: `context.jeebText.cardTitle` (15.5/w700), matching the kit's own tier-row title.
- Trailing mark: Ø22 ring → accent disc + white check on select, geometry copied from
  `JeebTierRow`'s indicator (which is private to the kit and takes tier-shaped arguments this
  screen has none of). This is the screen's only orange — rationed, and it is a "do-it-now"
  selection moment.

**`widgets/cancellation_success_sheet.dart`**
- `Icons.check_circle_outline` → `Icons.check_circle` (R10: filled glyphs only).
- Title `textTheme.titleLarge` → `context.jeebText.h2`; CTA → `JeebCtaButton.primary` under the
  unmoved `cancellation_sheet_done_cta` wrapper; padding switched to `EdgeInsetsDirectional`.
  Sheet corner stays 24 (`Spacing.large`) — already the board value.

## 3. Preserved byte-identically
`cancellation_root` · `cancellation_reason_<code>` (with its `container/label/selected/button`
flags) · `cancellation_other_field` · `cancellation_submit_cta` · `cancellation_sheet_done_cta`.
Cubit, repository resolution (`sl<CancellationRepository>()` — P0-CANCEL-CRASH), reason codes and
their order, the `other` → free-text branch, snackbar error/too-late handling, and the success-sheet
navigation (`rootNavigator.pop()` + `context.pop()`) are untouched.

## 4. Not done, on purpose
- **No new strings.** The neighbour docks a muted note under its CTA ("Free to cancel any time…");
  no equivalent ARB key exists here and `lib/l10n/*` is shared + hand-authored, so none was invented.
  No wiring request was filed — the screen reads correctly without it.
- **`CancellationResult.weeklyCount` / `strikeCount` / `restriction` / `retryAfter` stay unrendered**
  (as before). Surfacing them is new product surface + new copy, not a re-skin.
- **`cancellationWalletCta` ("View in Wallet") stays unused**, exactly as it shipped — adding it
  would be a new affordance.
- No pubspec, l10n, router, kit or theme file was touched.

## 5. Gates
- `dart analyze lib/features/cancellation` → **No issues found!**
- `flutter test test/core/router/cancellation_route_resolve_test.dart test/cancellation_cubit_test.dart`
  → **9/9 pass**.
- Throwaway smoke harness (written, run, deleted): client + jeeber reason lists mount, tapping a
  reason selects, `other` reveals the field, `ar` RTL renders all five jeeber reasons, and 200%
  text scale produces no overflow exception.
