import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

class CustomerProfileRating extends StatelessWidget {
  const CustomerProfileRating({
    super.key,
    required this.rating,
    required this.ratingCount,
  });

  final double? rating;
  final int ratingCount;

  bool get _hasRating => rating != null && ratingCount > 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final colorScheme = theme.colorScheme;

    final ratingText = (rating ?? 0).toStringAsFixed(1);
    final label = _hasRating
        ? l10n.deliveryManProfileRatingSummary(ratingText, ratingCount)
        : l10n.deliveryManProfileEmptyReviewsTitle;

    return Semantics(
      identifier: 'customer_profile_rating',
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _hasRating ? Icons.star_rounded : Icons.star_border_rounded,
            size: Sizes.large,
            color: colorScheme.primary,
          ),
          const SizedBox(width: Spacing.twoXSmall),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
