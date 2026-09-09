import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/session/reviews_refresh_signals.dart';
import '../domain/reviews_repository.dart';
import 'reviews_state.dart';

class ReviewsCubit extends Cubit<ReviewsState> {
  ReviewsCubit({
    required ReviewsRepository repository,
    required String jeeberId,
    int pageSize = 20,
  }) : _repository = repository,
       _jeeberId = jeeberId,
       _pageSize = pageSize,
       super(const ReviewsState());

  final ReviewsRepository _repository;
  final String _jeeberId;
  final int _pageSize;
  int _readGeneration = 0;
  bool _sessionEnded = false;
  bool _firstPageReading = false;
  String get jeeberId => _jeeberId;

  void endSession() {
    if (isClosed) return;
    _sessionEnded = true;
    _readGeneration++;
    emit(
      const ReviewsState(
        status: ReviewsStatus.failed,
        error: ReviewsFailure.unauthorized,
        appFailure: UnauthorizedFailure(),
      ),
    );
  }

  Future<void> refreshAndNotify() async {
    await refresh();
    if (isClosed ||
        _sessionEnded ||
        state.status != ReviewsStatus.loaded ||
        state.refreshError != null) {
      return;
    }
    ReviewsRefreshSignals.instance.signalChanged(
      rateeId: _jeeberId,
      source: this,
    );
  }

  Future<void> load() async {
    if (isClosed || _sessionEnded || state.status != ReviewsStatus.initial) {
      return;
    }
    emit(state.copyWith(status: ReviewsStatus.loading, clearError: true));
    await _readFirstPage(warm: false);
  }

  /// The cold-error retry: unlike [refresh] it shows the loading rung first.
  Future<void> retry() async {
    if (isClosed || _sessionEnded || state.status == ReviewsStatus.loading) {
      return;
    }
    emit(state.copyWith(status: ReviewsStatus.loading, clearError: true));
    await _readFirstPage(warm: false);
  }

  void acknowledgeRefreshError() {
    if (isClosed || _sessionEnded) return;
    emit(state.copyWith(clearRefreshError: true));
  }

  Future<void> refresh() async =>
      _readFirstPage(warm: state.status == ReviewsStatus.loaded);

  /// The single first-page read behind [load], [retry] and [refresh]. The
  /// generation counter drops a stale response from an overlapping pull.
  Future<void> _readFirstPage({required bool warm}) async {
    if (isClosed || _sessionEnded) return;
    final generation = ++_readGeneration;
    _firstPageReading = true;
    if (state.loadingMore) emit(state.copyWith(loadingMore: false));
    try {
      final page = await _repository.fetchReviews(
        jeeberId: _jeeberId,
        page: 1,
        pageSize: _pageSize,
      );
      if (isClosed || generation != _readGeneration) return;
      emit(
        state.copyWith(
          status: ReviewsStatus.loaded,
          reviews: List<ReviewItem>.unmodifiable(page.reviews),
          page: page.page,
          hasMore: page.hasMore,
          loadingMore: false,
          loadMoreError: false,
          coldStart: page.coldStart,
          reviewCount: page.reviewCount,
          averageScore: page.averageScore,
          clearAverageScore: page.averageScore == null,
          clearError: true,
          clearRefreshError: true,
          clearLoadMoreFailure: true,
        ),
      );
    } on ReviewsRepositoryException catch (e) {
      if (isClosed || generation != _readGeneration) return;
      _emitReadFailure(warm, e.failure, e.appFailure ?? AppFailure.of(e));
    } catch (error) {
      if (isClosed || generation != _readGeneration) return;
      _emitReadFailure(warm, ReviewsFailure.unknown, AppFailure.of(error));
    } finally {
      if (generation == _readGeneration) _firstPageReading = false;
    }
  }

  /// A warm failure never blanks the rows; it rides the strip (LR-07).
  void _emitReadFailure(bool warm, ReviewsFailure kind, AppFailure failure) {
    if (warm) {
      emit(state.copyWith(refreshError: failure));
      return;
    }
    emit(
      state.copyWith(
        status: ReviewsStatus.failed,
        error: kind,
        appFailure: failure,
      ),
    );
  }

  Future<void> loadMore() async {
    if (isClosed || _sessionEnded || _firstPageReading) return;
    if (state.status != ReviewsStatus.loaded) return;
    if (!state.hasMore || state.loadingMore) return;
    emit(state.copyWith(loadingMore: true, loadMoreError: false));
    final next = state.page + 1;
    final generation = _readGeneration;
    try {
      final page = await _repository.fetchReviews(
        jeeberId: _jeeberId,
        page: next,
        pageSize: _pageSize,
      );
      if (isClosed || _sessionEnded || generation != _readGeneration) return;
      emit(
        state.copyWith(
          reviews: _merge(state.reviews, page.reviews),
          page: page.page,
          hasMore: page.hasMore,
          loadingMore: false,
        ),
      );
    } on ReviewsRepositoryException catch (e) {
      if (isClosed || _sessionEnded || generation != _readGeneration) return;
      emit(
        state.copyWith(
          loadingMore: false,
          loadMoreError: true,
          loadMoreFailure: e.appFailure ?? AppFailure.of(e),
        ),
      );
    } catch (error) {
      if (isClosed || _sessionEnded || generation != _readGeneration) return;
      emit(
        state.copyWith(
          loadingMore: false,
          loadMoreError: true,
          loadMoreFailure: AppFailure.of(error),
        ),
      );
    }
  }

  Future<void> retryLoadMore() async {
    if (isClosed || _sessionEnded) return;
    if (!state.loadMoreError) return;
    emit(state.copyWith(loadMoreError: false, clearLoadMoreFailure: true));
    await loadMore();
  }

  Future<void> reportReview(String reviewId) async {
    if (isClosed || _sessionEnded) return;
    if (reviewId.isEmpty) return;
    if (state.reportStatus == ReportStatus.inFlight) return;
    emit(
      state.copyWith(
        reportStatus: ReportStatus.inFlight,
        reportingReviewId: reviewId,
        clearReportFailure: true,
      ),
    );
    try {
      await _repository.reportReview(reviewId);
      if (isClosed || _sessionEnded) return;
      emit(
        state.copyWith(
          reportStatus: ReportStatus.succeeded,
          clearReportFailure: true,
        ),
      );
    } catch (error) {
      if (isClosed || _sessionEnded) return;
      emit(
        state.copyWith(
          reportStatus: ReportStatus.failed,
          reportFailure: error is ReviewsRepositoryException
              ? (error.appFailure ?? AppFailure.of(error))
              : AppFailure.of(error),
        ),
      );
    }
  }

  void acknowledgeReport() {
    if (isClosed || _sessionEnded) return;
    if (state.reportStatus == ReportStatus.idle) return;
    emit(
      state.copyWith(
        reportStatus: ReportStatus.idle,
        clearReportingReviewId: true,
        clearReportFailure: true,
      ),
    );
  }

  @override
  Future<void> close() {
    _readGeneration++;
    return super.close();
  }

  List<ReviewItem> _merge(
    List<ReviewItem> existing,
    List<ReviewItem> incoming,
  ) {
    final seen = existing.map((e) => e.id).toSet();
    final out = List<ReviewItem>.of(existing);
    for (final e in incoming) {
      if (e.id.isEmpty || seen.add(e.id)) out.add(e);
    }
    return List<ReviewItem>.unmodifiable(out);
  }
}
