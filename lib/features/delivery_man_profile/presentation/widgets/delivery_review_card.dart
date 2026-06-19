import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/delivery_man_profile_view_data.dart';

/// Wraps a [DeliveryReviewData] in the shared [OmdsReviewCard] (reuse-table.md:
/// Ratings/Feedback → feedback-service, use-as-is). Supplies brand-orange stars
/// ([ColorScheme.primary]) and the verified-client subtitle. Bordered + rounded
/// to match the Figma card; index drives the Semantics ids QA/Maestro target.
///
/// JM-067: read-only. Helpful/Reply actions are suppressed (`showActions:
/// false`, D57 — immutable reviews); the reviewer is attributed by first name
/// only (`reviewerFirstName`, D58).
class DeliveryReviewCard extends StatelessWidget {
  const DeliveryReviewCard({
    super.key,
    required this.review,
    required this.index,
  });

  final DeliveryReviewData review;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'delivery_man_profile_review_card_$index',
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(Sizes.small),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: _ReviewCardBody(review: review),
      ),
    );
  }
}

class _ReviewCardBody extends StatelessWidget {
  const _ReviewCardBody({required this.review});

  final DeliveryReviewData review;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return OmdsReviewCard(
      // D58 — first name only.
      userName: review.reviewerFirstName,
      userImageUrl: review.reviewerAvatarUrl,
      rating: review.rating,
      reviewText: review.body,
      timeAgo: l10n.reviewRelativeDaysAgo(review.daysAgo),
      isVerifiedPurchase: review.isVerified,
      verifiedPurchaseLabel: l10n.reviewerVerifiedBadge,
      starColor: theme.colorScheme.primary,
      // D57 — no Helpful/Reply controls; reviews are immutable + read-only.
      showActions: false,
    );
  }
}
