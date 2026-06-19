import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/delivery_receipt_repository.dart';
import 'delivery_receipt_state.dart';

/// Drives the customer confirm-receipt screen (JM-033).
///
/// Responsibilities:
///  - Cold-load the receipt view for a delivery id (cash amount, Jeeber name,
///    proof photo) so the "Did you receive your order?" prompt can render.
///  - Confirm receipt: record the cash-on-delivery settlement + transition the
///    delivery to `Done` (D70/D11), then surface a one-shot `succeeded` the
///    screen listens for to navigate to the rating screen (JM-034).
///
/// Per 40_GUARDRAILS_ARCH §2 the cubit takes the abstract repository by
/// constructor injection and never touches `sl`.
class DeliveryReceiptCubit extends Cubit<DeliveryReceiptState> {
  DeliveryReceiptCubit({
    required DeliveryReceiptRepository repository,
    required String deliveryId,
  })  : _repository = repository,
        _deliveryId = deliveryId,
        super(const DeliveryReceiptState());

  final DeliveryReceiptRepository _repository;
  final String _deliveryId;

  /// Cold-load entry-point. Guards re-entry so the host route can safely
  /// re-invoke on remount.
  Future<void> load() async {
    if (state.status != DeliveryReceiptStatus.initial) return;
    emit(state.copyWith(
      status: DeliveryReceiptStatus.loading,
      clearError: true,
    ));
    try {
      final receipt = await _repository.fetchReceipt(_deliveryId);
      emit(state.copyWith(
        status: DeliveryReceiptStatus.loaded,
        receipt: receipt,
      ));
    } on DeliveryReceiptRepositoryException catch (e) {
      emit(state.copyWith(
        status: DeliveryReceiptStatus.failed,
        error: e.failure,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: DeliveryReceiptStatus.failed,
        error: DeliveryReceiptFailure.unknown,
      ));
    }
  }

  /// Pull-to-refresh / retry. Does NOT flip `status` to loading (the UI shows a
  /// pull indicator, not a full-screen spinner) once a receipt is loaded; on a
  /// cold failure it re-runs the full load.
  Future<void> refresh() async {
    if (state.status != DeliveryReceiptStatus.loaded) {
      emit(state.copyWith(status: DeliveryReceiptStatus.initial));
      return load();
    }
    try {
      final receipt = await _repository.fetchReceipt(_deliveryId);
      emit(state.copyWith(receipt: receipt, clearError: true));
    } on DeliveryReceiptRepositoryException catch (e) {
      emit(state.copyWith(error: e.failure));
    } catch (_) {
      emit(state.copyWith(error: DeliveryReceiptFailure.unknown));
    }
  }

  /// Customer confirms receipt → records cash settlement + transitions to
  /// `Done`. On success emits a one-shot [ReceiptConfirmStatus.succeeded] the
  /// screen consumes to route to the rating screen. Guards against double-tap
  /// while a confirm is in flight or already succeeded.
  Future<void> confirmReceipt() async {
    final receipt = state.receipt;
    if (receipt == null) return;
    if (state.confirmStatus == ReceiptConfirmStatus.inFlight ||
        state.confirmStatus == ReceiptConfirmStatus.succeeded) {
      return;
    }
    emit(state.copyWith(
      confirmStatus: ReceiptConfirmStatus.inFlight,
      clearConfirmError: true,
    ));
    try {
      await _repository.confirmReceipt(receipt);
      emit(state.copyWith(confirmStatus: ReceiptConfirmStatus.succeeded));
    } on DeliveryReceiptRepositoryException catch (e) {
      emit(state.copyWith(
        confirmStatus: ReceiptConfirmStatus.failed,
        confirmError: e.failure,
      ));
    } catch (_) {
      emit(state.copyWith(
        confirmStatus: ReceiptConfirmStatus.failed,
        confirmError: DeliveryReceiptFailure.unknown,
      ));
    }
  }

  /// Dismiss the transient confirm-failure banner so a replay doesn't loop.
  void acknowledgeConfirmError() {
    if (state.confirmStatus != ReceiptConfirmStatus.failed) return;
    emit(state.copyWith(
      confirmStatus: ReceiptConfirmStatus.idle,
      clearConfirmError: true,
    ));
  }
}
