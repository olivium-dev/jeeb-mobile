import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/reviews_repository.dart';
import 'reviews_state.dart';

class ReviewsCubit extends Cubit<ReviewsState> {
  ReviewsCubit({
    required ReviewsRepository repository,
    required String jeeberId,
    int pageSize = 20,
  })  : _repository = repository,
        _jeeberId = jeeberId,
        _pageSize = pageSize,
        super(const ReviewsState());

  final ReviewsRepository _repository;
  final String _jeeberId;
  final int _pageSize;

  Future<void> load() async {
    if (state.status != ReviewsStatus.initial) return;
    emit(state.copyWith(status: ReviewsStatus.loading, clearError: true));
    try {
      final page = await _repository.fetchReviews(
        jeeberId: _jeeberId,
        page: 1,
        pageSize: _pageSize,
      );
      emit(state.copyWith(
        status: ReviewsStatus.loaded,
        reviews: List<ReviewItem>.unmodifiable(page.reviews),
        page: page.page,
        hasMore: page.hasMore,
        coldStart: page.coldStart,
        reviewCount: page.reviewCount,
        averageScore: page.averageScore,
        clearAverageScore: page.averageScore == null,
      ));
    } on ReviewsRepositoryException catch (e) {
      emit(state.copyWith(status: ReviewsStatus.failed, error: e.failure));
    } catch (_) {
      emit(state.copyWith(
        status: ReviewsStatus.failed,
        error: ReviewsFailure.unknown,
      ));
    }
  }

  Future<void> refresh() async {
    try {
      final page = await _repository.fetchReviews(
        jeeberId: _jeeberId,
        page: 1,
        pageSize: _pageSize,
      );
      emit(state.copyWith(
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
      ));
    } on ReviewsRepositoryException catch (e) {
      emit(state.copyWith(error: e.failure));
    } catch (_) {
      emit(state.copyWith(error: ReviewsFailure.unknown));
    }
  }

  Future<void> loadMore() async {
    if (state.status != ReviewsStatus.loaded) return;
    if (!state.hasMore || state.loadingMore) return;
    emit(state.copyWith(loadingMore: true, loadMoreError: false));
    final next = state.page + 1;
    try {
      final page = await _repository.fetchReviews(
        jeeberId: _jeeberId,
        page: next,
        pageSize: _pageSize,
      );
      emit(state.copyWith(
        reviews: _merge(state.reviews, page.reviews),
        page: page.page,
        hasMore: page.hasMore,
        loadingMore: false,
      ));
    } on ReviewsRepositoryException catch (_) {
      emit(state.copyWith(loadingMore: false, loadMoreError: true));
    } catch (_) {
      emit(state.copyWith(loadingMore: false, loadMoreError: true));
    }
  }

  Future<void> retryLoadMore() async {
    if (!state.loadMoreError) return;
    emit(state.copyWith(loadMoreError: false));
    await loadMore();
  }

  Future<void> reportReview(String reviewId) async {
    if (reviewId.isEmpty) return;
    if (state.reportStatus == ReportStatus.inFlight) return;
    emit(state.copyWith(
      reportStatus: ReportStatus.inFlight,
      reportingReviewId: reviewId,
    ));
    try {
      await _repository.reportReview(reviewId);
      emit(state.copyWith(reportStatus: ReportStatus.succeeded));
    } catch (_) {
      emit(state.copyWith(reportStatus: ReportStatus.failed));
    }
  }

  void acknowledgeReport() {
    if (state.reportStatus == ReportStatus.idle) return;
    emit(state.copyWith(
      reportStatus: ReportStatus.idle,
      clearReportingReviewId: true,
    ));
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
