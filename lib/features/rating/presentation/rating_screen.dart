import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import 'widgets/recent_reviews_section.dart';

/// Mock recent reviews used until the ratings data source lands. The real
/// stream is tracked under `T-MOB-RATING-001`; this list lets the layout be
/// designed and golden-tested today without blocking on the backend.
const List<RecentReviewPreview> _mockRecentReviews = <RecentReviewPreview>[
  RecentReviewPreview(
    userName: 'Layla A.',
    rating: 5.0,
    reviewText: 'Arrived right on time and was very polite. Will request '
        'this Jeeber again next week.',
    timeAgo: '2 days ago',
    isVerifiedPurchase: true,
  ),
  RecentReviewPreview(
    userName: 'Omar K.',
    rating: 4.0,
    reviewText: 'Smooth handover. Took a slightly different route than I '
        'expected but everything arrived intact.',
    timeAgo: '1 week ago',
    isVerifiedPurchase: true,
  ),
  RecentReviewPreview(
    userName: 'Noor H.',
    rating: 5.0,
    reviewText: 'Communicated proactively about traffic delays. Five stars.',
    timeAgo: '3 weeks ago',
  ),
];

class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key, required this.deliveryId});

  final String deliveryId;

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _stars = 0;
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _onStarsChanged(int value) => setState(() => _stars = value);

  void _onSubmit() => Navigator.of(context).pop(<String, Object?>{
        'stars': _stars,
        'comment': _commentController.text,
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const OMDSAppBar(title: 'Rate Delivery', showBackButton: true),
      body: _RatingScreenBody(
        stars: _stars,
        onStarsChanged: _onStarsChanged,
        commentController: _commentController,
        onSubmit: _onSubmit,
        recentReviews: _mockRecentReviews,
      ),
    );
  }
}

class _RatingScreenBody extends StatelessWidget {
  const _RatingScreenBody({
    required this.stars,
    required this.onStarsChanged,
    required this.commentController,
    required this.onSubmit,
    required this.recentReviews,
  });

  final int stars;
  final ValueChanged<int> onStarsChanged;
  final TextEditingController commentController;
  final VoidCallback onSubmit;
  final List<RecentReviewPreview> recentReviews;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Spacing.medium),
              child: _RatingScrollContent(
                stars: stars,
                onStarsChanged: onStarsChanged,
                commentController: commentController,
                recentReviews: recentReviews,
              ),
            ),
          ),
          _RatingFooter(stars: stars, onSubmit: onSubmit),
        ],
      ),
    );
  }
}

class _RatingScrollContent extends StatelessWidget {
  const _RatingScrollContent({
    required this.stars,
    required this.onStarsChanged,
    required this.commentController,
    required this.recentReviews,
  });

  final int stars;
  final ValueChanged<int> onStarsChanged;
  final TextEditingController commentController;
  final List<RecentReviewPreview> recentReviews;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (recentReviews.isNotEmpty) ...[
          RecentReviewsSection(reviews: recentReviews),
          const SizedBox(height: Spacing.xLarge),
        ],
        const _RatingPromptHeader(),
        const SizedBox(height: Spacing.xLarge),
        _RatingStarInput(stars: stars, onChanged: onStarsChanged),
        const SizedBox(height: Spacing.xLarge),
        _RatingCommentField(controller: commentController),
      ],
    );
  }
}

class _RatingPromptHeader extends StatelessWidget {
  const _RatingPromptHeader();

  @override
  Widget build(BuildContext context) {
    return Text(
      'How was your experience?',
      style: Theme.of(context).textTheme.titleLarge,
      textAlign: TextAlign.center,
    );
  }
}

class _RatingStarInput extends StatelessWidget {
  const _RatingStarInput({required this.stars, required this.onChanged});

  final int stars;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: OmdsStarRating(
        rating: stars,
        starSize: Sizes.threeXLarge,
        onRatingChanged: onChanged,
      ),
    );
  }
}

class _RatingCommentField extends StatelessWidget {
  const _RatingCommentField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return OmdsTextField(
      controller: controller,
      labelText: 'Add a comment (optional)',
      maxLines: 4,
      maxLength: 1000,
    );
  }
}

class _RatingFooter extends StatelessWidget {
  const _RatingFooter({required this.stars, required this.onSubmit});

  final int stars;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.medium),
      child: OmdsPrimaryButton(
        text: 'Submit Rating',
        isEnabled: stars != 0,
        onTap: onSubmit,
      ),
    );
  }
}
