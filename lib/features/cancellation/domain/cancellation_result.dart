/// Result returned by a successful POST /v1/deliveries/{id}/cancel call.
///
/// Contract per D5 `CancelDeliveryResponse`:
/// `weeklyCount`, `retryAfter`, `strikeCount`, `restriction`,
/// `pendingApproval`, `jeeberRestricted` — some fields are invented for
/// mock fidelity (T-BE-030 / d5-delivery-lifecycle.contract.md).
class CancellationResult {
  const CancellationResult({
    required this.deliveryId,
    required this.weeklyCount,
    this.retryAfter,
    this.strikeCount,
    this.restriction,
    this.pendingApproval = false,
  });

  final String deliveryId;

  /// Cancellations this ISO-week (client only).
  final int weeklyCount;

  /// When the rate-limit resets (present only on 429 path — kept here
  /// for the rate-limited state so the UI can format the date).
  final DateTime? retryAfter;

  /// Jeeber-only: running strike count in the last 30 days.
  final int? strikeCount;

  /// Jeeber-only: restriction tier ('yellow', 'red') after this cancel.
  final String? restriction;

  /// True when a post-pickup client cancel requires admin approval.
  final bool pendingApproval;
}
