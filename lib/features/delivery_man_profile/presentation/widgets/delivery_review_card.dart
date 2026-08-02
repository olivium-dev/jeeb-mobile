import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/delivery_man_profile_view_data.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

// Widget previews for [DeliveryReviewCard] — run with

/// A review card with a one-or-two-line body: phone width, plus the list
/// padding. Boxes below are sized from what the card actually measures at 390
const Size _deliveryReviewCardBox = Size(390, 230);

/// A body-less card collapses to the header row only (~106 px of card).
const Size _deliveryReviewCardCompactBox = Size(390, 155);

/// The longest plausible body needs ~327 px of card on its own.
const Size _deliveryReviewCardTallBox = Size(390, 380);

/// The Figma comp's review body (`DevDeliveryManProfileFixtures`).
const String _deliveryReviewCardLorem =
    'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed ut leo '
    'facilisis, mollis dolor bibendum, tempor dolor. Lorem ipsum dolor sit '
    'amet, consectetur adipiscing elit.';

/// Hosts one card the way [DeliveryReviewsList] does: the same directional list
/// padding, and — the part that matters — an UNBOUNDED height.
Widget _deliveryReviewCardHosted(DeliveryReviewData review, {int index = 0}) =>
    SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.large,
        Spacing.medium,
        Spacing.large,
        Spacing.large,
      ),
      child: DeliveryReviewCard(review: review, index: index),
    );

/// The happy path, as the screen test builds it: a named, verified reviewer
/// with a whole-number score and a short body.
@JeebPreview(group: 'delivery_man_profile', name: 'Verified, 4 stars', size: _deliveryReviewCardBox)
Widget deliveryReviewCardVerified() => _deliveryReviewCardHosted(
      const DeliveryReviewData(
        id: 'r1',
        reviewerName: 'Karl Assaf',
        rating: 4,
        body: 'Great delivery, fast and friendly.',
        daysAgo: 2,
        reviewerAvatarUrl: 'https://i.pravatar.cc/150?img=15',
      ),
    );

/// The blank-reviewer regression, made visible.
/// A review can arrive from feedback-service with an empty client name. The
@JeebPreview(group: 'delivery_man_profile', name: 'Anonymous reviewer', size: _deliveryReviewCardBox)
Widget deliveryReviewCardAnonymous() => _deliveryReviewCardHosted(
      const DeliveryReviewData(
        id: 'anonymous',
        reviewerName: '   ',
        rating: 4,
        body: 'Great delivery.',
        daysAgo: 2,
        reviewerAvatarUrl: 'https://example.com/private-avatar.png',
      ),
      index: 1,
    );

/// A star-only review: the client rated but wrote nothing.
/// The body block is dropped entirely (`review.body.isNotEmpty`), so the card
@JeebPreview(group: 'delivery_man_profile', name: 'Rating only, no body', size: _deliveryReviewCardCompactBox)
Widget deliveryReviewCardNoBody() => _deliveryReviewCardHosted(
      const DeliveryReviewData(
        id: 'r-no-body',
        reviewerName: 'Nadia Chehab',
        rating: 5,
        body: '',
        daysAgo: 1,
        helpfulCount: 24,
      ),
      index: 2,
    );

/// A half-star score — the only state that renders `Icons.star_half`.
/// It is also the only state where `_formatRating` takes its non-integer
@JeebPreview(group: 'delivery_man_profile', name: 'Half star', size: _deliveryReviewCardBox)
Widget deliveryReviewCardHalfStar() => _deliveryReviewCardHosted(
      const DeliveryReviewData(
        id: 'r-half',
        reviewerName: 'Rami Khoury',
        rating: 4.5,
        body: 'Arrived on time, but the bag was a little squashed.',
        daysAgo: 12,
      ),
      index: 3,
    );

/// An unverified reviewer: the "Verified Client" subtitle disappears and the
/// name sits directly above the stars.
@JeebPreview(group: 'delivery_man_profile', name: 'Unverified reviewer', size: _deliveryReviewCardBox)
Widget deliveryReviewCardUnverified() => _deliveryReviewCardHosted(
      const DeliveryReviewData(
        id: 'r-unverified',
        reviewerName: 'Tarek Aoun',
        rating: 3,
        body: 'Took a while to find the building.',
        daysAgo: 30,
        isVerified: false,
      ),
      index: 4,
    );

/// Layout ceiling: the longest plausible first name, the Figma lorem body, and
/// a year-old timestamp all at once.
@JeebPreview(group: 'delivery_man_profile', name: 'Long name and body', size: _deliveryReviewCardTallBox)
Widget deliveryReviewCardLongContent() => _deliveryReviewCardHosted(
      const DeliveryReviewData(
        id: 'r-long',
        reviewerName: 'Abdulrahman Al-Muhandis',
        rating: 5,
        body: _deliveryReviewCardLorem,
        daysAgo: 365,
        reviewerAvatarUrl: 'https://i.pravatar.cc/150?img=33',
      ),
      index: 5,
    );
