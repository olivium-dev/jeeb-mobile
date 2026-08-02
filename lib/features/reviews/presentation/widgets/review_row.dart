import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../domain/reviews_repository.dart';
import '../reviews_l10n.dart';

class ReviewRow extends StatelessWidget {
  const ReviewRow({
    super.key,
    required this.review,
    required this.copy,
    required this.onReport,
  });

  final ReviewItem review;
  final ReviewsL10n copy;

  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'review_${review.id}',
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: Spacing.medium,
              end: Spacing.medium,
              top: Spacing.small,
            ),
            child: Semantics(
              identifier: 'review_${review.id}_reviewer_name',
              child: Text(
                review.reviewerFirstName,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
          OmdsReviewCard(
            userName: review.reviewerFirstName,
            rating: review.score,
            reviewText: review.body ?? '',
            timeAgo: copy.relativeTime(review.timestamp),
            showActions: false,
            starColor: theme.colorScheme.primary,
          ),
          if (review.reportable)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: Spacing.small,
                bottom: Spacing.xSmall,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Semantics(
                  identifier: 'review_${review.id}_report_cta',
                  button: true,
                  child: TextButton.icon(
                    onPressed: onReport,
                    icon: Icon(
                      Icons.flag_outlined,
                      size: Sizes.medium,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    label: Text(
                      copy.reportAction,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
