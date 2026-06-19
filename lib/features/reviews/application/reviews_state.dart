import 'package:equatable/equatable.dart';

import '../domain/reviews_repository.dart';

/// Top-level UI status for reviews-list (JM-068) — the canonical 4-state machine
/// (40_GUARDRAILS_ARCH §2.1 / §3; the D30 contract, 42_GUARDRAILS_MOCK §5.1).
/// `empty` is NOT a fifth status: it is `loaded` + an empty
/// [ReviewsState.reviews].
enum ReviewsStatus {
  /// Cold load — nothing fetched yet.
  initial,

  /// First page is on the wire (full-screen skeletons, D73).
  loading,

  /// At least the first page has landed. A refresh / load-more keeps us here.
  loaded,

  /// Cold load (page 1) failed and there is nothing to show.
  failed,
}

/// One-shot status of a per-row report action (D27). Separate from the screen
/// [ReviewsStatus] (40_GUARDRAILS_ARCH §2.1) so the report's snackbar fires
/// without re-triggering the list state machine.
enum ReportStatus { idle, inFlight, succeeded, failed }

/// Immutable state for the reviews list (JM-068).
///
/// [reviews] is the accumulated, paginated list (the cubit owns the order, R1m
/// serves it newest-first). [page]/[hasMore] drive infinite scroll (D73 —
/// scroll-end appends the next page). [coldStart] is the D59 aggregate gate: when
/// `true` the screen HIDES the average score and shows the "New" badge +
/// hidden-score note ([reviewCount] < 5). [error] is a typed [ReviewsFailure]
/// from the last FOREGROUND action (cold load / refresh) — never a raw exception
/// or string. A background load-more failure is held in [loadMoreError] (a soft,
/// retryable footer) so it does not tear down the already-rendered list.
/// [reportStatus] + [reportingReviewId] drive the one-shot report side-effect.
class ReviewsState extends Equatable {
  const ReviewsState({
    this.status = ReviewsStatus.initial,
    this.reviews = const <ReviewItem>[],
    this.page = 0,
    this.hasMore = false,
    this.loadingMore = false,
    this.error,
    this.loadMoreError = false,
    this.coldStart = false,
    this.reviewCount = 0,
    this.averageScore,
    this.reportStatus = ReportStatus.idle,
    this.reportingReviewId,
  });

  final ReviewsStatus status;

  /// Accumulated review rows in display order (newest first).
  final List<ReviewItem> reviews;

  /// The highest page index successfully fetched (1-based; 0 = none yet).
  final int page;

  /// Whether a further page exists (drives infinite scroll).
  final bool hasMore;

  /// A next-page fetch is in flight (drives the in-list skeleton, de-dupes).
  final bool loadingMore;

  /// One-shot typed error from the last cold load / refresh.
  final ReviewsFailure? error;

  /// A load-more page fetch failed — a soft, retryable footer state that leaves
  /// the already-loaded rows intact.
  final bool loadMoreError;

  /// D59 — jeeber has < 5 ratings: hide the aggregate score, show the New badge.
  final bool coldStart;

  /// Total rating count for the jeeber (the count label + New-badge gate).
  final int reviewCount;

  /// Rounded aggregate score, or `null` when [coldStart] (D59 hidden).
  final double? averageScore;

  /// One-shot status of the per-row report action (D27).
  final ReportStatus reportStatus;

  /// The review id currently being reported (for the one-shot snackbar copy).
  final String? reportingReviewId;

  bool get hasReviews => reviews.isNotEmpty;

  ReviewsState copyWith({
    ReviewsStatus? status,
    List<ReviewItem>? reviews,
    int? page,
    bool? hasMore,
    bool? loadingMore,
    ReviewsFailure? error,
    bool clearError = false,
    bool? loadMoreError,
    bool? coldStart,
    int? reviewCount,
    double? averageScore,
    bool clearAverageScore = false,
    ReportStatus? reportStatus,
    String? reportingReviewId,
    bool clearReportingReviewId = false,
  }) {
    return ReviewsState(
      status: status ?? this.status,
      reviews: reviews ?? this.reviews,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
      loadMoreError: loadMoreError ?? this.loadMoreError,
      coldStart: coldStart ?? this.coldStart,
      reviewCount: reviewCount ?? this.reviewCount,
      averageScore:
          clearAverageScore ? null : (averageScore ?? this.averageScore),
      reportStatus: reportStatus ?? this.reportStatus,
      reportingReviewId: clearReportingReviewId
          ? null
          : (reportingReviewId ?? this.reportingReviewId),
    );
  }

  @override
  List<Object?> get props => [
        status,
        reviews,
        page,
        hasMore,
        loadingMore,
        error,
        loadMoreError,
        coldStart,
        reviewCount,
        averageScore,
        reportStatus,
        reportingReviewId,
      ];
}
