import 'package:flutter_bloc/flutter_bloc.dart';

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
    } catch (_) {
      emit(state.copyWith(
        status: OrderSummaryStatus.failed,
        error: OrderSummaryFailure.unknown,
      ));
    }
  }

  Future<void> refresh() async {
    try {
      final summary = await _repository.fetchSummary(_deliveryId);
      emit(state.copyWith(
        status: OrderSummaryStatus.loaded,
        summary: summary,
        clearError: true,
      ));
    } on OrderSummaryRepositoryException catch (e) {
      emit(state.copyWith(error: e.failure));
    } catch (_) {
      emit(state.copyWith(error: OrderSummaryFailure.unknown));
    }
  }
}
