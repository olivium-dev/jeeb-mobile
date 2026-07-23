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
      container: true,
      explicitChildNodes: true,
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
    final firstName = review.reviewerFirstName;
    final isAnonymous = firstName.isEmpty;
    final displayName = isAnonymous ? l10n.reviewerAnonymousLabel : firstName;
    return Padding(
      padding: const EdgeInsets.all(Spacing.medium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // OmdsReviewCard derives "?" for every non-Latin initial. Using
              // the OMDS avatar directly lets an Arabic anonymous label remain
              // visible while its privacy-safe neutral initial stays stable.
              OmdsProfileAvatar(
                initial: isAnonymous ? 'J' : firstName,
                profilePicUrl: isAnonymous ? null : review.reviewerAvatarUrl,
                size: Sizes.large * 2,
              ),
              const SizedBox(width: Spacing.small),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (review.isVerified) ...[
                      const SizedBox(height: Spacing.twoXSmall),
                      Text(
                        l10n.reviewerVerifiedBadge,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: Sizes.small,
                        ),
                      ),
                    ],
                    const SizedBox(height: Spacing.twoXSmall),
                    _ReviewStars(
                      rating: review.rating,
                      semanticsLabel: l10n.reviewRatingStarsLabel(
                        _formatRating(review.rating),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                l10n.reviewRelativeDaysAgo(review.daysAgo),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: Sizes.small,
                ),
              ),
            ],
          ),
          if (review.body.isNotEmpty) ...[
            const SizedBox(height: Spacing.small),
            Text(
              review.body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatRating(double rating) =>
      rating == rating.roundToDouble() ? rating.toStringAsFixed(0) : '$rating';
}

class _ReviewStars extends StatelessWidget {
  const _ReviewStars({required this.rating, required this.semanticsLabel});

  final double rating;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      container: true,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            final value = index + 1;
            final icon = rating >= value
                ? Icons.star
                : rating >= value - 0.5
                ? Icons.star_half
                : Icons.star_border;
            return Padding(
              padding: EdgeInsetsDirectional.only(
                end: index < 4 ? Sizes.threeXSmall : 0,
              ),
              child: Icon(
                icon,
                size: Sizes.small,
                color: Theme.of(context).colorScheme.primary,
              ),
            );
          }),
        ),
      ),
    );
  }
}
