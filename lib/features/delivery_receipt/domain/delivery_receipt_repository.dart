import 'delivery_receipt.dart';

enum DeliveryReceiptFailure {
  network,

  notFound,

  transitionNotAllowed,

  forbidden,

  unknown,
}

class DeliveryReceiptRepositoryException implements Exception {
  const DeliveryReceiptRepositoryException(this.failure, [this.message]);
  final DeliveryReceiptFailure failure;
  final String? message;

  @override
  String toString() =>
      'DeliveryReceiptRepositoryException($failure, $message)';
}

abstract class DeliveryReceiptRepository {
  Future<DeliveryReceipt> fetchReceipt(String deliveryId);

  Future<void> confirmReceipt(DeliveryReceipt receipt);
}
