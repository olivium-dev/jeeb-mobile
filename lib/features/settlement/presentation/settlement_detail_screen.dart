import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../core/theme/jeeb_color_roles.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/settlement_statement.dart';

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
    return Scaffold(
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
