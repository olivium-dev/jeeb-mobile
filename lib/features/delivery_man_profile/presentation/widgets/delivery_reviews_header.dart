import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

/// "Reviews" heading + (count · View all) row above the review list
/// (design §2). "View all" uses an [OmdsPrimaryButton] text variant so it is
/// not a raw Material button while still reading as a text affordance; brand
/// primary color comes from the theme (design flag §9.3 — not the un-themed
/// Figma template color).
class DeliveryReviewsHeader extends StatelessWidget {
  const DeliveryReviewsHeader({
    super.key,
    required this.reviewCount,
    required this.onViewAll,
  });

  final int reviewCount;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.large,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.deliveryManProfileReviewsTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.secondaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Spacing.xSmall),
          _CountAndViewAll(reviewCount: reviewCount, onViewAll: onViewAll),
        ],
      ),
    );
  }
}

class _CountAndViewAll extends StatelessWidget {
  const _CountAndViewAll({required this.reviewCount, required this.onViewAll});

  final int reviewCount;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            l10n.deliveryManProfileReviewsCount(reviewCount),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ),
        _ViewAllButton(label: l10n.deliveryManProfileViewAllReviews, onTap: onViewAll),
      ],
    );
  }
}

class _ViewAllButton extends StatelessWidget {
  const _ViewAllButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'delivery_man_profile_view_all_reviews',
      button: true,
      child: OmdsPrimaryButton(
        key: const Key('delivery-man-profile-view-all'),
        text: label,
        onTap: onTap,
        variant: OmdsButtonVariant.text,
      ),
    );
  }
}
