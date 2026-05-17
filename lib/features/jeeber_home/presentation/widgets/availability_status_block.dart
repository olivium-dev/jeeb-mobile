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
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final headline = view.isToggleInFlight
        ? l10n.availabilityTransitioning
        : switch (view.status.state) {
            AvailabilityState.online => l10n.availabilityStatusOnline,
            AvailabilityState.offline => l10n.availabilityStatusOffline,
            AvailabilityState.autoOffline =>
              l10n.availabilityStatusAutoOffline,
          };

    return Column(
      key: rootKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          headline,
          textAlign: TextAlign.center,
          style: textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (view.status.isOnline) ...[
          const SizedBox(height: Spacing.xSmall),
          Text(
            l10n.availabilityActiveDeliveries(
              view.status.activeDeliveryCount,
            ),
            key: activeDeliveriesKey,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
