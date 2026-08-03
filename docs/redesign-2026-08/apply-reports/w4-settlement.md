# Apply report — w4 · Settlement

Files: `lib/features/settlement/presentation/settlement_screen.dart`,
`lib/features/settlement/presentation/settlement_detail_screen.dart`,
**new** `lib/features/settlement/presentation/widgets/settlement_status_pill.dart`.

There is no board render for these two screens. The reference used throughout is the neighbour
**19 · Earnings** (`screens/19-earnings.png` + `lib/features/earnings/presentation/earnings_dashboard_screen.dart`),
which is the redesigned surface these sit next to in the jeeber's money journey.

## What the neighbour does, and what these screens did

| 19 · Earnings (redesigned) | Settlement before |
|---|---|
| In-body header on a 24px gutter, no Material app bar | `OMDSAppBar` with `showBackButton` |
| Navy hero r20 + `heroNavy` shadow + Ø160 `accentRing` arc; eyebrow (periwinkle, tracked) over a 38px `statHero` amount | white `Card`, `labelMedium` caption over a `headlineSmall` amount |
| Grey `surfaceContainerHigh` r16 rows built from `JeebListRow` | bare `Padding` + `Row`, four stock `textTheme` roles |
| Section header via `JeebSectionLabel` | `titleMedium` `Text` |
| Every amount through `MoneyFormat` (LTR-isolated `$127.50`) | `'${currency} ${toStringAsFixed(2)}'` → `USD 90.00`, bidi-unsafe in `ar` |
| 16px gutters → 24px; list ends and the residual space stays white | `Spacing.medium` (16) gutters; empty state vertically centred |
| Pills are stadium-shaped | status chip was an 8px rect |

## What changed

**Kit widgets in.** `JeebTopBar.back` (both screens, replacing `OMDSAppBar`), `JeebOutlinedCard`
(statement rows), `JeebNavySurfaceCard` + `JeebNavyRing.statTopEnd` + `JeebShadows.heroNavy` (the
payout hero), `JeebSectionLabel` (breakdown header), `JeebListRow` (delivery lines).

**Tokens in.** `context.jeebText.titleProminent` (statement/week lines — the ramp names this use
verbatim), `.price` (statement payout), `.statHero` (hero amount), `.cardTitle` / `.caption` /
`.sectionLabel` / `.label`, `scheme.primary` / `onPrimary` / `surfaceContainerHigh`,
`JeebSemanticColors.mutedText`, `OmdsBorderRadius.medium`, `StadiumBorder` for the status pill.
`BorderRadius.circular(8|12)` and the last raw `TextStyle` lookups are gone; `Spacing.xLarge`
gutters and `EdgeInsetsDirectional` throughout.

**Money.** Both screens now format through `MoneyFormat.format` — the fleet's single formatter and
the only bidi-safe one. Same numbers, `$90.00` instead of `USD 90.00`.

**De-duplication.** Both screens hand-rolled the *same* paid/pending chip with the same
`jeebRoles.successContainer/warningContainer` mapping. That is now one
`SettlementStatusPill` (see the refusal below for why it is not a kit widget), with the geometry
brought onto the system: stadium shape, the kit chip's `4/12` inset, `jeebText.label`.

**Flow: unchanged.** Same states (loading / error / empty / ready), same row tap → detail, same
per-row PDF download, same export snackbar, same constructors (the devtool catalog and the router
build these unchanged). No new step, no removed affordance, no copy edit.

## Refusals and deliberate divergences

1. **`JeebMoneyBreakdown` was considered and refused.** Its own doc-comment scopes it to screen 17
   and records that 14 and 19 both measured and refused it. It draws one outlined card of
   label/value rows + rule + total + lock footnote; the settlement breakdown is a *list of
   deliveries*, one grey row each. Wrapping each delivery in that card would produce N stacked
   fee cards, and folding the list into one card would need a "fare" label and a total label that
   do not exist in `app_en.arb` — i.e. invented copy. **D41/D44 is still held**: the wording lives in
   `l10n.settlementCommissionLabel` = `"Platform fee: {amount}"`, `kJeebCommissionRate` is never
   multiplied at a call site here (the fee arrives on the wire as `SettlementDeliveryLine.commission`),
   and `test/decision_violations_test.dart` pins both the "Platform fee" string and the absence of
   "Commission". Verified green.
2. **`l10n.settlementTotalPayout` ("Total cash kept") is NOT wrapped in `JeebSectionLabel`.** That
   widget uppercases, and the same decision test asserts `find.text('Total cash kept')` exactly. The
   `sectionLabel` token (and its periwinkle ink, which is what the kit label keeps on navy) is
   applied by hand instead. This is the one label on either screen that is not uppercase.
3. **The status pill is not a kit widget.** `JeebSystemChip`'s three tones (filled / outlined /
   accent) carry no success or warning voice, and paid-vs-pending is the only state a statement has —
   flattening it to one grey pill would drop meaning. The contrast-gated `jeebRoles` pair stays.
   *Kit gap worth recording:* nothing in the kit expresses a success/warning state pill.
4. **No docked `JeebCtaFooter`.** 19 has one because its export is screen-level. Here the PDF is
   *per statement*, and the screen has no notion of a "current" statement — a docked CTA would have
   to invent one. The per-row download stays exactly where it was.
5. **No orange anywhere except the hero's 30% decorative ring.** Nothing on these screens is
   expiring or urgent, so the ration is spent on nothing else. Correct by R5, and it matches 19.

## Data the design language would want and the app does not have

- A tier emoji leading each delivery row (19 draws one): `SettlementDeliveryLine.tier` is a free
  string from the wire with no emoji/id mapping. Left off rather than guessed — the same call 19 made.
- `line.date` is rendered verbatim from the wire. 19 parses its ISO date and shows a weekday; here
  the wire format is not pinned by a contract this lane can see, so no parsing was added.
- The hero has no secondary stat strip (19 has three): the statement model carries only
  `totalPayout`, `currency`, `status`, and the delivery lines.

## Verification

- `dart analyze lib/features/settlement` → **No issues found!**
- `flutter test test/decision_violations_test.dart test/settlement_cubit_test.dart
  test/core/theme/no_raw_semantic_colors_test.dart test/core/jeeb_commission_test.dart
  test/devtool/catalog_network_guard_test.dart` → **all pass** (34 + 2).
- Design-token gate patterns (`Color(0x…)`, `Colors.<name>`, literal `SizedBox`/`EdgeInsets`/
  `BorderRadius.circular`/`fontSize`) grepped over `lib/features/settlement/` → clean.
- Rendered both screens at 440×956 through `AppTheme.light()` (throwaway golden harness, deleted),
  in `en` and `ar`. RTL mirrors correctly: back circle, hero eyebrow/pill, the decorative ring and
  the row amounts all flip. The first empty-state pass was vertically centred (R1 violation) and was
  fixed by hosting `OmdsEmptyState` in a `ListView`, the order-history pattern.

## Identifiers

Preserved byte-identically: `settlement_root`, `settlement_detail_root`,
`settlement_statement_row_{id}`, `settlement_download_{id}`. Added (new interactive elements):
`settlement_back`, `settlement_detail_back` — the `<screen>_back` contract §5 #1 owns.

## Wiring

One non-blocking request in `wiring/w4-settlement.md`: add the extracted
`settlement_status_pill.dart` to `migratedFiles` in `test/core/theme/no_raw_semantic_colors_test.dart`
so the color-role guard keeps covering the paid/pending mapping now that it lives one file lower.
