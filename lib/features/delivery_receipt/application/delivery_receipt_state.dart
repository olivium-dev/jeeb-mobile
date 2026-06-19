import 'package:equatable/equatable.dart';

import '../domain/delivery_receipt.dart';
import '../domain/delivery_receipt_repository.dart';

/// Screen-level read lifecycle (40_GUARDRAILS_ARCH §2): cold-load the receipt
/// view (cash amount + Jeeber name + proof photo) before the prompt renders.
enum DeliveryReceiptStatus { initial, loading, loaded, failed }

/// The confirm-receipt action sub-status, kept separate from the screen
/// `status` so the in-row spinner / failure banner don't tear down the loaded
/// body. `succeeded` is the one-shot the screen listens for to navigate to the
/// rating screen (JM-034).
enum ReceiptConfirmStatus { idle, inFlight, succeeded, failed }

class DeliveryReceiptState extends Equatable {
  const DeliveryReceiptState({
    this.status = DeliveryReceiptStatus.initial,
    this.receipt,
    this.error,
    this.confirmStatus = ReceiptConfirmStatus.idle,
    this.confirmError,
  });

  final DeliveryReceiptStatus status;
  final DeliveryReceipt? receipt;
  final DeliveryReceiptFailure? error;

  final ReceiptConfirmStatus confirmStatus;
  final DeliveryReceiptFailure? confirmError;

  bool get isConfirming => confirmStatus == ReceiptConfirmStatus.inFlight;

  DeliveryReceiptState copyWith({
    DeliveryReceiptStatus? status,
    DeliveryReceipt? receipt,
    DeliveryReceiptFailure? error,
    ReceiptConfirmStatus? confirmStatus,
    DeliveryReceiptFailure? confirmError,
    bool clearError = false,
    bool clearConfirmError = false,
  }) =>
      DeliveryReceiptState(
        status: status ?? this.status,
        receipt: receipt ?? this.receipt,
        error: clearError ? null : (error ?? this.error),
        confirmStatus: confirmStatus ?? this.confirmStatus,
        confirmError:
            clearConfirmError ? null : (confirmError ?? this.confirmError),
      );

  @override
  List<Object?> get props =>
      [status, receipt, error, confirmStatus, confirmError];
}
