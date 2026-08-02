import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../core/theme/jeeb_color_roles.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/settlement_statement.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/settlement_detail_screen_fixtures.dart';

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

/// The canvas box for a whole screen: a real phone, not the harness default.
/// The width is not decoration — see note 1 in the section header.
const Size _settlementDetailScreenPhoneBox = Size(390, 844);

/// The smallest surface the app supports (iPhone SE class).
/// Reserved for the states whose defect is a width budget: 70 pt narrower is
const Size _settlementDetailScreenCompactBox = Size(320, 568);

/// Hosts one statement under a real `Navigator`.
/// Single-page on purpose — see note 2 in the section header. `Navigator` is
Widget _settlementDetailScreenHosted(SettlementStatement statement) {
  return Navigator(
    onGenerateRoute: (RouteSettings settings) => MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => SettlementDetailScreen(statement: statement),
    ),
  );
}

/// The settled week, and the reconciliation gap.
/// The catalog's `Paid` state, unchanged. Read the headline against the two
@JeebPreview(
  group: 'settlement',
  name: 'Paid · two deliveries',
  size: _settlementDetailScreenPhoneBox,
  matrix: true,
)
Widget settlementDetailScreenPaid() =>
    _settlementDetailScreenHosted(settlementDetailScreenPaidWeek);

/// The open week — the only state where the status chip takes the warning role.
/// Worth having beside the paid one: the chip is the single element that
@JeebPreview(
  group: 'settlement',
  name: 'Pending · one delivery',
  size: _settlementDetailScreenPhoneBox,
)
Widget settlementDetailScreenPending() =>
    _settlementDetailScreenHosted(settlementDetailScreenPendingWeek);

/// The week a Jeeber took no jobs — and the missing empty state.
/// `statement.deliveries.map(...)` spreads to nothing, so the "Delivery
@JeebPreview(
  group: 'settlement',
  name: 'Empty · no delivery lines',
  size: _settlementDetailScreenPhoneBox,
)
Widget settlementDetailScreenNoDeliveries() =>
    _settlementDetailScreenHosted(settlementDetailScreenNoDeliveriesWeek);

/// The layout ceiling: the live market's currency, six lines, a long period.
/// LBP has no minor unit in practice, so a week's payout is eight digits — and
@JeebPreview(
  group: 'settlement',
  name: 'LBP · six lines',
  size: _settlementDetailScreenPhoneBox,
  matrix: true,
)
Widget settlementDetailScreenLbp() =>
    _settlementDetailScreenHosted(settlementDetailScreenLbpWeek);

/// The same LBP statement on the narrowest supported phone.
/// Not a duplicate: 320 pt is where the amounts column stops leaving the date
@JeebPreview(
  group: 'settlement',
  name: 'LBP · compact 320',
  size: _settlementDetailScreenCompactBox,
)
Widget settlementDetailScreenLbpCompact() =>
    _settlementDetailScreenHosted(settlementDetailScreenLbpWeek);

/// What a statement the gateway has not fully labelled renders as.
/// `SettlementStatement.fromJson` accepts `weekLabel` or `periodLabel` for the
@JeebPreview(
  group: 'settlement',
  name: 'Partial payload · blank title',
  size: _settlementDetailScreenPhoneBox,
)
Widget settlementDetailScreenPartialPayload() =>
    _settlementDetailScreenHosted(settlementDetailScreenPartialPayloadWeek());
