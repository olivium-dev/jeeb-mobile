import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../core/theme/jeeb_color_roles.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/settlement_statement.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/settlement_detail_screen_fixtures.dart';

/// Settlement statement detail screen (T-MOB-032 AC2).
///
/// Shows per-delivery breakdown for a single weekly statement.
/// Route: /jeeber/settlement/:id
// ORPHAN (JEBV4-227, verified 2026-07-12): dead chain from orphaned SettlementScreen — see docs/project-understanding/reconciliation/orphans.md
class SettlementDetailScreen extends StatelessWidget {
  const SettlementDetailScreen({
    super.key,
    required this.statement,
  });

  final SettlementStatement statement;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'settlement_detail_root',
      container: true,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: statement.weekLabel,
          showBackButton: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(Spacing.medium),
          children: [
            _SummaryCard(statement: statement, l10n: l10n),
            const SizedBox(height: Spacing.medium),
            Text(
              l10n.settlementBreakdownTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Spacing.small),
            ...statement.deliveries.map(
              (d) => _DeliveryLineRow(line: d, l10n: l10n),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.statement, required this.l10n});

  final SettlementStatement statement;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final isPaid = statement.status == SettlementStatus.paid;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.settlementTotalPayout,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.small,
                    vertical: Spacing.twoXSmall,
                  ),
                  decoration: BoxDecoration(
                    // paid = success, pending = warning (semantic roles).
                    color: isPaid
                        ? context.jeebRoles.successContainer
                        : context.jeebRoles.warningContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isPaid
                        ? l10n.settlementStatusPaid
                        : l10n.settlementStatusPending,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isPaid
                              ? context.jeebRoles.onSuccessContainer
                              : context.jeebRoles.onWarningContainer,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.xSmall),
            Semantics(
              label: l10n.settlementRowSemantics(
                '${statement.currency} ${statement.totalPayout.toStringAsFixed(2)}',
                isPaid ? l10n.settlementStatusPaid : l10n.settlementStatusPending,
              ),
              child: Text(
                '${statement.currency} ${statement.totalPayout.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryLineRow extends StatelessWidget {
  const _DeliveryLineRow({required this.line, required this.l10n});

  final SettlementDeliveryLine line;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xSmall),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.date,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  line.tier,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${line.currency} ${line.net.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                l10n.settlementCommissionLabel(
                  '${line.currency} ${line.commission.toStringAsFixed(2)}',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/settlement/settlement_detail_screen_preview_test.dart
// ===========================================================================
//
// This is a SCREEN, and an unusually simple one to drive: it takes a
// [SettlementStatement] VALUE and reads nothing else — no cubit, no
// `sl<>()`, no repository, no `Future`. Every state below is therefore just a
// different statement, which also means this screen has NO loading state and
// NO error state to preview: the fetch happens one screen up, in
// [SettlementScreen]'s cubit, and this one is handed the result. The states
// that remain are the shapes the payload can take.
//
// Two mechanical notes:
//
// 1. It owns its own `Scaffold` (the OMDSAppBar surface) and [jeebPreviewHost]
//    wraps every child in one as well, so the canvas shows two nested
//    Scaffolds. The inner one is the real surface; the outer contributes only a
//    background. The canvas box is therefore a real device
//    ([_settlementDetailScreenPhoneBox], 390x844) rather than the harness's
//    default 390x200 — a statement is an app bar over a scrolling breakdown and
//    cannot be judged in a 200 pt strip. The WIDTH is load-bearing: the
//    `flutter_test` default surface is 800 pt, wider than any phone, and every
//    layout defect noted below is invisible at that width.
//
// 2. `OMDSAppBar(showBackButton: true)` defaults to
//    `Navigator.of(context).maybePop()`, which needs a `Navigator` above it —
//    the canvas host is a bare surface. [_settlementDetailScreenHosted] supplies
//    a local one holding a single page, so the back affordance resolves instead
//    of throwing. It is then INERT, which is not a preview artefact: this screen
//    is reached by `context.go`-style navigation from a route that nothing links
//    to, so `maybePop` finds nothing to pop in the app either. See the ORPHAN
//    note on the class above (JEBV4-227).
//
// What these previews surfaced in the screen — see the notes on each:
//
//  * The breakdown has NO empty state. With `deliveries: []` the screen still
//    renders the `settlementBreakdownTitle` heading and then stops, leaving a
//    labelled section with nothing under it and 700 pt of blank surface — no
//    "no deliveries this week" copy, unlike every other list surface in the app
//    (`Empty · no delivery lines`).
//  * `_SummaryCard`'s header `Row` has NO flexible child. The label and the
//    status chip are both rigid, laid out under `spaceBetween`, so as soon as
//    the localized "Total cash kept" plus the chip exceed the card width the row
//    overflows rather than wrapping or ellipsizing. This is NOT an edge case:
//    the AR cell of `Paid · two deliveries` overflows by 37 pt at the ordinary
//    390 pt phone box at 100% text, because `إجمالي النقد المحتفظ به` is longer
//    than `Total cash kept`. EN at 390 pt fits, which is what makes it a fact
//    about the copy. At the 320 pt box it is 44 pt over in EN and 96 pt in AR.
//  * `_DeliveryLineRow` constrains only its LEFT column. The amounts column is
//    the non-flexible child, so it is measured first against an unbounded
//    main-axis constraint — it can neither wrap nor ellipsize — and the
//    `Expanded` date/tier column is left with the remainder, down to zero. The
//    amounts are printed as `'<currency> <toStringAsFixed(2)>'`, with no
//    grouping separators and two forced decimals, so an LBP payload puts
//    `LBP 2025000.00` over `Platform fee: LBP 225000.00` in that column
//    (`LBP · six lines`).
//  * The headline and the breakdown are two independent server fields and the
//    screen never reconciles them. `settlementTotalPayout` renders
//    `statement.totalPayout` verbatim; nothing sums the lines and nothing
//    accounts for a residual. The state the CATALOG has shipped since it was
//    written renders "Total cash kept USD 184.50" above two lines totalling
//    USD 16.00 + 12.00, and no part of the screen flags it
//    (`Paid · two deliveries`).
//  * `SettlementDeliveryLine.deliveryId` and `.fare` are parsed and carried but
//    never rendered — here or anywhere else in `lib/`. A Jeeber disputing a line
//    can see its date, tier, fee and net, but not WHICH delivery it was, and not
//    the fare the fee was taken from.
//  * `weekLabel` is free server text rendered straight into the app-bar title
//    with no `maxLines`/`overflow`, and it is also the field
//    `SettlementStatement.fromJson` defaults to `''` — so a payload that spells
//    the period differently opens a statement with a blank title bar
//    (`Partial payload · blank title`).

/// The canvas box for a whole screen: a real phone, not the harness default.
///
/// The width is not decoration — see note 1 in the section header.
const Size _settlementDetailScreenPhoneBox = Size(390, 844);

/// The smallest surface the app supports (iPhone SE class).
///
/// Reserved for the states whose defect is a width budget: 70 pt narrower is
/// the difference between an amounts column that leaves the date room and one
/// that does not.
const Size _settlementDetailScreenCompactBox = Size(320, 568);

/// Hosts one statement under a real `Navigator`.
///
/// Single-page on purpose — see note 2 in the section header. `Navigator` is
/// also all this screen needs: there is no `Router`, no `BlocProvider` and no
/// DI graph in the tree, because there is nothing on this screen that reads one.
Widget _settlementDetailScreenHosted(SettlementStatement statement) {
  return Navigator(
    onGenerateRoute: (RouteSettings settings) => MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => SettlementDetailScreen(statement: statement),
    ),
  );
}

/// The settled week, and the reconciliation gap.
///
/// The catalog's `Paid` state, unchanged. Read the headline against the two
/// lines below it: `USD 184.50` over `USD 16.00` + `USD 12.00`. The screen
/// presents the breakdown as the explanation of the total and then does no
/// arithmetic, so a statement whose lines do not add up renders exactly as
/// cleanly as one that does.
///
/// Matrixed because the summary header is the layout to watch: a label and a
/// status chip in a `spaceBetween` `Row` with nothing flexible between them.
/// The AR rendering swaps in the longer "إجمالي النقد المحتفظ به" and the 200%
/// rendering doubles it.
@JeebPreview(
  group: 'settlement',
  name: 'Paid · two deliveries',
  size: _settlementDetailScreenPhoneBox,
  matrix: true,
)
Widget settlementDetailScreenPaid() =>
    _settlementDetailScreenHosted(settlementDetailScreenPaidWeek);

/// The open week — the only state where the status chip takes the warning role.
///
/// Worth having beside the paid one: the chip is the single element that
/// changes, and the two semantic roles it can carry
/// (`successContainer` / `warningContainer`) are only comparable side by side.
/// The same reconciliation gap is here too, more starkly — `USD 96.00` over one
/// `USD 9.60` line reads like a misplaced decimal point and the screen has no
/// opinion about it.
@JeebPreview(
  group: 'settlement',
  name: 'Pending · one delivery',
  size: _settlementDetailScreenPhoneBox,
)
Widget settlementDetailScreenPending() =>
    _settlementDetailScreenHosted(settlementDetailScreenPendingWeek);

/// The week a Jeeber took no jobs — and the missing empty state.
///
/// `statement.deliveries.map(...)` spreads to nothing, so the "Delivery
/// Breakdown" heading is rendered and then the `ListView` ends. There is no
/// empty copy, no illustration and no CTA: just a section label over ~700 pt of
/// blank surface, under a headline reading `USD 0.00`.
@JeebPreview(
  group: 'settlement',
  name: 'Empty · no delivery lines',
  size: _settlementDetailScreenPhoneBox,
)
Widget settlementDetailScreenNoDeliveries() =>
    _settlementDetailScreenHosted(settlementDetailScreenNoDeliveriesWeek);

/// The layout ceiling: the live market's currency, six lines, a long period.
///
/// LBP has no minor unit in practice, so a week's payout is eight digits — and
/// the screen formats every amount by hand, `'<currency> ${v.toStringAsFixed(2)}'`,
/// with no grouping separators and two forced decimals. That puts
/// `Platform fee: LBP 225000.00` in `_DeliveryLineRow`'s amounts column, which
/// is the child with NO width constraint: it is laid out first at unbounded
/// width and the `Expanded` date/tier column takes what is left.
///
/// The long `weekLabel` lands in the app-bar title, which sets no `maxLines`.
///
/// Matrixed because this is the state where AR and 200% have somewhere to go:
/// six rows of latin digits inside a mirrored layout, and every one of them
/// doubled.
@JeebPreview(
  group: 'settlement',
  name: 'LBP · six lines',
  size: _settlementDetailScreenPhoneBox,
  matrix: true,
)
Widget settlementDetailScreenLbp() =>
    _settlementDetailScreenHosted(settlementDetailScreenLbpWeek);

/// The same LBP statement on the narrowest supported phone.
///
/// Not a duplicate: 320 pt is where the amounts column stops leaving the date
/// and tier a usable share of the row. Judging a hand-formatted eight-digit
/// amount at 390 pt says nothing about the device that actually runs out of
/// room first.
///
/// This one renders WITH overflow stripes on purpose — it is the state that
/// demonstrates both unconstrained `Row`s at once (44 pt over in the summary
/// header, 47 pt in a delivery line). The stripes are the finding, not a broken
/// fixture; `test/previews/settlement/settlement_detail_screen_preview_test.dart`
/// pins both so a fix cannot land silently.
@JeebPreview(
  group: 'settlement',
  name: 'LBP · compact 320',
  size: _settlementDetailScreenCompactBox,
)
Widget settlementDetailScreenLbpCompact() =>
    _settlementDetailScreenHosted(settlementDetailScreenLbpWeek);

/// What a statement the gateway has not fully labelled renders as.
///
/// `SettlementStatement.fromJson` accepts `weekLabel` or `periodLabel` for the
/// title and falls back to `''`; the fixture feeds it a payload spelling the
/// key a third way and omitting `deliveries` — which is the ordinary shape of
/// contract drift, not a synthetic null. The result is a statement opened under
/// a BLANK title bar, with a real payout on it (`USD 42.75`) and a breakdown
/// heading over nothing. Nothing on screen tells the user which period they are
/// looking at, and the back affordance is the only way out.
@JeebPreview(
  group: 'settlement',
  name: 'Partial payload · blank title',
  size: _settlementDetailScreenPhoneBox,
)
Widget settlementDetailScreenPartialPayload() =>
    _settlementDetailScreenHosted(settlementDetailScreenPartialPayloadWeek());
