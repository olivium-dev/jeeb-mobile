import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/goods_cost_repository.dart';
import 'goods_cost_state.dart';

/// Drives the Jeeber "Enter Goods Cost" screen.
///
/// Responsibilities:
///  - Best-effort read of the delivery's gateway-authoritative currency so the
///    entry field can label the amount (no client-side / hardcoded currency —
///    40_GUARDRAILS_ARCH §5). A read failure is non-blocking: the label simply
///    degrades and the Jeeber can still enter the cost.
///  - Record the declared goods cost. On success emits a one-shot
///    [GoodsCostSubmitStatus.succeeded] the screen consumes to pop with the
///    gateway-confirmed record.
///
/// Per 40_GUARDRAILS_ARCH §2 the cubit takes the abstract repository by
/// constructor injection and never touches `sl`.
class GoodsCostCubit extends Cubit<GoodsCostState> {
  GoodsCostCubit({
    required GoodsCostRepository repository,
    required String deliveryId,
  })  : _repository = repository,
        _deliveryId = deliveryId,
        super(const GoodsCostState());

  final GoodsCostRepository _repository;
  final String _deliveryId;

  /// Best-effort currency read for the entry-field label. Swallows failures —
  /// the label degrades rather than blocking goods-cost entry.
  Future<void> loadCurrency() async {
    if (state.currency != null) return;
    try {
      final currency = await _repository.fetchCurrency(_deliveryId);
      emit(state.copyWith(currency: currency));
    } catch (_) {
      // Non-blocking: leave currency null so the label degrades neutrally.
    }
  }

  /// Records [amount] as the goods cost. Guards against double-submit while a
  /// record is in flight or already succeeded. On success emits a one-shot
  /// `succeeded` carrying the gateway-confirmed record.
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

  /// Dismiss the transient submit-failure banner so a replay doesn't loop.
  void acknowledgeError() {
    if (state.submitStatus != GoodsCostSubmitStatus.failed) return;
    emit(state.copyWith(
      submitStatus: GoodsCostSubmitStatus.idle,
      clearSubmitError: true,
    ));
  }
}
