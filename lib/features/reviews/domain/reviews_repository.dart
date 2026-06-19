// PURE Dart. No Flutter / Dio / GetIt imports (40_GUARDRAILS_ARCH §1 layer rules).
//
// Reviews-list domain contract (JM-068). The per-jeeber reviews source (R1m) is
// backend-owned; the LIVE shape is `GET /v1/ratings/jeeb/reviews?jeeberId=`
// (42_GUARDRAILS_MOCK "FINAL WAVE … R1m"). The DI default stays the
// INTEGRATOR-STUB (`injection_container.dart`, CTO-D2) until R1m is verified
// end-to-end against :4010; the screen renders its content/pagination state from
// either binding because they implement this same contract.
//
// Decisions: D58 (reviewer first name ONLY), D59 (cold-start hide score < 5 +
// "New" badge), D27 (report a review), D73 (skeletons / infinite scroll).

/// A single review row (`review_<id>`).
///
/// Attribution is the reviewer's FIRST NAME only (D58 — never a full name); the
/// wire field is `reviewerFirstName`. [score] is the 0–5 star value (the R1m
/// `score`). [reportable] gates the per-row `review_<id>_report_cta` (D27); R1m
/// returns `true` for every row.
class ReviewItem {
  const ReviewItem({
    required this.id,
    required this.reviewerFirstName,
    required this.score,
    required this.timestamp,
    this.body,
    this.reportable = true,
  });

  final String id;
  final String reviewerFirstName;
  final double score;

  /// ISO-8601 timestamp string (R1m `createdAt`/`ts`). The presentation layer
  /// formats it for display; kept raw here so `domain/` stays Flutter-free.
  final String timestamp;

  /// The free-text review comment (R1m `body`). Optional — a star-only rating
  /// has no body.
  final String? body;

  /// Whether this row exposes a report affordance (D27). R1m → always `true`.
  final bool reportable;
}

/// One page of the paginated reviews list, plus the D59 cold-start aggregate
/// gate.
///
/// [coldStart] is `true` while the jeeber has fewer than the cold-start
/// threshold of ratings (R1m `coldStart`, derived from `reviewCount < 5`, D59).
/// When cold-start the UI HIDES the aggregate [averageScore] (R1m returns it
/// `null`) and shows the "New" badge + a "few reviews yet" note — the individual
/// rows still render. [reviewCount] is the jeeber's total rating count (R1m
/// `reviewCount`), used for the count label and the New-badge gate.
class ReviewsPage {
  const ReviewsPage({
    required this.reviews,
    required this.page,
    required this.totalPages,
    this.coldStart = false,
    this.reviewCount = 0,
    this.averageScore,
  });

  final List<ReviewItem> reviews;
  final int page;
  final int totalPages;

  /// D59 — jeeber has < 5 ratings: hide the aggregate score, show the New badge.
  final bool coldStart;

  /// Total rating count for the jeeber (R1m `reviewCount`).
  final int reviewCount;

  /// The rounded aggregate score, or `null` when [coldStart] (D59 hidden).
  final double? averageScore;

  bool get hasMore => page < totalPages;
}

enum ReviewsFailure { network, notFound, unauthorized, unknown }

class ReviewsRepositoryException implements Exception {
  const ReviewsRepositoryException(this.failure, [this.message]);

  final ReviewsFailure failure;
  final String? message;

  @override
  String toString() => 'ReviewsRepositoryException($failure, $message)';
}

/// Domain contract for the all-reviews list (JM-068).
abstract class ReviewsRepository {
  /// Fetch one page of a jeeber's reviews (R1m). Throws
  /// [ReviewsRepositoryException] on failure.
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page,
    int pageSize,
  });

  /// Report a review for moderation (D27). Throws
  /// [ReviewsRepositoryException] on failure.
  Future<void> reportReview(String reviewId);
}
