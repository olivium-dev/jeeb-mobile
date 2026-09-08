import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/app_failure.dart';

import '../domain/order_summary_repository.dart';
import 'order_summary_state.dart';

class OrderSummaryCubit extends Cubit<OrderSummaryState> {
  OrderSummaryCubit({
    required OrderSummaryRepository repository,
    required String deliveryId,
  })  : _repository = repository,
        _deliveryId = deliveryId,
        super(const OrderSummaryState());

  final OrderSummaryRepository _repository;
  final String _deliveryId;

  Future<void> load() async {
    if (state.status != OrderSummaryStatus.initial) return;
    emit(state.copyWith(status: OrderSummaryStatus.loading, clearError: true));
    try {
      final summary = await _repository.fetchSummary(_deliveryId);
      emit(state.copyWith(
        status: OrderSummaryStatus.loaded,
        summary: summary,
      ));
    } on OrderSummaryRepositoryException catch (e) {
      emit(state.copyWith(
        status: OrderSummaryStatus.failed,
        error: e.failure,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: OrderSummaryStatus.failed,
        error: _failureOf(e),
      ));
    }
  }

  /// The error CTA's act: `load()` early-returns unless `initial`, so the
  /// failed rung could never re-read and never showed a loading rung.
  Future<void> retry() async {
    if (state.status == OrderSummaryStatus.loading) return;
    emit(state.copyWith(
      status: OrderSummaryStatus.loading,
      clearError: true,
      clearRefreshError: true,
    ));
    try {
      final summary = await _repository.fetchSummary(_deliveryId);
      emit(state.copyWith(
        status: OrderSummaryStatus.loaded,
        summary: summary,
      ));
    } on OrderSummaryRepositoryException catch (e) {
      emit(state.copyWith(
        status: OrderSummaryStatus.failed,
        error: e.failure,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: OrderSummaryStatus.failed,
        error: _failureOf(e),
      ));
    }
  }

  /// Warm re-read: keeps the rows, never flips to loading.
  Future<void> refresh() async {
    try {
      final summary = await _repository.fetchSummary(_deliveryId);
      emit(state.copyWith(
        status: OrderSummaryStatus.loaded,
        summary: summary,
        clearRefreshError: true,
      ));
    } on OrderSummaryRepositoryException catch (e) {
      emit(state.copyWith(refreshError: e.failure));
    } catch (e) {
      emit(state.copyWith(refreshError: _failureOf(e)));
    }
  }

  void acknowledgeRefreshError() =>
      emit(state.copyWith(clearRefreshError: true));

  static OrderSummaryFailure _failureOf(Object error) =>
      switch (AppFailure.of(error).kind) {
        AppFailureKind.network ||
        AppFailureKind.timeout =>
          OrderSummaryFailure.network,
        AppFailureKind.notFound ||
        AppFailureKind.gone =>
          OrderSummaryFailure.notFound,
        AppFailureKind.unauthorized ||
        AppFailureKind.forbidden =>
          OrderSummaryFailure.forbidden,
        _ => OrderSummaryFailure.unknown,
      };
}
