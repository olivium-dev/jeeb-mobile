import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/delivery_man_profile_view_data.dart';
import 'delivery_review_card.dart';

/// The list of review cards (or a [JeebEmptyState] when there are none).
/// Lazily built ([ListView.separated]) because a Jeeber can have hundreds of
/// reviews (design §5). Non-scrollable + shrink-wrapped: it lives inside the
/// page's single scroll view so the whole column scrolls as one.
///
/// redesign-2026-08: the list rides the board's 24px gutter and the cards are
/// separated by air alone — outlined cards are their own separation, so a
/// divider between two of them would draw a third line (R7/R12).
///
/// JM-067/D57: read-only — no Helpful/Reply callbacks (jeeber reviews are
/// immutable). D58: cards render the reviewer's first name only.
class DeliveryReviewsList extends StatelessWidget {
  const DeliveryReviewsList({super.key, required this.reviews});

  final List<DeliveryReviewData> reviews;

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) return const _EmptyReviews();
    return ListView.separated(
      key: const Key('delivery-man-profile-reviews-list'),
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Spacing.small,
        Spacing.xLarge,
        Spacing.large,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: reviews.length,
      separatorBuilder: (_, _) => const SizedBox(height: Spacing.small),
      itemBuilder: (context, index) =>
          DeliveryReviewCard(review: reviews[index], index: index),
    );
  }
}

class _EmptyReviews extends StatelessWidget {
  const _EmptyReviews();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // `parcel` (E4) is the board's "this record is still empty" subject, and
    // `compact` because this is a band inside the profile, not the screen.
    return Padding(
      padding: const EdgeInsetsDirectional.all(Spacing.xLarge),
      child: JeebEmptyState.compact(
        key: const Key('delivery-man-profile-reviews-empty'),
        identifier: 'delivery_man_profile_reviews_empty',
        variant: JeebEmptyStateVariant.parcel,
        headline: l10n.deliveryManProfileEmptyReviewsTitle,
        body: l10n.deliveryManProfileEmptyReviewsSubtitle,
      ),
    );
  }
}
