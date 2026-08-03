import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_surface_tone.dart';
import '../../../../l10n/app_localizations.dart';

/// Per-role rating line on the customer-profile identity card (JM-035 AC1, D6).
///
/// Always rendered (with the `customer_profile_rating` identifier) so the
/// Maestro presence assertion holds for every account — a rated account shows
/// "★ 4.9 · 312 Reviews", an unrated account shows a deterministic "No reviews
/// yet" state. The id is presence-only (i18n-safe); the value is never asserted.
///
/// redesign-2026-08: the star inherits the SURFACE ink via [JeebSurfaceTone]
/// (white on the navy identity card, navy on a light one) rather than the warm
/// `starRatingColor` — §4.1 rations orange/amber to rating *stats*, and
/// `JeebProfileHeader`'s pinned navy star is the same rule.
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
  });

  final double? rating;
  final int ratingCount;

  bool get _hasRating => rating != null && ratingCount > 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tone = JeebSurfaceTone.of(context);
    final muted = Theme.of(context).extension<JeebSemanticColors>()?.mutedText;

    final ratingText = (rating ?? 0).toStringAsFixed(1);
    final label = _hasRating
        ? l10n.deliveryManProfileRatingSummary(ratingText, ratingCount)
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
            _hasRating ? Icons.star_rounded : Icons.star_border_rounded,
            size: Sizes.medium,
            color: tone.titleInk,
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
