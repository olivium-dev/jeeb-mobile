import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

/// Compact ETA pill rendered at the top of the screen while the parcel is
/// in transit. Hidden by the screen layer in every other lifecycle state.
class DeliveryEtaBadge extends StatelessWidget {
  const DeliveryEtaBadge({super.key, required this.minutes});

  static const Key rootKey = Key('delivery-status-eta-badge');

  final int minutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final isArriving = minutes <= 1;
    return Container(
      key: rootKey,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.small,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: OmdsBorderRadius.large,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 16,
            color: colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: Spacing.xSmall),
          Text(
            l10n.deliveryEtaLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: Spacing.xSmall),
          Text(
            isArriving
                ? l10n.deliveryEtaArriving
                : l10n.deliveryEtaMinutes(minutes),
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
