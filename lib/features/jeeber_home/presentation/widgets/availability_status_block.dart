import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/availability_state.dart';
import '../../domain/entities/availability_status.dart';

/// Supporting-text block of the availability card: the status line
/// ("You're online — receiving requests" / "You're offline"), the
/// active-deliveries count while online, and the auto-offline idle hint.
///
/// Start-aligned body copy (it sits beside the M3 switch inside
/// `AvailabilityCard`), never a headline — the card's title row owns the
/// heading.
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusHeadline(view: view),
        if (view.status.isOnline) ...[
          const SizedBox(height: Spacing.twoXSmall),
          _ActiveDeliveriesLine(count: view.status.activeDeliveryCount),
          const SizedBox(height: Spacing.twoXSmall),
          const _IdleHintLine(),
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
      textAlign: TextAlign.start,
      style: theme.textTheme.bodyMedium?.copyWith(
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
      textAlign: TextAlign.start,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// "Auto-offline after 8 h idle" — surfaces the inactivity policy alongside
/// the switch so the system flipping the Jeeber offline later is never a
/// surprise (§G2 fix spec).
class _IdleHintLine extends StatelessWidget {
  const _IdleHintLine();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      AppLocalizations.of(context).availabilityAutoOfflineHint,
      textAlign: TextAlign.start,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
