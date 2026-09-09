import 'package:equatable/equatable.dart';

import '../../../core/network/app_failure.dart';
import '../domain/delivery_man_profile_view_data.dart';

enum DeliveryManProfileReviewsStatus { initial, loading, loaded, failed }

class DeliveryManProfileReviewsState extends Equatable {
  const DeliveryManProfileReviewsState({
    this.status = DeliveryManProfileReviewsStatus.initial,
    this.reviews = const <DeliveryReviewData>[],
    this.reviewCount = 0,
    this.hasMore = false,
    this.error,
    this.refreshError,
    this.averageScore,
    this.hasFreshSummary = false,
  });

  final DeliveryManProfileReviewsStatus status;
  final List<DeliveryReviewData> reviews;
  final int reviewCount;
  final double? averageScore;
  final bool hasFreshSummary;
  bool get coldStart =>
      reviewCount < DeliveryManProfileViewData.coldStartThreshold ||
      averageScore == null;
  final bool hasMore;

  /// The cold failure that owns the reviews band.
  final AppFailure? error;

  /// A refresh that failed with reviews already on screen.
  final AppFailure? refreshError;

  bool get isLoading => status == DeliveryManProfileReviewsStatus.loading;

  /// The count line is a claim about loaded data: suppress it otherwise.
  bool get showCount =>
      status == DeliveryManProfileReviewsStatus.loaded && reviewCount > 0;

  DeliveryManProfileReviewsState copyWith({
    DeliveryManProfileReviewsStatus? status,
    List<DeliveryReviewData>? reviews,
    int? reviewCount,
    bool? hasMore,
    AppFailure? error,
    AppFailure? refreshError,
    bool clearError = false,
    bool clearRefreshError = false,
    double? averageScore,
    bool clearAverageScore = false,
    bool? hasFreshSummary,
  }) {
    return DeliveryManProfileReviewsState(
      status: status ?? this.status,
      reviews: reviews ?? this.reviews,
      reviewCount: reviewCount ?? this.reviewCount,
      averageScore: clearAverageScore
          ? null
          : (averageScore ?? this.averageScore),
      hasFreshSummary: hasFreshSummary ?? this.hasFreshSummary,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? error : (error ?? this.error),
      refreshError: clearRefreshError
          ? refreshError
          : (refreshError ?? this.refreshError),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    status,
    reviews,
    reviewCount,
    averageScore,
    hasFreshSummary,
    hasMore,
    error,
    refreshError,
  ];
}
