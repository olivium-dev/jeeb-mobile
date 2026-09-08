import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/app_failure.dart';

import '../domain/delivery_receipt_repository.dart';
import 'delivery_receipt_state.dart';

class DeliveryReceiptCubit extends Cubit<DeliveryReceiptState> {
  DeliveryReceiptCubit({
    required DeliveryReceiptRepository repository,
    required String deliveryId,
  })  : _repository = repository,
        _deliveryId = deliveryId,
        super(const DeliveryReceiptState());

  final DeliveryReceiptRepository _repository;
  final String _deliveryId;

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
    } catch (e) {
      emit(state.copyWith(
        status: DeliveryReceiptStatus.failed,
        error: _failureOf(e),
      ));
    }
  }

  /// The error CTA's act: `load()` early-returns unless `initial`, so a retry
  /// from `failed` was a no-op with no loading rung.
  Future<void> retry() async {
    if (state.status == DeliveryReceiptStatus.loading) return;
    emit(state.copyWith(
      status: DeliveryReceiptStatus.loading,
      clearError: true,
      clearRefreshError: true,
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
    } catch (e) {
      emit(state.copyWith(
        status: DeliveryReceiptStatus.failed,
        error: _failureOf(e),
      ));
    }
  }

  /// Warm re-read: keeps the receipt and never flips the status rung.
  Future<void> refresh() async {
    if (state.status != DeliveryReceiptStatus.loaded) {
      emit(state.copyWith(status: DeliveryReceiptStatus.initial));
      return load();
    }
    try {
      final receipt = await _repository.fetchReceipt(_deliveryId);
      emit(state.copyWith(receipt: receipt, clearRefreshError: true));
    } on DeliveryReceiptRepositoryException catch (e) {
      emit(state.copyWith(refreshError: e.failure));
    } catch (e) {
      emit(state.copyWith(refreshError: _failureOf(e)));
    }
  }

  void acknowledgeRefreshError() {
    emit(state.copyWith(clearRefreshError: true));
  }

  static DeliveryReceiptFailure _failureOf(Object error) =>
      switch (AppFailure.of(error).kind) {
        AppFailureKind.network ||
        AppFailureKind.timeout =>
          DeliveryReceiptFailure.network,
        AppFailureKind.notFound ||
        AppFailureKind.gone =>
          DeliveryReceiptFailure.notFound,
        AppFailureKind.unauthorized ||
        AppFailureKind.forbidden =>
          DeliveryReceiptFailure.forbidden,
        _ => DeliveryReceiptFailure.unknown,
      };

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
    } catch (e) {
      emit(state.copyWith(
        confirmStatus: ReceiptConfirmStatus.failed,
        confirmError: _failureOf(e),
      ));
    }
  }

  void acknowledgeConfirmError() {
    if (state.confirmStatus != ReceiptConfirmStatus.failed) return;
    emit(state.copyWith(
      confirmStatus: ReceiptConfirmStatus.idle,
      clearConfirmError: true,
    ));
  }
}
