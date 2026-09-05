import 'package:flutter/foundation.dart';

import '../../../core/dev_seam/dev_seam.dart';
import '../../../core/dev_seam/dev_seam_config.dart';
import '../domain/reviews_repository.dart';

class StubReviewsRepository implements ReviewsRepository {
  const StubReviewsRepository();

  static const int _pageOneCount = 7;
  static const int _pageTwoCount = 3;
  static const int _totalPages = 2;
  static const int _reviewCount = 10; // >= 5 -> not cold-start (D59).
  static const double _averageScore = 4.6;

  static const int _coldStartCount = 2;

  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final clampedPage = page < 1 ? 1 : page;

    if (kDebugMode &&
        DevSeam.current.journeySeed == JourneySeed.jeeberColdStartProfile) {
      final count = clampedPage == 1 ? _coldStartCount : 0;
      return ReviewsPage(
        reviews: _buildPage(clampedPage, count),
        page: clampedPage,
        totalPages: 1,
        coldStart: true,
        reviewCount: _coldStartCount,
        averageScore: null,
      );
    }

    final count = switch (clampedPage) {
      1 => _pageOneCount,
      2 => _pageTwoCount,
      _ => 0,
    };
    return ReviewsPage(
      reviews: _buildPage(clampedPage, count),
      page: clampedPage,
      totalPages: _totalPages,
      coldStart: false,
      reviewCount: _reviewCount,
      averageScore: _averageScore,
    );
  }

  @override
  Future<void> reportReview(String reviewId) async {}

  List<ReviewItem> _buildPage(int page, int count) {
    const names = <String>[
      'Sami',
      'Lina',
      'Omar',
      'Maya',
      'Karim',
      'Rana',
      'Tarek',
    ];
    const bodies = <String?>[
      'Fast and friendly.',
      'Good service, arrived on time.',
      null,
      'Very careful with the package.',
      'Great communication throughout.',
      'Would order again.',
      'Polite and professional.',
    ];
    return List<ReviewItem>.unmodifiable(
      List<ReviewItem>.generate(count, (i) {
        final index = (page - 1) * 100 + i + 1;
        return ReviewItem(
          id: 'review-${index.toString().padLeft(3, '0')}',
          reviewerFirstName: names[i % names.length],
          score: (5 - (i % 2)).toDouble(),
          timestamp: DateTime.utc(
            2026,
            6,
            18,
            12,
          ).subtract(Duration(days: index)).toIso8601String(),
          body: bodies[i % bodies.length],
        );
      }),
    );
  }
}
