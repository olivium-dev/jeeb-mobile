import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/recent_delivery_summary.dart';

/// One-tap "order again" card for the most recent completed delivery.
class RecentDeliveryCard extends StatelessWidget {
  const RecentDeliveryCard({
    super.key,
    required this.summary,
    required this.onReorder,
  });

  final RecentDeliverySummary summary;
  final VoidCallback onReorder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(Spacing.medium),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Spacing.medium),
      ),
      child: Row(
        children: [
          Container(
            width: Sizes.xLarge,
            height: Sizes.xLarge,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(Spacing.small),
            ),
            child: Icon(
              Icons.replay_outlined,
              color: scheme.onPrimaryContainer,
              size: Sizes.large,
            ),
          ),
          const SizedBox(width: Spacing.small),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Spacing.twoXSmall),
                Text(
                  summary.destinationLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.small),
          TextButton(
            key: Key('recent-delivery-reorder-${summary.id}'),
            onPressed: onReorder,
            child: Text(l10n.homeReorderAction),
          ),
        ],
      ),
    );
  }
}
