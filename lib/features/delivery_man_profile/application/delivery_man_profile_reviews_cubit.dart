import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/session/reviews_refresh_signals.dart';
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
  }) : _repository = repository,
       super(
         seedReviews.isEmpty
             ? const DeliveryManProfileReviewsState()
             : DeliveryManProfileReviewsState(
                 status: DeliveryManProfileReviewsStatus.loaded,
                 reviews: seedReviews,
                 reviewCount: seedReviewCount > 0
                     ? seedReviewCount
                     : seedReviews.length,
               ),
       );

  final DeliveryManProfileRepository? _repository;
  final String? jeeberId;
  int _generation = 0;
  bool _sessionEnded = false;

  void endSession() {
    if (isClosed) return;
    _sessionEnded = true;
    _generation++;
    emit(
      const DeliveryManProfileReviewsState(
        status: DeliveryManProfileReviewsStatus.failed,
        error: UnauthorizedFailure(),
      ),
    );
  }

  Future<void> refreshAndNotify() async {
    await refresh();
    if (isClosed ||
        _sessionEnded ||
        state.status != DeliveryManProfileReviewsStatus.loaded ||
        state.refreshError != null ||
        jeeberId == null) {
      return;
    }
    ReviewsRefreshSignals.instance.signalChanged(
      rateeId: jeeberId!,
      source: this,
    );
  }

  /// True when a real read is possible; otherwise the seed is all there is.
  bool get canLoad => _repository != null && (jeeberId?.isNotEmpty ?? false);

  Future<void> load() async {
    final DeliveryManProfileRepository? repository = _repository;
    final String? id = jeeberId;
    if (repository == null ||
        id == null ||
        id.isEmpty ||
        isClosed ||
        _sessionEnded) {
      return;
    }
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
    if (repository == null ||
        id == null ||
        id.isEmpty ||
        isClosed ||
        _sessionEnded) {
      return;
    }
    await _read(repository, id, warm: true);
  }

  void acknowledgeRefreshError() {
    if (isClosed || _sessionEnded) return;
    if (state.refreshError == null) return;
    emit(state.copyWith(clearRefreshError: true));
  }

  Future<void> _read(
    DeliveryManProfileRepository repository,
    String id, {
    required bool warm,
  }) async {
    final generation = ++_generation;
    try {
      final DeliveryManReviewsPage page = await repository.fetchReviews(
        jeeberId: id,
      );
      if (isClosed || _sessionEnded || generation != _generation) return;
      emit(
        state.copyWith(
          status: DeliveryManProfileReviewsStatus.loaded,
          reviews: page.reviews,
          reviewCount: page.reviewCount,
          averageScore: page.averageScore,
          clearAverageScore: page.averageScore == null,
          hasFreshSummary: true,
          hasMore: page.hasMore,
          clearError: true,
          clearRefreshError: true,
        ),
      );
    } catch (e) {
      if (isClosed || _sessionEnded || generation != _generation) return;
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

  @override
  Future<void> close() {
    _generation++;
    return super.close();
  }
}
