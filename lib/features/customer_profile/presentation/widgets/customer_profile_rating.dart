import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

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

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

// Widget previews for [CustomerProfileRating] — run with

/// The width the chip actually gets inside `CustomerProfileHeader` on a 390pt
/// phone: `Spacing.xLarge` gutters on both sides, an `Sizes.eightXLarge` avatar
const double _customerProfileRatingIdentityWidth = 250;

/// The same column on a 320pt phone (iPhone SE, small Android):
/// `320 - 24 - 24 - 80 - 12 = 180`. Used by the longest state, where the
const double _customerProfileRatingSmallIdentityWidth = 180;

/// Canvas box for the chip: phone width, and tall enough for the 200% rendering
/// (a single 32pt line — this label truncates rather than wrapping).
const Size _customerProfileRatingChipBox = Size(390, 96);

/// Renders the chip under the constraint the profile header really gives it,
/// leading-aligned the way `CrossAxisAlignment.start` places it in the identity
Widget _customerProfileRatingHosted({
  required double? rating,
  required int ratingCount,
  double width = _customerProfileRatingIdentityWidth,
}) =>
    Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: CustomerProfileRating(rating: rating, ratingCount: ratingCount),
      ),
    );

/// The state the widget was written for: an established customer, filled star,
/// "4.9 . 312 Reviews" (the exact pair named in the class doc comment).
@JeebPreview(
  group: 'customer_profile',
  name: 'Rated (production)',
  size: _customerProfileRatingChipBox,
)
Widget customerProfileRatingRated() =>
    _customerProfileRatingHosted(rating: 4.9, ratingCount: 312);

/// The state most accounts are actually in: the seeded customer carries no
/// rating at all, so `rating` is null and `ratingCount` is 0.
@JeebPreview(
  group: 'customer_profile',
  name: 'Unrated (cold start)',
  size: _customerProfileRatingChipBox,
)
Widget customerProfileRatingUnrated() =>
    _customerProfileRatingHosted(rating: null, ratingCount: 0);

/// Reviews on file, no average computed — and the header denies both.
/// `_hasRating` is `rating != null && ratingCount > 0`, one boolean over two
@JeebPreview(
  group: 'customer_profile',
  name: 'Reviews, no average',
  size: _customerProfileRatingChipBox,
)
Widget customerProfileRatingCountWithoutAverage() =>
    _customerProfileRatingHosted(rating: null, ratingCount: 42);

/// One review, and the header presents it as a score.
/// Two defects share this frame:
@JeebPreview(
  group: 'customer_profile',
  name: 'Single review',
  size: _customerProfileRatingChipBox,
)
Widget customerProfileRatingSingleReview() =>
    _customerProfileRatingHosted(rating: 5.0, ratingCount: 1);

/// A genuinely badly-rated account: 0.0 across 3 ratings.
/// `_hasRating` is true, so this takes the SOLID `Icons.star_rounded` inked with
@JeebPreview(
  group: 'customer_profile',
  name: 'Zero score, rated',
  size: _customerProfileRatingChipBox,
)
Widget customerProfileRatingZeroScore() =>
    _customerProfileRatingHosted(rating: 0.0, ratingCount: 3);

/// Longest plausible content in the narrowest column: a long-standing account,
/// 4.96 over 1284 ratings, on a 320pt phone (180pt of column).
@JeebPreview(
  group: 'customer_profile',
  name: 'Longest plausible (small phone)',
  size: _customerProfileRatingChipBox,
)
Widget customerProfileRatingLongest() => _customerProfileRatingHosted(
      rating: 4.96,
      ratingCount: 1284,
      width: _customerProfileRatingSmallIdentityWidth,
    );
