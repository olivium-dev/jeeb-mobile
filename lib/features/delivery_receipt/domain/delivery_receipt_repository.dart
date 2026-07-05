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
///  2. **Confirm** receipt — the idempotent SM-1 `AtDoor → Done` transition
///     (D70). The cash-on-delivery ledger (D11) is settled server-side by the
///     jeeber (BR-16); the customer never records COD and never sees the
///     platform fee.
abstract class DeliveryReceiptRepository {
  /// Fetches the receipt view for [deliveryId].
  Future<DeliveryReceipt> fetchReceipt(String deliveryId);

  /// Confirms the customer received the order by transitioning the delivery to
  /// `Done` via the real, shipped gateway route
  /// `PATCH /v1/deliveries/{id}/status`. The customer does NOT record COD — that
  /// ledger is jeeber/server-owned and the amount is server-authoritative
  /// (BR-16). Idempotent: an already-terminal delivery is a no-op, and a 422
  /// `transition_not_allowed` (server already flipped to `Done`) is treated as
  /// success. Throws a [DeliveryReceiptRepositoryException] tagged with the
  /// canonical failure on any other error.
  Future<void> confirmReceipt(DeliveryReceipt receipt);
}
