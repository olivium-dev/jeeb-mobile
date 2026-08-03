import 'package:equatable/equatable.dart';

import '../domain/reviews_repository.dart';

enum ReviewsStatus {
  initial,

  loading,

  loaded,

  failed,
}

enum ReportStatus { idle, inFlight, succeeded, failed }

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

  final List<ReviewItem> reviews;

  final int page;

  final bool hasMore;

  final bool loadingMore;

  final ReviewsFailure? error;

  final bool loadMoreError;

  final bool coldStart;

  final int reviewCount;

  final double? averageScore;

  final ReportStatus reportStatus;

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
