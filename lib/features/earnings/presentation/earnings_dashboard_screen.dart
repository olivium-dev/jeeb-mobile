import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';
import 'package:open_file/open_file.dart';

import '../application/earnings_cubit.dart';
import '../application/earnings_state.dart';
import '../domain/earnings_repository.dart';
import '../domain/earnings_summary.dart';
import 'earnings_dashboard_l10n.dart';

/// JM-052 — Earnings & Fees Dashboard.
///
/// The Earnings tab body:
///   * `earnings_total_cash` — the cash the Jeeber collected directly from
///     customers; this never moves through Jeeb.
///   * `earnings_fees_paid` — platform fees the Jeeber paid from their
///     pre-charged wallet on won offers.
///   * `earnings_net_per_offer` — average cash kept per delivery after the fee
///     (D44).
///   * `earnings_member_since` — the Jeeber's join date (only when the wire
///     surfaces it — never fabricated).
///   * `earnings_wallet_link` → `wallet` (wallet-hub, JM-053).
///   * `earnings_activity_link` → `wallet-activity` (wallet-activity-list,
///     JM-055).
///
/// Both cross-feature links target routes that are REGISTERED today (W2.5/W3
/// integrator batch), so they are real `pushNamed` edges — NOT guarded
/// coming-soon. The hub's `wallet_earnings_row` lands here.
///
/// Data: `GET /v1/jeeb/earnings?jeeberId=&period=` via `sl<EarningsRepository>()`
/// (→ `DioEarningsRepository`). The gateway rewrites `/v1/jeeb/earnings` →
/// `/wallet-service/v1/jeeb/earnings` on :4010 — the path fix the JM-052 AC
/// flagged (the repo previously posted the un-keyed `/v1/wallet/jeeb/earnings`).
class EarningsDashboardScreen extends StatelessWidget {
  const EarningsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final copy = EarningsDashboardL10n.of(context);
    return Semantics(
      identifier: 'earnings_dashboard_root',
      container: true,
      child: Scaffold(
        appBar: OMDSAppBar(title: copy.title),
        body: BlocConsumer<EarningsCubit, EarningsState>(
          listener: _onStateChange,
          builder: (context, state) => _buildBody(context, state, copy),
        ),
      ),
    );
  }

  void _onStateChange(BuildContext context, EarningsState state) {
    if (state.exportMode == EarningsExportMode.done &&
        state.exportedFilePath != null) {
      OpenFile.open(state.exportedFilePath!);
      context.read<EarningsCubit>().resetExport();
    }
    if (state.exportMode == EarningsExportMode.error &&
        state.exportError != null) {
      // EXEMPT: OMDS exports no standalone toast/snackbar widget; showOmdsSnackbar
      // is the approved fleet pattern for transient error feedback.
      showOmdsSnackbar(context, message: state.exportError!);
      context.read<EarningsCubit>().resetExport();
    }
  }

  Widget _buildBody(
    BuildContext context,
    EarningsState state,
    EarningsDashboardL10n copy,
  ) {
    if (state.mode == EarningsViewMode.loading) {
      return const Center(child: OmdsLoadingState());
    }
    if (state.mode == EarningsViewMode.error) {
      return OmdsErrorState(
        message: copy.loadError,
        retryLabel: copy.retry,
        onRetry: () => context.read<EarningsCubit>().loadEarnings(),
      );
    }
    return _ReadyBody(summary: state.summary!, state: state, copy: copy);
  }
}

class _ReadyBody extends StatelessWidget {
  const _ReadyBody({
    required this.summary,
    required this.state,
    required this.copy,
  });

  final EarningsSummary summary;
  final EarningsState state;
  final EarningsDashboardL10n copy;

