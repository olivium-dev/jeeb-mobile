import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/delivery_man_profile_view_data.dart';
import 'delivery_review_card.dart';








class DeliveryReviewsList extends StatelessWidget {
  const DeliveryReviewsList({super.key, required this.reviews});

  final List<DeliveryReviewData> reviews;

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) return const _EmptyReviews();
    return ListView.separated(
      key: const Key('delivery-man-profile-reviews-list'),
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.large,
        Spacing.medium,
        Spacing.large,
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
    return Padding(
      padding: const EdgeInsetsDirectional.all(Spacing.large),
      child: OmdsEmptyState(
        key: const Key('delivery-man-profile-reviews-empty'),
        icon: Icons.reviews_outlined,
        title: l10n.deliveryManProfileEmptyReviewsTitle,
        subtitle: l10n.deliveryManProfileEmptyReviewsSubtitle,
      ),
    );
  }
}
