import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../l10n/app_localizations.dart';

/// Per-role rating line on the customer-profile identity card (JM-035 AC1, D6).
///
/// Always rendered (with the `customer_profile_rating` identifier) so the
/// Maestro presence assertion holds for every account — a rated account shows
/// "★ 4.9 · 312 Reviews", an unrated account shows a deterministic "No reviews
/// yet" state. The id is presence-only (i18n-safe); the value is never asserted.
///
/// MIDNIGHT M3-07: the star is `JeebSemanticColors.amber` (`#FFC107`), the
/// token sheet §3 field whose stated use is "stars/ratings" — R15's caption is
/// explicit that the board's stars shine amber on the night field. The count
/// run stays `mutedText`; amber is the glyph only.
///
/// Copy reuses the existing `deliveryManProfile*` rating keys (same rating-row
/// semantics) — no new ARB keys (l10n is integrator-owned). A dedicated
/// `customerProfileRating*` set is requested in `50_ROUTE_REQUESTS.md` for a
/// later copy-polish pass; Maestro keys on the identifier, not the text.
class CustomerProfileRating extends StatelessWidget {
  const CustomerProfileRating({
    super.key,
    required this.rating,
    required this.ratingCount,
    this.ratingUnavailable = false,
  });

  final double? rating;
  final int ratingCount;

  /// The review read failed — say so rather than claim "no reviews yet".
  final bool ratingUnavailable;

  bool get _hasReviews => ratingCount > 0;
  bool get _hasAggregate => rating != null && _hasReviews;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final semantics = Theme.of(context).extension<JeebSemanticColors>();
    final muted = semantics?.mutedText;

    final ratingText = (rating ?? 0).toStringAsFixed(1);
    final label = ratingUnavailable
        ? l10n.customerProfileRatingUnavailable
        : _hasAggregate
        ? l10n.deliveryManProfileRatingSummary(ratingText, ratingCount)
        : _hasReviews
        ? l10n.deliveryManProfileReviewsCount(ratingCount)
        : l10n.deliveryManProfileEmptyReviewsTitle;

    // Identifier-only + `container: true`, mirroring the proven
    // `DeliveryManMetaRow` pattern. A competing explicit `label` on this wrapper
    // fights the text-emitting child below for the accessible name, which folds
    // the `customer_profile_rating` identifier away when it merges up into the
    // header node (the name node then swallows it). `container: true` forces a
    // first-class node so the identifier survives; the visible `Text` already
    // exposes the rating summary as the readable label.
    return Semantics(
      identifier: 'customer_profile_rating',
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _hasAggregate && !ratingUnavailable
                ? Icons.star_rounded
                : Icons.star_border_rounded,
            size: Sizes.medium,
            // R15 draws the unearned star muted, never a dim amber.
            color: _hasAggregate && !ratingUnavailable
                ? semantics?.amber
                : muted,
          ),
          const SizedBox(width: Spacing.twoXSmall),
          Flexible(
            child: Text(
              label,
              style: context.jeebText.bodySmall.copyWith(color: muted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