  @override
  Widget build(BuildContext context) {
    return OmdsPullToRefresh(
      onRefresh: () => context.read<EarningsCubit>().loadEarnings(),
      child: ListView(
        padding: const EdgeInsets.all(Spacing.medium),
        children: [
          _PeriodFilterRow(selectedPeriod: state.period, copy: copy),
          const SizedBox(height: Spacing.medium),
          // ── Fee-only headline cards (D41/D44). ──────────────────────────────
          _TotalCashCard(summary: summary, copy: copy),
          const SizedBox(height: Spacing.medium),
          _FeesPaidCard(summary: summary, copy: copy),
          const SizedBox(height: Spacing.medium),
          _StatsRow(summary: summary, copy: copy),
          if (summary.memberSince != null) ...[
            const SizedBox(height: Spacing.medium),
            _MemberSinceRow(memberSince: summary.memberSince!, copy: copy),
          ],
          const SizedBox(height: Spacing.large),
          _DeliveryBreakdownList(summary: summary, copy: copy),
          const SizedBox(height: Spacing.large),
          // ── Cross-feature links (real edges). ───────────────────────────────
          _WalletLink(copy: copy),
          _ActivityLink(copy: copy),
          const SizedBox(height: Spacing.xLarge),
          _ExportButton(exportMode: state.exportMode, copy: copy),
        ],
      ),
    );
  }
}

class _PeriodFilterRow extends StatelessWidget {
  const _PeriodFilterRow({required this.selectedPeriod, required this.copy});
  final EarningsPeriod selectedPeriod;
  final EarningsDashboardL10n copy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: EarningsPeriod.values
          .map(
            (p) => _PeriodPill(
              period: p,
              selected: p == selectedPeriod,
              copy: copy,
            ),
          )
          .toList(),
    );
  }
}

class _PeriodPill extends StatelessWidget {
  const _PeriodPill({
    required this.period,
    required this.selected,
    required this.copy,
  });
  final EarningsPeriod period;
  final bool selected;
  final EarningsDashboardL10n copy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: Spacing.xSmall),
      child: Semantics(
        identifier: 'earnings_period_${period.name}',
        button: true,
        child: OmdsChip(
          label: _label(period),
          isSelected: selected,
          onTap: () =>
              context.read<EarningsCubit>().loadEarnings(period: period),
        ),
      ),
    );
  }

  String _label(EarningsPeriod p) {
    switch (p) {
      case EarningsPeriod.today:
        return copy.periodToday;
      case EarningsPeriod.week:
        return copy.periodWeek;
      case EarningsPeriod.month:
        return copy.periodMonth;
    }
  }
}

