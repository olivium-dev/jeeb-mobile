import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';

import '../application/live_tracking_cubit.dart';
import '../application/live_tracking_state.dart';
import '../domain/delivery_tracking_info.dart';

class LiveTrackingScreen extends StatelessWidget {
  final String deliveryId;
  const LiveTrackingScreen({super.key, required this.deliveryId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const OMDSAppBar(
        title: 'Live Tracking',
        showBackButton: true,
        centerTitle: false,
      ),
      body: BlocBuilder<LiveTrackingCubit, LiveTrackingState>(
        builder: (context, state) {
          switch (state.mode) {
            case LiveTrackingViewMode.loading:
              return const Center(child: OmdsLoadingState());
            case LiveTrackingViewMode.error:
              return _ErrorBody(
                message: state.errorMessage ?? 'Something went wrong',
                onRetry: () => context.read<LiveTrackingCubit>().retry(),
              );
            case LiveTrackingViewMode.ready:
              return _TrackingBody(info: state.trackingInfo!);
          }
        },
      ),
    );
  }
}

class _TrackingBody extends StatelessWidget {
  final DeliveryTrackingInfo info;
  const _TrackingBody({required this.info});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Spacing.medium),
      children: [
        _TrackingHeaderCard(info: info),
        const SizedBox(height: Spacing.xLarge),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xSmall),
          child: Text(
            'Delivery Timeline',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: Spacing.medium),
        ...TrackingStage.values.map(
          (stage) => _TimelineStep(
            stage: stage,
            currentStage: info.currentStage,
            timestamp: info.stageTimestamps[stage],
            isLast: stage == TrackingStage.delivered,
          ),
        ),
      ],
    );
  }
}

class _TrackingHeaderCard extends StatelessWidget {
  const _TrackingHeaderCard({required this.info});

  final DeliveryTrackingInfo info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.medium),
        child: Row(
          children: [
            Icon(Icons.local_shipping, color: theme.colorScheme.primary),
            const SizedBox(width: Spacing.small),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delivery ${info.deliveryId}',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: Sizes.twoXSmall),
                  Text(
                    'Status: ${info.currentStage.label}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final TrackingStage stage;
  final TrackingStage currentStage;
  final DateTime? timestamp;
  final bool isLast;

  const _TimelineStep({
    required this.stage,
    required this.currentStage,
    required this.timestamp,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final isReached = stage.isAtOrBefore(currentStage);
    final isCurrent = stage == currentStage;
    final theme = Theme.of(context);
    final activeColor = theme.colorScheme.primary;
    final inactiveColor = theme.colorScheme.outlineVariant;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TimelineRail(
            isReached: isReached,
            isCurrent: isCurrent,
            isLast: isLast,
            stage: stage,
            currentStage: currentStage,
            activeColor: activeColor,
            inactiveColor: inactiveColor,
            onPrimary: theme.colorScheme.onPrimary,
          ),
          const SizedBox(width: Spacing.small),
          Expanded(
            child: _TimelineCopy(
              stage: stage,
              timestamp: timestamp,
              isReached: isReached,
              isCurrent: isCurrent,
              isLast: isLast,
              theme: theme,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRail extends StatelessWidget {
  const _TimelineRail({
    required this.isReached,
    required this.isCurrent,
    required this.isLast,
    required this.stage,
    required this.currentStage,
    required this.activeColor,
    required this.inactiveColor,
    required this.onPrimary,
  });

  final bool isReached;
  final bool isCurrent;
  final bool isLast;
  final TrackingStage stage;
  final TrackingStage currentStage;
  final Color activeColor;
  final Color inactiveColor;
  final Color onPrimary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: Sizes.threeXLarge,
      child: Column(
        children: [
          Container(
            width: isCurrent ? Sizes.large : Sizes.medium,
            height: isCurrent ? Sizes.large : Sizes.medium,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // Colors.transparent is the single allowed Colors.* per skill —
              // there is no semantic OMDS token for hit-test transparency.
              color: isReached ? activeColor : Colors.transparent,
              border: Border.all(
                color: isReached ? activeColor : inactiveColor,
                width: UIConstants.strokeWidthNormal,
              ),
            ),
            child: isCurrent
                ? Icon(Icons.check, size: Sizes.small, color: onPrimary)
                : null,
          ),
          if (!isLast)
            Expanded(
              child: Container(
                width: Sizes.threeXSmall,
                margin: const EdgeInsets.symmetric(
                  vertical: Spacing.twoXSmall,
                ),
                color: isReached && stage != currentStage
                    ? activeColor
                    : inactiveColor,
              ),
            ),
        ],
      ),
    );
  }
}

class _TimelineCopy extends StatelessWidget {
  const _TimelineCopy({
    required this.stage,
    required this.timestamp,
    required this.isReached,
    required this.isCurrent,
    required this.isLast,
    required this.theme,
  });

  final TrackingStage stage;
  final DateTime? timestamp;
  final bool isReached;
  final bool isCurrent;
  final bool isLast;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : Spacing.xLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stage.label,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              color: isReached
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (timestamp != null) ...[
            const SizedBox(height: Sizes.threeXSmall),
            Text(
              DateFormat('MMM d, h:mm a').format(timestamp!.toLocal()),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ] else if (!isReached) ...[
            const SizedBox(height: Sizes.threeXSmall),
            Text(
              'Pending',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: OmdsErrorState(
        message: message,
        icon: Icons.error_outline,
        onRetry: onRetry,
        retryLabel: 'Retry',
      ),
    );
  }
}
