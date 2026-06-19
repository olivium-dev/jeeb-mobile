import 'package:flutter/foundation.dart';

import '../../../core/dev_seam/dev_seam.dart';
import '../../../core/dev_seam/dev_seam_config.dart';
import '../domain/reviews_repository.dart';

/// INTEGRATOR-STUB(JM-068): the per-jeeber reviews source (R1m) is wired to
/// :4010 in `DioReviewsRepository`, but per CTO-D2 the DI default stays this
/// in-memory stub until R1m is verified end-to-end against the mock. The reviews
/// list (`ReviewsListScreen`, JM-068) + the inbound `profile_view_all_reviews`
/// edge (JM-067) render their full content/pagination state against it NOW; the
/// data-bound ACs validate once DI is repointed.
///
/// DELIBERATELY a non-fake, DI-registerable stub (NOT a `Fake*` test seam, which
/// DO-NOT forbids in DI — 40_GUARDRAILS_ARCH §6/§12). Returns a deterministic
/// two-page list (first-name only, D58; `reportable:true`, D27) plus the D59
/// aggregate (non-cold-start: an `averageScore` is shown) so the screen exercises
/// the content state + infinite scroll.
///
/// SWAP WHEN R1m IS VERIFIED: replace the `injection_container.dart` registration
/// `StubReviewsRepository()` with `DioReviewsRepository(sl<Dio>())` — no screen
/// change (both honor the [ReviewsRepository] contract).
class StubReviewsRepository implements ReviewsRepository {
  const StubReviewsRepository();

  static const int _pageOneCount = 7;
  static const int _pageTwoCount = 3;
  static const int _totalPages = 2;
  static const int _reviewCount = 10; // >= 5 -> not cold-start (D59).
  static const double _averageScore = 4.6;

  // D59 cold-start posture (< 5 reviews) — the score is hidden + a "New" badge
  // shows. JM-068 AC2b exercises this via `jeeb.seam.journey=
  // jeeber_cold_start_profile`; the stub reads that debug seam so the SAME stub
  // serves both the populated (AC1/2/3) and the cold-start (AC2b) branches.
  static const int _coldStartCount = 2;

  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final clampedPage = page < 1 ? 1 : page;

    // JM-068 AC2b cold-start branch (debug-only): a profile with < 5 reviews
    // hides the aggregate score + shows the New badge / hidden-score note.
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
  Future<void> reportReview(String reviewId) async {
    // No-op until R1m: the LIVE impl POSTs `/v1/ratings/jeeb/reviews/:id/report`.
  }

  List<ReviewItem> _buildPage(int page, int count) {
    const names = <String>[
      'Sami', 'Lina', 'Omar', 'Maya', 'Karim', 'Rana', 'Tarek',
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
          timestamp: DateTime.utc(2026, 6, 18, 12)
              .subtract(Duration(days: index))
              .toIso8601String(),
          body: bodies[i % bodies.length],
        );
      }),
    );
  }
}
