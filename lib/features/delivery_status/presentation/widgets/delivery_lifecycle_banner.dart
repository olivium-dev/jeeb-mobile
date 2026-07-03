import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/delivery_snapshot.dart';

/// Single-line banner above the status content shown only for terminal
/// lifecycle states. Active deliveries don't render it (returning null is
/// the screen's responsibility; this widget renders a SizedBox otherwise so
/// it can sit safely inside a Column).
class DeliveryLifecycleBanner extends StatelessWidget {
  const DeliveryLifecycleBanner({super.key, required this.lifecycle});

  static const Key rootKey = Key('delivery-status-lifecycle-banner');

  final DeliveryLifecycle lifecycle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCompleted = lifecycle == DeliveryLifecycle.completed;
    final isCancelled = lifecycle == DeliveryLifecycle.cancelled;
    if (!isCompleted && !isCancelled) {
      return const SizedBox.shrink();
    }
    // Completed is a success state -> semantic success role (was the brand
    // tertiary orange); cancelled keeps the M3 error pair.
    final roles = context.jeebRoles;
    final background =
        isCompleted ? roles.successContainer : colorScheme.errorContainer;
    final foreground = isCompleted
        ? roles.onSuccessContainer
        : colorScheme.onErrorContainer;
    final icon =
        isCompleted ? Icons.check_circle_outline : Icons.cancel_outlined;
    final message = isCompleted
        ? l10n.deliveryCompletedBanner
        : l10n.deliveryCancelledBanner;
    return Container(
      key: rootKey,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.small,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: OmdsBorderRadius.small,
      ),
      child: Row(
        children: [
          Icon(icon, color: foreground),
          const SizedBox(width: Spacing.small),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.titleSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
