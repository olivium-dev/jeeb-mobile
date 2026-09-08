import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/diagnostics/diag.dart';
import '../../../core/network/app_failure.dart';
import '../domain/goods_cost_repository.dart';
import 'goods_cost_state.dart';

class GoodsCostCubit extends Cubit<GoodsCostState> {
  GoodsCostCubit({
    required GoodsCostRepository repository,
    required String deliveryId,
  }) : _repository = repository,
       _deliveryId = deliveryId,
       super(const GoodsCostState());

  final GoodsCostRepository _repository;
  final String _deliveryId;

  /// A double tap on the inline retry must not fire two reads (§7-13b).
  bool _currencyInFlight = false;

  Future<void> loadCurrency() async {
    // Re-entrant after a failure so the inline retry can actually retry.
    if (state.currency != null && !state.currencyUnavailable) return;
    if (_currencyInFlight) return;
    _currencyInFlight = true;
    try {
      final currency = await _repository.fetchCurrency(_deliveryId);
      emit(state.copyWith(currency: currency, currencyUnavailable: false));
    } catch (e) {
      // LR-29: the label degrades to neutral AND the Jeeber is told why.
      Diag.event('goods_cost.currency_read_failed', <String, Object?>{
        'kind': AppFailure.of(e).kind.name,
      });
      emit(state.copyWith(currencyUnavailable: true));
    } finally {
      _currencyInFlight = false;
    }
  }

  Future<void> submit(double amount) async {
    if (state.submitStatus == GoodsCostSubmitStatus.inFlight ||
        state.submitStatus == GoodsCostSubmitStatus.succeeded) {
      return;
    }
    emit(
      state.copyWith(
        submitStatus: GoodsCostSubmitStatus.inFlight,
        clearSubmitError: true,
      ),
    );
    try {
      final recorded = await _repository.recordGoodsCost(
        deliveryId: _deliveryId,
        amount: amount,
      );
      emit(
        state.copyWith(
          submitStatus: GoodsCostSubmitStatus.succeeded,
          recorded: recorded,
        ),
      );
    } on GoodsCostRepositoryException catch (e) {
      emit(
        state.copyWith(
          submitStatus: GoodsCostSubmitStatus.failed,
          submitError: e.failure,
          failure: e.cause,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          submitStatus: GoodsCostSubmitStatus.failed,
          submitError: GoodsCostFailure.unknown,
          failure: AppFailure.of(e),
        ),
      );
    }
  }

  void acknowledgeError() {
    if (state.submitStatus != GoodsCostSubmitStatus.failed) return;
    emit(
      state.copyWith(
        submitStatus: GoodsCostSubmitStatus.idle,
        clearSubmitError: true,
      ),
    );
  }
}
