import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/delivery_man_profile_view_data.dart';

/// Wraps a [DeliveryReviewData] in the shared [OmdsReviewCard] (reuse-table.md:
/// Ratings/Feedback → feedback-service, use-as-is). Supplies localized action
/// labels, brand-orange stars ([ColorScheme.primary]), and the verified-client
/// subtitle. Bordered + rounded to match the Figma card; index drives the
/// Semantics ids QA/Maestro target.
class DeliveryReviewCard extends StatelessWidget {
  const DeliveryReviewCard({
    super.key,
    required this.review,
    required this.index,
    required this.onHelpful,
    required this.onReply,
  });

  final DeliveryReviewData review;
  final int index;
  final VoidCallback onHelpful;
  final VoidCallback onReply;

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
        child: _ReviewCardBody(
          review: review,
          onHelpful: onHelpful,
          onReply: onReply,
        ),
      ),
    );
  }
}

class _ReviewCardBody extends StatelessWidget {
  const _ReviewCardBody({
    required this.review,
    required this.onHelpful,
    required this.onReply,
  });

  final DeliveryReviewData review;
  final VoidCallback onHelpful;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return OmdsReviewCard(
      userName: review.reviewerName,
      userImageUrl: review.reviewerAvatarUrl,
      rating: review.rating,
      reviewText: review.body,
      timeAgo: l10n.reviewRelativeDaysAgo(review.daysAgo),
      isVerifiedPurchase: review.isVerified,
      verifiedPurchaseLabel: l10n.reviewerVerifiedBadge,
      helpfulCount: review.helpfulCount,
      helpfulLabel: l10n.reviewHelpfulAction,
      replyLabel: l10n.reviewReplyAction,
      starColor: theme.colorScheme.primary,
      onHelpfulPressed: onHelpful,
      onReplyPressed: onReply,
    );
  }
}
