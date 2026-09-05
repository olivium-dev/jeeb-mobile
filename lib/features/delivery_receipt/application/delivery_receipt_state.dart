import 'package:equatable/equatable.dart';

import '../domain/delivery_receipt.dart';
import '../domain/delivery_receipt_repository.dart';

enum DeliveryReceiptStatus { initial, loading, loaded, failed }

enum ReceiptConfirmStatus { idle, inFlight, succeeded, failed }

class DeliveryReceiptState extends Equatable {
  const DeliveryReceiptState({
    this.status = DeliveryReceiptStatus.initial,
    this.receipt,
    this.error,
    this.refreshError,
    this.confirmStatus = ReceiptConfirmStatus.idle,
    this.confirmError,
  });

  final DeliveryReceiptStatus status;
  final DeliveryReceipt? receipt;
  final DeliveryReceiptFailure? error;

  /// A warm refresh failed with a receipt already on screen: a dismissible
  /// note, never a rung — [error] was written here and rendered nowhere.
  final DeliveryReceiptFailure? refreshError;

  final ReceiptConfirmStatus confirmStatus;
  final DeliveryReceiptFailure? confirmError;

  bool get isConfirming => confirmStatus == ReceiptConfirmStatus.inFlight;

  DeliveryReceiptState copyWith({
    DeliveryReceiptStatus? status,
    DeliveryReceipt? receipt,
    DeliveryReceiptFailure? error,
    DeliveryReceiptFailure? refreshError,
    ReceiptConfirmStatus? confirmStatus,
    DeliveryReceiptFailure? confirmError,
    bool clearError = false,
    bool clearRefreshError = false,
    bool clearConfirmError = false,
  }) =>
      DeliveryReceiptState(
        status: status ?? this.status,
        receipt: receipt ?? this.receipt,
        error: clearError ? null : (error ?? this.error),
        refreshError:
            clearRefreshError ? null : (refreshError ?? this.refreshError),
        confirmStatus: confirmStatus ?? this.confirmStatus,
        confirmError:
            clearConfirmError ? null : (confirmError ?? this.confirmError),
      );

  @override
  List<Object?> get props =>
      [status, receipt, error, refreshError, confirmStatus, confirmError];
}
