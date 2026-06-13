import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';
import 'package:open_file/open_file.dart';

import '../../../l10n/app_localizations.dart';
import '../application/earnings_cubit.dart';
import '../application/earnings_state.dart';
import '../domain/earnings_repository.dart';
import '../domain/earnings_summary.dart';

class EarningsDashboardScreen extends StatelessWidget {
  const EarningsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(title: l10n.earningsTitle),
      body: BlocConsumer<EarningsCubit, EarningsState>(
        listener: _onStateChange,
        builder: _buildBody,
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

  Widget _buildBody(BuildContext context, EarningsState state) {
    if (state.mode == EarningsViewMode.loading) {
      return const Center(child: OmdsLoadingState());
    }
    if (state.mode == EarningsViewMode.error) {
      return _ErrorView(message: state.errorMessage ?? '');
    }
    return _ReadyBody(summary: state.summary!, state: state);
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return OmdsErrorState(
      message: message,
      onRetry: () => context.read<EarningsCubit>().loadEarnings(),
    );
  }
}

class _ReadyBody extends StatelessWidget {
  const _ReadyBody({required this.summary, required this.state});
  final EarningsSummary summary;
  final EarningsState state;

  @override
  Widget build(BuildContext context) {
    return OmdsPullToRefresh(
      onRefresh: () => context.read<EarningsCubit>().loadEarnings(),
      child: ListView(
        padding: const EdgeInsets.all(Spacing.medium),
        children: [
          _PeriodFilterRow(selectedPeriod: state.period),
          const SizedBox(height: Spacing.medium),
          _SummaryCard(summary: summary),
          const SizedBox(height: Spacing.medium),
          _StatsRow(summary: summary),
          const SizedBox(height: Spacing.medium),
          _DeliveryBreakdownList(deliveries: summary.deliveries),
          const SizedBox(height: Spacing.medium),
          const _SettlementStatementsRow(),
          const SizedBox(height: Spacing.xLarge),
          _ExportButton(exportMode: state.exportMode),
        ],
      ),
    );
  }
}

class _PeriodFilterRow extends StatelessWidget {
  const _PeriodFilterRow({required this.selectedPeriod});
  final EarningsPeriod selectedPeriod;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: EarningsPeriod.values
          .map((p) => _PeriodPill(period: p, selected: p == selectedPeriod))
          .toList(),
    );
  }
}

class _PeriodPill extends StatelessWidget {
  const _PeriodPill({required this.period, required this.selected});
  final EarningsPeriod period;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: Spacing.xSmall),
      child: OmdsChip(
        label: _label(l10n, period),
        isSelected: selected,
        onTap: () => context.read<EarningsCubit>().loadEarnings(period: period),
      ),
    );
  }

  String _label(AppLocalizations l10n, EarningsPeriod p) {
    switch (p) {
      case EarningsPeriod.today:
        return l10n.earningsPeriodToday;
      case EarningsPeriod.week:
        return l10n.earningsPeriodWeek;
      case EarningsPeriod.month:
        return l10n.earningsPeriodMonth;
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});
  final EarningsSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xLarge),
        child: Column(
          children: [
            Semantics(
              label: '${l10n.earningsNet} ${summary.netPayout} ${summary.currency}',
              child: Text(
                '${summary.netPayout} ${summary.currency}',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: Spacing.twoXSmall),
            Text(summary.periodLabel, style: theme.textTheme.bodySmall),
            const SizedBox(height: Spacing.medium),
            _SummaryBreakdownRow(summary: summary, l10n: l10n),
          ],
        ),
      ),
    );
  }
}

class _SummaryBreakdownRow extends StatelessWidget {
  const _SummaryBreakdownRow({required this.summary, required this.l10n});
  final EarningsSummary summary;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _BreakdownItem(
          label: l10n.earningsGross,
          value: '${summary.totalEarnings} ${summary.currency}',
        ),
        _BreakdownItem(
          label: l10n.earningsCommission,
          value: '${summary.commission} ${summary.currency}',
        ),
      ],
    );
  }
}

class _BreakdownItem extends StatelessWidget {
  const _BreakdownItem({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(label, style: theme.textTheme.labelSmall),
        const SizedBox(height: Spacing.twoXSmall),
        Text(value, style: theme.textTheme.titleSmall),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.summary});
  final EarningsSummary summary;

  @override
  Widget build(BuildContext context) {
    final ratingText = summary.averageRating != null
        ? summary.averageRating!.toStringAsFixed(1)
        : '—';
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: '${summary.deliveryCount}',
            subtitle: 'Deliveries',
          ),
        ),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: _StatCard(title: ratingText, subtitle: 'Avg Rating'),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.medium),
        child: Column(
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: Spacing.twoXSmall),
            Text(subtitle, style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _DeliveryBreakdownList extends StatelessWidget {
  const _DeliveryBreakdownList({required this.deliveries});
  final List<EarningsDeliveryItem> deliveries;

  @override
  Widget build(BuildContext context) {
    if (deliveries.isEmpty) return const SizedBox.shrink();
    return Column(
      children: deliveries.map(_DeliveryRow.new).toList(),
    );
  }
}

class _DeliveryRow extends StatelessWidget {
  const _DeliveryRow(this.item);
  final EarningsDeliveryItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      title: Text(l10n.earningsDeliveryItemTitle(item.deliveryId)),
      subtitle: Text(l10n.earningsDeliveryItemTier(item.tier)),
      trailing: Text(
        l10n.earningsDeliveryItemFare(
          item.fare.toString(),
          item.currency,
        ),
        semanticsLabel:
            '${item.fare} ${item.currency}',
      ),
    );
  }
}

class _SettlementStatementsRow extends StatelessWidget {
  const _SettlementStatementsRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'earnings-view-settlements',
      button: true,
      child: OmdsSettingsRow(
        key: const Key('earnings-row-settlements'),
        title: l10n.settlementTitle,
        leadingIcon: Icons.receipt_long_outlined,
        icon: Icons.chevron_right,
        onTap: () => context.push('/jeeber/settlement'),
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.exportMode});
  final EarningsExportMode exportMode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isLoading = exportMode == EarningsExportMode.exporting;
    return OmdsLoadingButton(
      text: l10n.earningsExportButton,
      isLoading: isLoading,
      onTap: () {
        if (!isLoading) context.read<EarningsCubit>().exportPdf();
      },
    );
  }
}
