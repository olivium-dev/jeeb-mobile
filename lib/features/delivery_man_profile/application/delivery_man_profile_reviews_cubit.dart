import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/app_failure.dart';
import '../domain/delivery_man_profile_repository.dart';
import '../domain/delivery_man_profile_view_data.dart';
import 'delivery_man_profile_reviews_state.dart';

/// Loads a jeeber's public reviews. Seeded from the pushed value object so the
/// catalog and the preview fixtures still render with no repository at all.
class DeliveryManProfileReviewsCubit
    extends Cubit<DeliveryManProfileReviewsState> {
  DeliveryManProfileReviewsCubit({
    DeliveryManProfileRepository? repository,
    this.jeeberId,
    List<DeliveryReviewData> seedReviews = const <DeliveryReviewData>[],
    int seedReviewCount = 0,
  })  : _repository = repository,
        super(
          seedReviews.isEmpty
              ? const DeliveryManProfileReviewsState()
              : DeliveryManProfileReviewsState(
                  status: DeliveryManProfileReviewsStatus.loaded,
                  reviews: seedReviews,
                  reviewCount:
                      seedReviewCount > 0 ? seedReviewCount : seedReviews.length,
                ),
        );

  final DeliveryManProfileRepository? _repository;
  final String? jeeberId;

  /// True when a real read is possible; otherwise the seed is all there is.
  bool get canLoad =>
      _repository != null && (jeeberId?.isNotEmpty ?? false);

  Future<void> load() async {
    final DeliveryManProfileRepository? repository = _repository;
    final String? id = jeeberId;
    if (repository == null || id == null || id.isEmpty) return;
    if (state.status == DeliveryManProfileReviewsStatus.loading) return;
    emit(
      state.copyWith(
        status: DeliveryManProfileReviewsStatus.loading,
        clearError: true,
      ),
    );
    await _read(repository, id, warm: false);
  }

  /// Never flips to loading (R6): the rows on screen stay put.
  Future<void> refresh() async {
    final DeliveryManProfileRepository? repository = _repository;
    final String? id = jeeberId;
    if (repository == null || id == null || id.isEmpty) return;
    await _read(repository, id, warm: true);
  }

  void acknowledgeRefreshError() {
    if (state.refreshError == null) return;
    emit(state.copyWith(clearRefreshError: true));
  }

  Future<void> _read(
    DeliveryManProfileRepository repository,
    String id, {
    required bool warm,
  }) async {
    try {
      final DeliveryManReviewsPage page =
          await repository.fetchReviews(jeeberId: id);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: DeliveryManProfileReviewsStatus.loaded,
          reviews: page.reviews,
          reviewCount: page.reviewCount,
          hasMore: page.hasMore,
          clearError: true,
          clearRefreshError: true,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      final AppFailure failure = AppFailure.of(e);
      if (warm && state.status == DeliveryManProfileReviewsStatus.loaded) {
        emit(state.copyWith(refreshError: failure));
        return;
      }
      emit(
        state.copyWith(
          status: DeliveryManProfileReviewsStatus.failed,
          error: failure,
        ),
      );
    }
  }
}
