import 'goods_cost.dart';

/// Classified failure surface the cubit maps to copy. The UI never sees a raw
/// `DioException` — `data/` translates transport errors into one of these
/// (40_GUARDRAILS_ARCH §4).
enum GoodsCostFailure {
  /// Connection / timeout — retryable.
  network,

  /// The delivery id resolved nothing (404).
  notFound,

  /// The gateway rejected the amount (422) — e.g. non-positive / out of range.
  validation,

  /// Anything else.
  unknown,
}

/// Typed exception the repository raises so the cubit can map cleanly without
/// peeking at the underlying transport.
class GoodsCostRepositoryException implements Exception {
  const GoodsCostRepositoryException(this.failure, [this.message]);
  final GoodsCostFailure failure;
  final String? message;

  @override
  String toString() => 'GoodsCostRepositoryException($failure, $message)';
}

/// Contract for the Jeeber "Enter Goods Cost" screen.
///
/// Two responsibilities:
///  1. **Read** the delivery's currency so the entry field can label the amount
///     in the gateway-authoritative currency (40_GUARDRAILS_ARCH §5 — currency
///     comes from the gateway verbatim; there is no user/config currency field).
///  2. **Record** the goods cost the Jeeber declares for a delivery, returning
///     the gateway-confirmed [GoodsCost] (amount echoed back + the currency the
///     gateway settled on).
abstract class GoodsCostRepository {
  /// Best-effort read of the delivery's ISO currency code, used only to label
  /// the entry field. Throws a [GoodsCostRepositoryException] on hard failure;
  /// the cubit treats a failure here as non-blocking and degrades the label.
  Future<String> fetchCurrency(String deliveryId);

  /// Records [amount] as the goods cost for [deliveryId]. Returns the
  /// gateway-confirmed record (amount + currency verbatim). Throws a
  /// [GoodsCostRepositoryException] tagged with the canonical failure on error.
  Future<GoodsCost> recordGoodsCost({
    required String deliveryId,
    required double amount,
  });
}
