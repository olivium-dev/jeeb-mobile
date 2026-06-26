import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../domain/reviews_repository.dart';
import '../reviews_l10n.dart';

/// One review row in the all-reviews list (JM-068). Reuses [OmdsReviewCard] for
/// the avatar + stars + body (reuse-table.md Ratings/Feedback), but with
/// `showActions: false` so NO Helpful/Reply controls render (D57 — reviews are
/// immutable). The D27 report affordance is a DISTINCT trailing node
/// (`review_<id>_report_cta`) so QA/Maestro can assert + tap it by id, and a
/// `review_<id>_reviewer_name` node carries the first-name-only attribution
/// (D58) for the flow assertion.
///
/// A dumb widget (40_GUARDRAILS_ARCH §1): data in via constructor, the report
/// event out via [onReport] — it never reaches into `sl`/`context.go`.
class ReviewRow extends StatelessWidget {
  const ReviewRow({
    super.key,
    required this.review,
    required this.copy,
    required this.onReport,
  });

  final ReviewItem review;
  final ReviewsL10n copy;

  /// Fired when the per-row `review_<id>_report_cta` is tapped (D27). The screen
  /// owns the confirm dialog + cubit call.
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      // Per-row container so a flow can scope assertions to one review.
      identifier: 'review_${review.id}',
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // First-name-only attribution (D58) — its own asserted node.
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
            // The card also renders the name internally; we pass it for the
            // avatar initial + visual parity, but the asserted name node above
            // is the i18n-safe attribution target. First name ONLY (D58).
            userName: review.reviewerFirstName,
            rating: review.score,
            reviewText: review.body ?? '',
            timeAgo: copy.relativeTime(review.timestamp),
            // D57: NO Helpful/Reply controls on an immutable review.
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
