import 'package:flutter_bloc/flutter_bloc.dart';

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
    } catch (_) {
      emit(state.copyWith(
        status: DeliveryReceiptStatus.failed,
        error: DeliveryReceiptFailure.unknown,
      ));
    }
  }

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

  void acknowledgeConfirmError() {
    if (state.confirmStatus != ReceiptConfirmStatus.failed) return;
    emit(state.copyWith(
      confirmStatus: ReceiptConfirmStatus.idle,
      clearConfirmError: true,
    ));
  }
}
