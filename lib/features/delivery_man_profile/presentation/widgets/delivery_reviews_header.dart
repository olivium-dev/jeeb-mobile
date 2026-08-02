import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

import '../../../../core/previews/jeeb_preview.dart';
import '../../domain/delivery_man_profile_view_data.dart';
import 'delivery_reviews_list.dart';

/// "Reviews" heading + (count · View all) row above the review list.
class DeliveryReviewsHeader extends StatelessWidget {
  const DeliveryReviewsHeader({
    super.key,
    required this.reviewCount,
    required this.onViewAll,
  });

  final int reviewCount;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.large,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ReviewsTitle(),
          const SizedBox(height: Spacing.xSmall),
          _CountAndViewAll(reviewCount: reviewCount, onViewAll: onViewAll),
        ],
      ),
    );
  }
}

class _ReviewsTitle extends StatelessWidget {
  const _ReviewsTitle();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Text(
      l10n.deliveryManProfileReviewsTitle,
      style: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _CountAndViewAll extends StatelessWidget {
  const _CountAndViewAll({required this.reviewCount, required this.onViewAll});

  final int reviewCount;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            l10n.deliveryManProfileReviewsCount(reviewCount),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ),
        _ViewAllButton(label: l10n.deliveryManProfileViewAllReviews, onTap: onViewAll),
      ],
    );
  }
}

class _ViewAllButton extends StatelessWidget {
  const _ViewAllButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Canonical id per JM-067 AC.
    return Semantics(
      identifier: 'profile_view_all_reviews',
      button: true,
      child: OmdsPrimaryButton(
        key: const Key('delivery-man-profile-view-all'),
        text: label,
        onTap: onTap,
        variant: OmdsButtonVariant.text,
      ),
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// Stateless widget: reviewCount input only, network-free by construction.

/// Phone width (390 pt design).
const double _deliveryReviewsHeaderPhoneWidth = 390;

/// Narrowest width (iPhone SE / small Android).
const double _deliveryReviewsHeaderNarrowPhoneWidth = 320;

/// Canvas boxes.
const Size _deliveryReviewsHeaderBox = Size(_deliveryReviewsHeaderPhoneWidth, 130);
const Size _deliveryReviewsHeaderLargeTextBox = Size(_deliveryReviewsHeaderPhoneWidth, 300);
const Size _deliveryReviewsHeaderWithListBox = Size(_deliveryReviewsHeaderPhoneWidth, 420);

/// Header hosted in [ListView]; width/textScale pinned in tree.
Widget _deliveryReviewsHeaderHosted(
  int reviewCount, {
  double width = _deliveryReviewsHeaderPhoneWidth,
  double? textScale,
  Widget? below,
}) {
  final Widget column = Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      DeliveryReviewsHeader(
        reviewCount: reviewCount,
        onViewAll: () {},
      ),
      ?below,
    ],
  );

  final Widget sized = Align(
    alignment: AlignmentDirectional.topStart,
    child: SizedBox(
      width: width,
      child: SingleChildScrollView(child: column),
    ),
  );

  if (textScale == null) return sized;
  return Builder(
    builder: (BuildContext context) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: sized,
    ),
  );
}

/// Production baseline: 113 reviews.
@JeebPreview(group: 'delivery_man_profile', name: '113 reviews (production)', size: _deliveryReviewsHeaderBox)
Widget deliveryReviewsHeaderProduction() => _deliveryReviewsHeaderHosted(113);

/// Cold start: 0 reviews (production state).
@JeebPreview(group: 'delivery_man_profile', name: 'Cold start · 0 reviews', size: _deliveryReviewsHeaderBox)
Widget deliveryReviewsHeaderColdStart() => _deliveryReviewsHeaderHosted(0);

/// Pluralization defect ("1 Reviews").
@JeebPreview(group: 'delivery_man_profile', name: 'Single review · "1 Reviews"', size: _deliveryReviewsHeaderBox)
Widget deliveryReviewsHeaderSingleReview() => _deliveryReviewsHeaderHosted(1);

/// Six figures on narrowest phone (128450).
@JeebPreview(group: 'delivery_man_profile', name: 'Six figures · 320 pt', size: _deliveryReviewsHeaderBox)
Widget deliveryReviewsHeaderSixFigures() =>
    _deliveryReviewsHeaderHosted(128450, width: _deliveryReviewsHeaderNarrowPhoneWidth);

/// Layout ceiling at 200% text on 320 pt (count wraps).
@JeebPreview(group: 'delivery_man_profile', name: 'Narrow · 200% text', size: _deliveryReviewsHeaderLargeTextBox)
Widget deliveryReviewsHeaderNarrowLargeText() =>
    _deliveryReviewsHeaderHosted(47, width: _deliveryReviewsHeaderNarrowPhoneWidth, textScale: 2.0);

/// Header above empty list (spatial review).
@JeebPreview(group: 'delivery_man_profile', name: 'Above the empty list', size: _deliveryReviewsHeaderWithListBox)
Widget deliveryReviewsHeaderAboveEmptyList() => _deliveryReviewsHeaderHosted(
  0,
  below: const DeliveryReviewsList(reviews: <DeliveryReviewData>[]),
);
