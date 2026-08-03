import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/theme/jeeb_semantic_colors.dart';
import '../../../core/theme/jeeb_shadows.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_list_row.dart';
import '../../../core/widgets/jeeb/jeeb_navy_surface_card.dart';
import '../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/settlement_statement.dart';
import 'widgets/settlement_status_pill.dart';

/// Settlement statement detail screen (T-MOB-032 AC2).
///
/// Shows per-delivery breakdown for a single weekly statement.
/// Route: /jeeber/settlement/:id
///
/// redesign-2026-08: re-skinned to match its neighbour, the earnings dashboard
/// (screen 19) — the payout is a navy hero with the 38px `statHero` amount, the
/// breakdown is a `JeebSectionLabel` over grey `JeebListRow`s. Same data, same
/// order, no new affordances.
///
/// D41/D44: the per-delivery cut is a **platform fee**, never a "commission".
/// The wording lives in `l10n.settlementCommissionLabel` ("Platform fee:
/// {amount}") and is pinned by `test/decision_violations_test.dart`.
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
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              JeebTopBar.back(
                title: statement.weekLabel,
                identifier: 'settlement_detail_back',
              ),
              Expanded(
                child: ListView(
                  // 24px board gutter; the list simply ends and the white below
                  // it is the design (R1) — no Spacer, no centring.
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    Spacing.xLarge,
                    Spacing.medium,
                    Spacing.xLarge,
                    Spacing.xLarge,
                  ),
                  children: [
                    _PayoutHero(statement: statement, l10n: l10n),
                    const SizedBox(height: Spacing.large),
                    JeebSectionLabel(l10n.settlementBreakdownTitle),
                    const SizedBox(height: Spacing.small),
                    for (var i = 0; i < statement.deliveries.length; i++) ...[
                      if (i > 0) const SizedBox(height: Spacing.xSmall),
                      _DeliveryLineRow(
                        line: statement.deliveries[i],
                        l10n: l10n,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The navy payout hero — 19's `_CashHero` shape: eyebrow + status pill, then
/// the 38px amount.
class _PayoutHero extends StatelessWidget {
  const _PayoutHero({required this.statement, required this.l10n});

  final SettlementStatement statement;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final amount = MoneyFormat.format(
      statement.totalPayout,
      currency: statement.currency,
    );
    final statusLabel =
        SettlementStatusPill.labelFor(l10n, statement.status);

    return JeebNavySurfaceCard(
      radius: Spacing.large,
      padding: const EdgeInsetsDirectional.all(Spacing.large),
      shadow: JeebShadows.heroNavy,
      rings: const [JeebNavyRing.statTopEnd],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                // NOT `JeebSectionLabel`: that widget uppercases its label, and
                // `test/decision_violations_test.dart` pins this string exactly
                // ("Total cash kept"). The token — and its periwinkle ink, which
                // is the same ink the kit label keeps on navy — still applies.
                child: Text(
                  l10n.settlementTotalPayout,
                  style: context.jeebText.sectionLabel,
                ),
              ),
              const SizedBox(width: Spacing.small),
              SettlementStatusPill(status: statement.status),
            ],
          ),
          const SizedBox(height: Spacing.xSmall),
          Semantics(
            label: l10n.settlementRowSemantics(amount, statusLabel),
            child: Text(
              amount,
              style: context.jeebText.statHero.copyWith(
                color: scheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One delivery line — 19's grey breakdown row: `surfaceContainerHigh` block,
/// date over tier, amount kept and the platform fee on the trailing edge.
class _DeliveryLineRow extends StatelessWidget {
  const _DeliveryLineRow({required this.line, required this.l10n});

  final SettlementDeliveryLine line;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Never a bare `!`: `wrapForTest` themes with ThemeData.light(), where the
    // extension is absent, and the bang would crash every widget test.
    final semantic =
        theme.extension<JeebSemanticColors>() ?? JeebSemanticColors.light();
    final net = MoneyFormat.format(line.net, currency: line.currency);
    final fee = MoneyFormat.format(line.commission, currency: line.currency);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: OmdsBorderRadius.medium,
      ),
      child: JeebListRow(
        title: line.date,
        subtitle: line.tier,
        showChevron: false,
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              net,
              style: context.jeebText.cardTitle.copyWith(
                color: scheme.primary,
              ),
              semanticsLabel: net,
            ),
            // D41/D44: fee-only framing. The l10n value is "Platform fee:
            // {amount}" and the word "Commission" appears nowhere.
            Text(
              l10n.settlementCommissionLabel(fee),
              style: context.jeebText.caption.copyWith(
                color: semantic.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
