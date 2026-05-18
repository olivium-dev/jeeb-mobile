import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

/// Lightweight presentation-only model for a single recent review.
///
/// Mirrors the subset of fields [OmdsReviewCard] needs. The real data layer
/// (a `RatingsRepository` exposing `Stream<List<Review>>`) does not yet exist
/// in `jeeb-mobile`; tracked under `T-MOB-RATING-001`. When the data feature
/// lands, map the domain entity to this model at the screen boundary — keep
/// this widget free of domain types so it stays Storybook-friendly.
class RecentReviewPreview {
  const RecentReviewPreview({
    required this.userName,
    required this.rating,
    required this.reviewText,
    required this.timeAgo,
    this.userImageUrl,
    this.isVerifiedPurchase = false,
  });

  final String userName;
  final double rating;
  final String reviewText;
  final String timeAgo;
  final String? userImageUrl;
  final bool isVerifiedPurchase;
}

/// Reviews preview block for the rating screens.
///
/// Renders an [OmdsSectionHeader] ("Reviews (N)" + optional "View all" CTA)
/// followed by up to [maxItems] [OmdsReviewCard] entries. Returns a zero-size
/// widget when [reviews] is empty so the parent can use it unconditionally.
class RecentReviewsSection extends StatelessWidget {
  const RecentReviewsSection({
    super.key,
    required this.reviews,
    this.onViewAllTap,
    this.maxItems = 3,
    this.title = 'Reviews',
    this.viewAllText = 'View all',
  });

  final List<RecentReviewPreview> reviews;
  final VoidCallback? onViewAllTap;
  final int maxItems;
  final String title;
  final String viewAllText;

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) return const SizedBox.shrink();
    final visible = reviews.take(maxItems).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReviewsHeader(
          title: title,
          count: reviews.length,
          viewAllText: viewAllText,
          onViewAllTap: onViewAllTap,
        ),
        const SizedBox(height: Spacing.xSmall),
        for (final review in visible) _ReviewCardItem(review: review),
      ],
    );
  }
}

class _ReviewsHeader extends StatelessWidget {
  const _ReviewsHeader({
    required this.title,
    required this.count,
    required this.viewAllText,
    required this.onViewAllTap,
  });

  final String title;
  final int count;
  final String viewAllText;
  final VoidCallback? onViewAllTap;

  @override
  Widget build(BuildContext context) {
    return OmdsSectionHeader(
      title: '$title ($count)',
      showAllText: viewAllText,
      onShowAllTap: onViewAllTap,
      showShowAll: onViewAllTap != null,
    );
  }
}

class _ReviewCardItem extends StatelessWidget {
  const _ReviewCardItem({required this.review});

  final RecentReviewPreview review;

  @override
  Widget build(BuildContext context) {
    return OmdsReviewCard(
      userName: review.userName,
      rating: review.rating,
      reviewText: review.reviewText,
      timeAgo: review.timeAgo,
      userImageUrl: review.userImageUrl,
      isVerifiedPurchase: review.isVerifiedPurchase,
      showActions: false,
    );
  }
}
