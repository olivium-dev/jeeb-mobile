import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_avatar.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/delivery_man_profile_view_data.dart';

/// A single review, rendered on the board's white card: [JeebOutlinedCard]
/// (1.5px `colorScheme.outline`, r16, **no shadow** — outline over shadow) with
/// a kit [JeebAvatar] identity disc and the `context.jeebText` ramp. The index
/// drives the Semantics ids QA/Maestro target.
///
/// JM-067: read-only. Helpful/Reply actions are suppressed (D57 — immutable
/// reviews); the reviewer is attributed by first name only
/// (`reviewerFirstName`, D58).
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
    // The frozen wrapper stays at the call site (the kit's documented consumer
    // idiom) so the node shape QA reads is unchanged by the re-skin.
    return Semantics(
      identifier: 'delivery_man_profile_review_card_$index',
      container: true,
      explicitChildNodes: true,
      child: JeebOutlinedCard(child: _ReviewCardBody(review: review)),
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
    final semantic = theme.extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    final firstName = review.reviewerFirstName;
    final isAnonymous = firstName.isEmpty;
    final displayName = isAnonymous ? l10n.reviewerAnonymousLabel : firstName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A reviewer with no name on file gets the kit's honest `dormant`
            // mark rather than a fabricated identity; the neutral 'J' initial
            // keeps a non-Latin anonymous label from degrading to "?".
            JeebAvatar.thread(
              initial: isAnonymous ? 'J' : firstName,
              imageUrl: isAnonymous ? null : review.reviewerAvatarUrl,
              fill: isAnonymous
                  ? JeebAvatarFill.dormant
                  : JeebAvatarFill.primary,
            ),
            const SizedBox(width: Spacing.small),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: context.jeebText.cardTitle.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (review.isVerified) ...[
                    const SizedBox(height: Spacing.twoXSmall),
                    Text(
                      l10n.reviewerVerifiedBadge,
                      style: context.jeebText.caption.copyWith(
                        color: semantic.mutedText,
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
              // R16's card timestamp, measured: 11.5/w600 `#8A93D8`.
              style: context.jeebText.caption.copyWith(
                color: semantic.mutedText,
              ),
            ),
          ],
        ),
        if (review.body.isNotEmpty) ...[
          const SizedBox(height: Spacing.small),
          Text(
            review.body,
            style: context.jeebText.body.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ],
    );
  }

  String _formatRating(double rating) =>
      rating == rating.roundToDouble() ? rating.toStringAsFixed(0) : '$rating';
}

class _ReviewStars extends StatelessWidget {
  const _ReviewStars({required this.rating, required this.semanticsLabel});

  final double rating;
  final String semanticsLabel;

  /// R15's own star pair: `amber` filled, white 22 % (`glassBorderVivid`)
  /// empty, and never a hollow glyph — the board draws none.
  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    return Semantics(
      label: semanticsLabel,
      container: true,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            final value = index + 1;
            final filled = rating >= value;
            final half = !filled && rating >= value - 0.5;
            return Padding(
              padding: EdgeInsetsDirectional.only(
                end: index < 4 ? Sizes.threeXSmall : 0,
              ),
              child: Icon(
                half ? Icons.star_half : Icons.star,
                size: Sizes.small,
                color: filled || half
                    ? semantic.amber
                    : semantic.glassBorderVivid,
              ),
            );
          }),
        ),
      ),
    );
  }
}
