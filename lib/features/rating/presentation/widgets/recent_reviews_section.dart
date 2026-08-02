import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/previews/jeeb_preview.dart';

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
// ============================== JEEB PREVIEWS ==============================
const double _recentReviewsSectionPhoneWidth = 390;

/// Horizontal gutter for content column.
const double _recentReviewsSectionGutter = Spacing.large;

/// Canvas box: three cards plus header.
const Size _recentReviewsSectionFeedBox = Size(390, 540);

/// A single card plus its header (215 px measured).
const Size _recentReviewsSectionSingleBox = Size(390, 230);

/// The empty state collapses to nothing; the box only has to ho
const Size _recentReviewsSectionEmptyBox = Size(390, 120);

/// Two cards of Arabic content (406 px measured).
const Size _recentReviewsSectionArabicBox = Size(390, 430);

/// The longest plausible review: a wrapped name over a four-lin
const Size _recentReviewsSectionTallBox = Size(390, 520);

/// The Figma comp's review body, as `DevDeliveryManProfileFixtu
const String _recentReviewsSectionLorem =
    'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed ut leo '
    'facilisis, mollis dolor bibendum, tempor dolor. Lorem ipsum dolor sit '
    'amet, consectetur adipiscing elit.';

/// Three reviews as feedback-service would hand them over, usin
const List<RecentReviewPreview> _recentReviewsSectionFeed =
    <RecentReviewPreview>[
  RecentReviewPreview(
    userName: 'Karl Assaf',
    rating: 4,
    reviewText: 'Great delivery, fast and friendly.',
    timeAgo: '2 days ago',
    userImageUrl: 'https://i.pravatar.cc/150?img=15',
    isVerifiedPurchase: true,
  ),
  RecentReviewPreview(
    userName: 'Rami Khoury',
    rating: 4.5,
    reviewText: 'Arrived on time, but the bag was a little squashed.',
    timeAgo: '12 days ago',
  ),
  RecentReviewPreview(
    userName: 'Nadia Chehab',
    rating: 5,
    reviewText: '',
    timeAgo: '3 weeks ago',
  ),
];

/// Twelve reviews — what a jeeber with a few months on the plat
List<RecentReviewPreview> _recentReviewsSectionHistory() =>
    <RecentReviewPreview>[
      ..._recentReviewsSectionFeed,
      for (int week = 4; week <= 12; week++)
        RecentReviewPreview(
          userName: 'Client $week',
          rating: 4,
          reviewText: 'Older review from $week weeks ago.',
          timeAgo: '$week weeks ago',
        ),
    ];

/// Hosts the section the way a rating screen does: a fixed-widt
Widget _recentReviewsSectionHosted(
  Widget child, {
  double width = _recentReviewsSectionPhoneWidth,
  String? caption,
}) => Align(
      alignment: AlignmentDirectional.topStart,
      child: SizedBox(
        width: width,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: _recentReviewsSectionGutter,
            vertical: Spacing.medium,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              child,
              if (caption != null) ...<Widget>[
                const SizedBox(height: Spacing.small),
                Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

/// The state a rating screen is designed around: three recent r
@JeebPreview(
  group: 'rating',
  name: 'Three reviews, view all',
  size: _recentReviewsSectionFeedBox,
)
Widget recentReviewsSectionThreeReviews() => _recentReviewsSectionHosted(
      RecentReviewsSection(
        reviews: _recentReviewsSectionFeed,
        onViewAllTap: () {},
      ),
    );

/// The empty state, which is the one a parent is most likely to
@JeebPreview(
  group: 'rating',
  name: 'Empty (renders nothing)',
  size: _recentReviewsSectionEmptyBox,
)
Widget recentReviewsSectionEmpty() => _recentReviewsSectionHosted(
      Builder(
        builder: (BuildContext context) => DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: const RecentReviewsSection(
            reviews: <RecentReviewPreview>[],
          ),
        ),
      ),
      caption: 'Empty list — the section collapses to zero height',
    );

/// Defect 2 above, made visible: twelve reviews, three cards, o
@JeebPreview(
  group: 'rating',
  name: 'Twelve reviews, three shown',
  size: _recentReviewsSectionFeedBox,
)
Widget recentReviewsSectionTruncated() => _recentReviewsSectionHosted(
      RecentReviewsSection(
        reviews: _recentReviewsSectionHistory(),
        onViewAllTap: () {},
      ),
    );

/// No `onViewAllTap`, so the header suppresses its own CTA (`sh
@JeebPreview(
  group: 'rating',
  name: 'No view-all CTA',
  size: _recentReviewsSectionSingleBox,
)
Widget recentReviewsSectionNoViewAll() => _recentReviewsSectionHosted(
      const RecentReviewsSection(
        reviews: <RecentReviewPreview>[
          RecentReviewPreview(
            userName: 'Tarek Aoun',
            rating: 3,
            reviewText: 'Took a while to find the building.',
            timeAgo: '30 days ago',
          ),
        ],
      ),
    );

/// Layout ceiling: the longest plausible name, the Figma lorem 
@JeebPreview(
  group: 'rating',
  name: 'Long name and body',
  size: _recentReviewsSectionTallBox,
  matrix: true,
)
Widget recentReviewsSectionLongContent() => _recentReviewsSectionHosted(
      RecentReviewsSection(
        reviews: const <RecentReviewPreview>[
          RecentReviewPreview(
            userName: 'Abdulrahman Al-Muhandis Al-Trabulsi',
            rating: 5,
            reviewText: _recentReviewsSectionLorem,
            timeAgo: '365 days ago',
            isVerifiedPurchase: true,
          ),
        ],
        onViewAllTap: () {},
      ),
    );

/// An Arabic reviewer, which is the majority case in Lebanon an
@JeebPreview(
  group: 'rating',
  name: 'Arabic reviewer',
  size: _recentReviewsSectionArabicBox,
  matrix: true,
)
Widget recentReviewsSectionArabicReviewer() => _recentReviewsSectionHosted(
      RecentReviewsSection(
        reviews: const <RecentReviewPreview>[
          RecentReviewPreview(
            userName: 'ليلى الحاج',
            rating: 5,
            reviewText: 'وصل الطلب بسرعة والسائق كان لطيفاً جداً.',
            timeAgo: '2 days ago',
            isVerifiedPurchase: true,
          ),
          RecentReviewPreview(
            userName: 'عبد الرحمن المهندس',
            rating: 4,
            reviewText: 'تأخر قليلاً بسبب الزحمة لكن الطلب وصل سليماً.',
            timeAgo: '5 days ago',
          ),
        ],
        onViewAllTap: () {},
      ),
    );
