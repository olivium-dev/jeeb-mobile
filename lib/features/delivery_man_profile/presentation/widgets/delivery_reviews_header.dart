import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';






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
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.large,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ReviewsTitle(),
          const SizedBox(height: Spacing.xSmall),
          _CountAndViewAll(reviewCount: reviewCount, onViewAll: onViewAll),
        ],
      ),
    );
  }
}

class _ReviewsTitle extends StatelessWidget {
  const _ReviewsTitle();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Text(
      l10n.deliveryManProfileReviewsTitle,
      style: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.secondaryContainer,
        fontWeight: FontWeight.w700,
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
      identifier: 'profile_view_all_reviews',
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
