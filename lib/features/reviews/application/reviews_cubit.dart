import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/reviews_repository.dart';
import 'reviews_state.dart';

/// Drives reviews-list (JM-068). Imports `domain/` only (40_GUARDRAILS_ARCH
/// §2.2); the abstract [ReviewsRepository] is constructor-injected (the screen
/// resolves the DI binding — the INTEGRATOR-STUB today, the LIVE
/// `DioReviewsRepository` once R1m is verified on :4010, 42_GUARDRAILS_MOCK
/// "FINAL WAVE … R1m"). The cubit never changes when the binding swaps.
///
/// Responsibilities:
///  - cold-load the first reviews page (newest-first, R1m envelope) + capture the
///    D59 cold-start gate (coldStart / reviewCount / averageScore),
///  - pull-to-refresh: re-fetch page 1 without flipping to a full-screen spinner
///    (the UI shows the pull indicator, §2.2),
///  - load-more: fetch the next page on scroll-end and APPEND it (infinite
///    scroll, D73 / JM-068 AC) — de-duped by review id, single-flight, with a
///    failure held as a soft footer error that leaves the loaded rows intact,
///  - report a review (D27) as a one-shot action that surfaces a snackbar via
///    [ReviewsState.reportStatus] without disturbing the list.
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

  /// Cold-entry load (page 1). Guards re-entry so a remount doesn't refetch
  /// (§2.2).
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

  /// Pull-to-refresh — re-fetches page 1 and REPLACES the list (the freshest
  /// page wins). Does NOT flip `status` to `loading` (§2.2). Resets the paging
  /// cursor + clears any soft load-more error, and re-reads the D59 gate.
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

  /// Fetch the next page and APPEND it (infinite scroll, D73). Single-flight: a
  /// no-op when not loaded, when there is no further page, or when a fetch is
  /// already in flight. A failure surfaces as the soft
  /// [ReviewsState.loadMoreError] footer (the loaded rows stay) and can be
  /// retried by [retryLoadMore].
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

  /// Retry the failed next-page fetch (clears the soft footer error, re-runs
  /// [loadMore]).
  Future<void> retryLoadMore() async {
    if (!state.loadMoreError) return;
    emit(state.copyWith(loadMoreError: false));
    await loadMore();
  }

  /// Report a review for moderation (D27). One-shot: emits `inFlight`, then
  /// `succeeded`/`failed` so the screen can fire a single snackbar (gated in a
  /// `listener`, §3). Never tears down the list. A second report while one is in
  /// flight is a no-op.
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

  /// One-shot acknowledgement of a finished report (after the snackbar fires),
  /// so a rebuild doesn't replay it (§2.2).
  void acknowledgeReport() {
    if (state.reportStatus == ReportStatus.idle) return;
    emit(state.copyWith(
      reportStatus: ReportStatus.idle,
      clearReportingReviewId: true,
    ));
  }

  /// Append [incoming] to [existing], dropping rows whose id is already present
  /// (defensive de-dupe — a backend that re-emits a boundary row on the next
  /// page must never double-render it). Returns an unmodifiable list — the cubit
  /// owns the order (§2.1).
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
