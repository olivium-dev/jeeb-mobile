import '../domain/delivery_receipt.dart';
import '../domain/delivery_receipt_repository.dart';

class FakeDeliveryReceiptRepository implements DeliveryReceiptRepository {
  FakeDeliveryReceiptRepository({
    DeliveryReceipt? receipt,
    this.fetchFailure,
    this.confirmFailure,
  }) : _receipt = receipt;

  final DeliveryReceipt? _receipt;
  final DeliveryReceiptFailure? fetchFailure;
  final DeliveryReceiptFailure? confirmFailure;

  bool confirmed = false;

  @override
  Future<DeliveryReceipt> fetchReceipt(String deliveryId) async {
    final failure = fetchFailure;
    if (failure != null) {
      throw DeliveryReceiptRepositoryException(failure);
    }
    return _receipt ??
        DeliveryReceipt(
          deliveryId: deliveryId,
          jeeberName: 'Kamal Hajj',
          jeeberId: 'user-jeeber-002',
          cashAmount: 9.0,
          currency: 'USD',
          status: 'AtDoor',
          proofPhotoUrl: 'https://cdn.jeeb.app/proof/$deliveryId.jpg',
        );
  }

  @override
  Future<void> confirmReceipt(DeliveryReceipt receipt) async {
    final failure = confirmFailure;
    if (failure != null) {
      throw DeliveryReceiptRepositoryException(failure);
    }
    confirmed = true;
  }
}
