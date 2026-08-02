import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/delivery_man_profile_view_data.dart';
import 'delivery_review_card.dart';

import '../../../../core/previews/jeeb_preview.dart';

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
// ============================== JEEB PREVIEWS ==============================
const double _deliveryReviewsListPhoneWidth = 390;

/// Canvas boxes, sized to the state each one holds.
const Size _deliveryReviewsListTwoCardBox = Size(_deliveryReviewsListPhoneWidth, 320);
const Size _deliveryReviewsListOneCardBox = Size(_deliveryReviewsListPhoneWidth, 200);
const Size _deliveryReviewsListStarsOnlyBox = Size(_deliveryReviewsListPhoneWidth, 180);
const Size _deliveryReviewsListEmptyBox = Size(_deliveryReviewsListPhoneWidth, 320);
const Size _deliveryReviewsListLongBodyBox = Size(_deliveryReviewsListPhoneWidth, 280);

/// The Figma seed body (`DevDeliveryManProfileFixtures`) — the 
const String _deliveryReviewsListLorem =
    'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed ut leo '
    'facilisis, mollis dolor bibendum, tempor dolor. Lorem ipsum dolor sit '
    'amet, consectetur adipiscing elit.';

DeliveryReviewData _deliveryReviewsListReview({
  required String id,
  required String reviewerName,
  required String body,
  double rating = 4,
  int daysAgo = 2,
  bool isVerified = true,
  String? reviewerAvatarUrl,
}) => DeliveryReviewData(
  id: id,
  reviewerName: reviewerName,
  rating: rating,
  body: body,
  daysAgo: daysAgo,
  isVerified: isVerified,
  reviewerAvatarUrl: reviewerAvatarUrl,
  helpfulCount: 24,
);

/// One list, hosted the way `_DeliveryManProfileBody` hosts it.
Widget _deliveryReviewsListHosted(List<DeliveryReviewData> reviews) {
  return Align(
    alignment: AlignmentDirectional.topStart,
    child: SizedBox(
      width: _deliveryReviewsListPhoneWidth,
      child: SingleChildScrollView(
        child: DeliveryReviewsList(reviews: reviews),
      ),
    ),
  );
}

/// The default surface: the two-review list the Figma comp and 
@JeebPreview(group: 'delivery_man_profile', name: 'Two reviews', size: _deliveryReviewsListTwoCardBox)
Widget deliveryReviewsListTwoReviews() => _deliveryReviewsListHosted(<DeliveryReviewData>[
  _deliveryReviewsListReview(
    id: 'r1',
    reviewerName: 'Karl Assaf',
    body: 'Great delivery, fast and friendly.',
  ),
  _deliveryReviewsListReview(
    id: 'r2',
    reviewerName: 'Nour Haddad',
    rating: 5,
    body: 'Arrived early and called ahead.',
    daysAgo: 9,
  ),
]);

/// The other half of the widget: `reviews.isEmpty` replaces the
@JeebPreview(group: 'delivery_man_profile', name: 'Empty', size: _deliveryReviewsListEmptyBox)
Widget deliveryReviewsListEmpty() => _deliveryReviewsListHosted(const <DeliveryReviewData>[]);

/// Longest plausible content: the Figma seed body on a single c
@JeebPreview(group: 'delivery_man_profile', name: 'Long body', size: _deliveryReviewsListLongBodyBox)
Widget deliveryReviewsListLongBody() => _deliveryReviewsListHosted(<DeliveryReviewData>[
  _deliveryReviewsListReview(id: 'r1', reviewerName: 'Maroun Khoury', body: _deliveryReviewsListLorem),
]);

/// Privacy regression guard, made visible (`delivery_review_car
@JeebPreview(group: 'delivery_man_profile', name: 'Anonymous reviewer', size: _deliveryReviewsListOneCardBox)
Widget deliveryReviewsListAnonymous() => _deliveryReviewsListHosted(<DeliveryReviewData>[
  _deliveryReviewsListReview(
    id: 'anonymous',
    reviewerName: '   ',
    body: 'Great delivery.',
    reviewerAvatarUrl: 'https://example.com/private-avatar.png',
  ),
]);

/// A star-only review from an unverified client: `body` is empt
@JeebPreview(group: 'delivery_man_profile', name: 'Stars only', size: _deliveryReviewsListStarsOnlyBox)
Widget deliveryReviewsListStarsOnly() => _deliveryReviewsListHosted(<DeliveryReviewData>[
  _deliveryReviewsListReview(
    id: 'r1',
    reviewerName: 'Rania Sfeir',
    rating: 3.5,
    body: '',
    daysAgo: 30,
    isVerified: false,
  ),
]);

/// Layout ceiling: a year-old review from a long-named client —
@JeebPreview(group: 'delivery_man_profile', name: 'Year-old review', size: _deliveryReviewsListOneCardBox)
Widget deliveryReviewsListYearOld() => _deliveryReviewsListHosted(<DeliveryReviewData>[
  _deliveryReviewsListReview(
    id: 'r1',
    reviewerName: 'Abdulrahman Al-Muhandis',
    rating: 5,
    body: 'Handled a bulky order without a scratch.',
    daysAgo: 365,
  ),
]);
