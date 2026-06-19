import 'delivery_receipt.dart';

/// Classified failure surface the cubit maps to copy. The UI never sees a
/// raw `DioException` — `data/` translates transport errors into one of these
/// (40_GUARDRAILS_ARCH §4).
enum DeliveryReceiptFailure {
  /// Connection / timeout — retryable.
  network,

  /// The delivery id resolved no receipt (404) — nothing to confirm.
  notFound,

  /// The delivery is in a state from which "Done" is not a legal transition
  /// (the mock returns 422 `transition_not_allowed`). Surfaced so the screen
  /// can tell the customer the confirmation could not be applied.
  transitionNotAllowed,

  /// Anything else.
  unknown,
}

/// Typed exception the repository raises so the cubit can map cleanly without
/// peeking at the underlying transport.
class DeliveryReceiptRepositoryException implements Exception {
  const DeliveryReceiptRepositoryException(this.failure, [this.message]);
  final DeliveryReceiptFailure failure;
  final String? message;

  @override
  String toString() =>
      'DeliveryReceiptRepositoryException($failure, $message)';
}

/// Contract for the customer confirm-receipt screen (JM-033).
///
/// Two responsibilities:
///  1. **Read** the receipt view for a delivery (cash amount, Jeeber name,
///     proof photo) so the prompt can render.
///  2. **Confirm** receipt — the SM-1 `AtDoor → Done` transition (D70) plus the
///     cash-on-delivery settlement record (D11, no commission shown to the
///     customer). The cash record is recorded server-side; the customer-facing
///     screen never displays the platform fee.
abstract class DeliveryReceiptRepository {
  /// Fetches the receipt view for [deliveryId].
  Future<DeliveryReceipt> fetchReceipt(String deliveryId);

  /// Confirms the customer received the order. Records the cash settlement
  /// (`POST /v1/payments/cod_jeeb/record`) then transitions the delivery to
  /// `Done` (`POST /v1/delivery/status/transition`). Idempotent server-side
  /// (both endpoints key on `deliveryId`). Throws a
  /// [DeliveryReceiptRepositoryException] tagged with the canonical failure on
  /// error.
  Future<void> confirmReceipt(DeliveryReceipt receipt);
}
