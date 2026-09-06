import '../domain/delivery_receipt.dart';
import '../domain/delivery_receipt_repository.dart';

/// Missing wiring is an unavailable operation, never a fabricated receipt.
class UnavailableDeliveryReceiptRepository extends DeliveryReceiptRepository {
  @override
  Future<DeliveryReceipt> fetchReceipt(String deliveryId) async =>
      throw const DeliveryReceiptRepositoryException(
        DeliveryReceiptFailure.unknown,
      );

  @override
  Future<void> confirmReceipt(DeliveryReceipt receipt) async =>
      throw const DeliveryReceiptRepositoryException(
        DeliveryReceiptFailure.unknown,
      );
}
