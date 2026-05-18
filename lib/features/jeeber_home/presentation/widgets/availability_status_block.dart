import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/availability_state.dart';
import '../../domain/entities/availability_status.dart';

/// Persistent text block beneath the toggle that always tells the
/// Jeeber what their state is and (when online) how many deliveries are
/// in-flight.
class AvailabilityStatusBlock extends StatelessWidget {
  const AvailabilityStatusBlock({super.key, required this.view});

  static const Key rootKey = Key('availability-status-block-root');
  static const Key activeDeliveriesKey =
      Key('availability-status-block-active-deliveries');

  final AvailabilityViewState view;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: rootKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        _StatusHeadline(view: view),
        if (view.status.isOnline) ...[
          const SizedBox(height: Spacing.xSmall),
          _ActiveDeliveriesLine(count: view.status.activeDeliveryCount),
        ],
      ],
    );
  }
}

class _StatusHeadline extends StatelessWidget {
  const _StatusHeadline({required this.view});

  final AvailabilityViewState view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      _headline(context),
      textAlign: TextAlign.center,
      style: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  String _headline(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (view.isToggleInFlight) return l10n.availabilityTransitioning;
    return switch (view.status.state) {
      AvailabilityState.online => l10n.availabilityStatusOnline,
      AvailabilityState.offline => l10n.availabilityStatusOffline,
      AvailabilityState.autoOffline => l10n.availabilityStatusAutoOffline,
    };
  }
}

class _ActiveDeliveriesLine extends StatelessWidget {
  const _ActiveDeliveriesLine({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Text(
      l10n.availabilityActiveDeliveries(count),
      key: AvailabilityStatusBlock.activeDeliveriesKey,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
