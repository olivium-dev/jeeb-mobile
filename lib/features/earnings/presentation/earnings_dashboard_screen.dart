import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../application/earnings_cubit.dart';
import '../application/earnings_state.dart';
import '../domain/earnings_summary.dart';

class EarningsDashboardScreen extends StatelessWidget {
  const EarningsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const OMDSAppBar(title: 'Earnings'),
      body: BlocBuilder<EarningsCubit, EarningsState>(
        builder: (context, state) {
          switch (state.mode) {
            case EarningsViewMode.loading:
              return const Center(child: OmdsLoadingState());
            case EarningsViewMode.error:
              return OmdsErrorState(
                message: state.errorMessage ?? 'Something went wrong',
                onRetry: () => context.read<EarningsCubit>().loadEarnings(),
              );
            case EarningsViewMode.ready:
              return _ReadyBody(summary: state.summary!);
          }
        },
      ),
    );
  }
}

class _ReadyBody extends StatelessWidget {
  final EarningsSummary summary;
  const _ReadyBody({required this.summary});

  @override
  Widget build(BuildContext context) {
    return OmdsPullToRefresh(
      onRefresh: () => context.read<EarningsCubit>().loadEarnings(),
      child: ListView(
        padding: const EdgeInsets.all(Spacing.medium),
        children: [
          _TotalEarningsCard(summary: summary),
          const SizedBox(height: Spacing.medium),
          _PrimaryStatsRow(summary: summary),
          const SizedBox(height: Spacing.medium),
          _SecondaryStatsRow(summary: summary),
          const SizedBox(height: Spacing.xLarge),
          OmdsPrimaryButton(
            text: 'Download Statement',
            variant: OmdsButtonVariant.outlined,
            icon: const Icon(Icons.download),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _TotalEarningsCard extends StatelessWidget {
  const _TotalEarningsCard({required this.summary});
  final EarningsSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xLarge),
        child: Column(
          children: [
            Text('Total Earnings', style: theme.textTheme.titleSmall),
            const SizedBox(height: Spacing.xSmall),
            Text(
              '${summary.totalEarnings} ${summary.currency}',
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: Spacing.twoXSmall),
            Text(summary.periodLabel, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _PrimaryStatsRow extends StatelessWidget {
  const _PrimaryStatsRow({required this.summary});
  final EarningsSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Deliveries',
            value: '${summary.deliveryCount}',
          ),
        ),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: _StatCard(
            title: 'Commission',
            value: '${summary.commission} ${summary.currency}',
          ),
        ),
      ],
    );
  }
}

class _SecondaryStatsRow extends StatelessWidget {
  const _SecondaryStatsRow({required this.summary});
  final EarningsSummary summary;

  @override
  Widget build(BuildContext context) {
    final ratingDisplay = summary.averageRating != null
        ? summary.averageRating!.toStringAsFixed(1)
        : '—';
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Net Payout',
            value: '${summary.netPayout} ${summary.currency}',
          ),
        ),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: _StatCard(title: 'Rating', value: ratingDisplay),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.medium),
        child: Column(
          children: [
            Text(title, style: theme.textTheme.labelSmall),
            const SizedBox(height: Spacing.twoXSmall),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
