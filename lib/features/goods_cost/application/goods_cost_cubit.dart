import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/goods_cost_repository.dart';
import 'goods_cost_state.dart';

class GoodsCostCubit extends Cubit<GoodsCostState> {
  GoodsCostCubit({
    required GoodsCostRepository repository,
    required String deliveryId,
  })  : _repository = repository,
        _deliveryId = deliveryId,
        super(const GoodsCostState());

  final GoodsCostRepository _repository;
  final String _deliveryId;

  Future<void> loadCurrency() async {
    if (state.currency != null) return;
    try {
      final currency = await _repository.fetchCurrency(_deliveryId);
      emit(state.copyWith(currency: currency));
    } catch (_) {
    }
  }

  Future<void> submit(double amount) async {
    if (state.submitStatus == GoodsCostSubmitStatus.inFlight ||
        state.submitStatus == GoodsCostSubmitStatus.succeeded) {
      return;
    }
    emit(state.copyWith(
      submitStatus: GoodsCostSubmitStatus.inFlight,
      clearSubmitError: true,
    ));
    try {
      final recorded = await _repository.recordGoodsCost(
        deliveryId: _deliveryId,
        amount: amount,
      );
      emit(state.copyWith(
        submitStatus: GoodsCostSubmitStatus.succeeded,
        recorded: recorded,
      ));
    } on GoodsCostRepositoryException catch (e) {
      emit(state.copyWith(
        submitStatus: GoodsCostSubmitStatus.failed,
        submitError: e.failure,
      ));
    } catch (_) {
      emit(state.copyWith(
        submitStatus: GoodsCostSubmitStatus.failed,
        submitError: GoodsCostFailure.unknown,
      ));
    }
  }

  void acknowledgeError() {
    if (state.submitStatus != GoodsCostSubmitStatus.failed) return;
    emit(state.copyWith(
      submitStatus: GoodsCostSubmitStatus.idle,
      clearSubmitError: true,
    ));
  }
}