/// `earnings_total_cash` — total cash earned, net, off-wallet (COD, D41).
class _TotalCashCard extends StatelessWidget {
  const _TotalCashCard({required this.summary, required this.copy});
  final EarningsSummary summary;
  final EarningsDashboardL10n copy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = _fmt(summary.totalCashEarned);
    return Semantics(
      identifier: 'earnings_total_cash',
      container: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(copy.totalCashLabel, style: theme.textTheme.labelLarge),
              const SizedBox(height: Spacing.xSmall),
              Text(
                '$value ${summary.currency}',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                semanticsLabel: '$value ${summary.currency}',
              ),
              const SizedBox(height: Spacing.twoXSmall),
              Text(
                copy.totalCashHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `earnings_fees_paid` — total captured platform fees.
class _FeesPaidCard extends StatelessWidget {
  const _FeesPaidCard({required this.summary, required this.copy});
  final EarningsSummary summary;
  final EarningsDashboardL10n copy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = _fmt(summary.feesPaid);
    return Semantics(
      identifier: 'earnings_fees_paid',
      container: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.large),
          child: Row(
            children: [
              Icon(
                Icons.percent_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: Spacing.small),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(copy.feesPaidLabel, style: theme.textTheme.titleSmall),
                    const SizedBox(height: Spacing.twoXSmall),
                    Text(
                      copy.feesPaidHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Spacing.small),
              Text(
                '$value ${summary.currency}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                semanticsLabel: '$value ${summary.currency}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.summary, required this.copy});
  final EarningsSummary summary;
  final EarningsDashboardL10n copy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            identifier: 'earnings_net_per_offer',
            title: '${_fmt(summary.netPerOffer)} ${summary.currency}',
            subtitle: copy.netPerOfferLabel,
            hint: copy.netPerOfferHint,
          ),
        ),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: _StatCard(
            identifier: 'earnings_deliveries_count',
            title: '${summary.deliveryCount}',
            subtitle: copy.deliveriesLabel,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.identifier,
    required this.title,
    required this.subtitle,
    this.hint,
  });
  final String identifier;
  final String title;
  final String subtitle;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: identifier,
      container: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.medium),
          child: Column(
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Spacing.twoXSmall),
              Text(
                subtitle,
                style: theme.textTheme.labelSmall,
                textAlign: TextAlign.center,
              ),
              if (hint != null) ...[
                const SizedBox(height: Spacing.twoXSmall),
                Text(
                  hint!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// `earnings_member_since` — the Jeeber's join date (D-context; only rendered
/// when the wire surfaces it).
class _MemberSinceRow extends StatelessWidget {
  const _MemberSinceRow({required this.memberSince, required this.copy});
  final String memberSince;
  final EarningsDashboardL10n copy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatted = _formatDate(memberSince);
    return Semantics(
      identifier: 'earnings_member_since',
      container: true,
      child: Row(
        children: [
          Icon(
            Icons.event_available_outlined,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: Spacing.xSmall),
          Text(copy.memberSinceLabel, style: theme.textTheme.bodyMedium),
          const SizedBox(width: Spacing.xSmall),
          Text(
            formatted,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    return DateFormat.yMMM().format(parsed);
  }
}

class _DeliveryBreakdownList extends StatelessWidget {
  const _DeliveryBreakdownList({required this.summary, required this.copy});
  final EarningsSummary summary;
  final EarningsDashboardL10n copy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (summary.deliveries.isEmpty) {
      return Semantics(
        identifier: 'earnings_breakdown_empty',
        container: true,
        child: const OmdsEmptyState(),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(copy.breakdownTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: Spacing.xSmall),
        ...summary.deliveries.map((d) => _DeliveryRow(item: d, copy: copy)),
      ],
    );
  }
}

class _DeliveryRow extends StatelessWidget {
  const _DeliveryRow({required this.item, required this.copy});
  final EarningsDeliveryItem item;
  final EarningsDashboardL10n copy;

  @override
  Widget build(BuildContext context) {
    final cash = _fmt(item.cashCollected);
    final fee = _fmt(item.feePaid);
    return Semantics(
      identifier: 'earnings_delivery_row_${item.deliveryId}',
      container: true,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(copy.deliveryRowTitle(item.deliveryId)),
        subtitle: Text(copy.deliveryRowFee(fee, item.currency)),
        trailing: Text(
          '$cash ${item.currency}',
          semanticsLabel: '$cash ${item.currency}',
        ),
      ),
    );
  }
}

/// `earnings_wallet_link` → wallet-hub (JM-053). Pushed so the back stack
/// returns to the Earnings tab.
class _WalletLink extends StatelessWidget {
  const _WalletLink({required this.copy});
  final EarningsDashboardL10n copy;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'earnings_wallet_link',
      button: true,
      container: true,
      child: OmdsSettingsRow(
        title: copy.walletLink,
        subtitle: copy.walletLinkSubtitle,
        leadingIcon: Icons.account_balance_wallet_outlined,
        onTap: () => context.pushNamed('wallet'),
      ),
    );
  }
}

/// `earnings_activity_link` → wallet-activity-list (JM-055).
class _ActivityLink extends StatelessWidget {
  const _ActivityLink({required this.copy});
  final EarningsDashboardL10n copy;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'earnings_activity_link',
      button: true,
      container: true,
      child: OmdsSettingsRow(
        title: copy.activityLink,
        subtitle: copy.activityLinkSubtitle,
        leadingIcon: Icons.receipt_long_outlined,
        onTap: () => context.pushNamed('wallet-activity'),
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.exportMode, required this.copy});
  final EarningsExportMode exportMode;
  final EarningsDashboardL10n copy;

  @override
  Widget build(BuildContext context) {
    final isLoading = exportMode == EarningsExportMode.exporting;
    return Semantics(
      identifier: 'earnings_export_cta',
      button: true,
      container: true,
      child: OmdsLoadingButton(
        text: copy.exportButton,
        isLoading: isLoading,
        onTap: () {
          if (!isLoading) context.read<EarningsCubit>().exportPdf();
        },
      ),
    );
  }
}

String _fmt(double v) => v.toStringAsFixed(2);
