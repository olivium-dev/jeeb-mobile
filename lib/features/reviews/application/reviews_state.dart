import 'package:equatable/equatable.dart';

import '../../../core/network/app_failure.dart';
import '../domain/reviews_repository.dart';

enum ReviewsStatus { initial, loading, loaded, failed }

enum ReportStatus { idle, inFlight, succeeded, failed }

class ReviewsState extends Equatable {
  const ReviewsState({
    this.status = ReviewsStatus.initial,
    this.reviews = const <ReviewItem>[],
    this.page = 0,
    this.hasMore = false,
    this.loadingMore = false,
    this.error,
    this.appFailure,
    this.refreshError,
    this.loadMoreFailure,
    this.reportFailure,
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

  /// The classified cold-read failure.
  final AppFailure? appFailure;

  /// A refresh that failed over rows already on screen.
  final AppFailure? refreshError;

  /// The classified pagination failure.
  final AppFailure? loadMoreFailure;

  /// The classified report-review failure.
  final AppFailure? reportFailure;

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
    AppFailure? appFailure,
    AppFailure? refreshError,
    bool clearRefreshError = false,
    AppFailure? loadMoreFailure,
    bool clearLoadMoreFailure = false,
    AppFailure? reportFailure,
    bool clearReportFailure = false,
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
      appFailure: clearError ? null : (appFailure ?? this.appFailure),
      refreshError: clearRefreshError
          ? null
          : (refreshError ?? this.refreshError),
      loadMoreFailure: clearLoadMoreFailure
          ? null
          : (loadMoreFailure ?? this.loadMoreFailure),
      reportFailure: clearReportFailure
          ? null
          : (reportFailure ?? this.reportFailure),
      loadMoreError: loadMoreError ?? this.loadMoreError,
      coldStart: coldStart ?? this.coldStart,
      reviewCount: reviewCount ?? this.reviewCount,
      averageScore: clearAverageScore
          ? null
          : (averageScore ?? this.averageScore),
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
    appFailure,
    refreshError,
    loadMoreFailure,
    reportFailure,
    loadMoreError,
    coldStart,
    reviewCount,
    averageScore,
    reportStatus,
    reportingReviewId,
  ];
}
