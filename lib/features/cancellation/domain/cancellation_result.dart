/// Response from POST /v1/deliveries/{id}/cancel.
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

  /// Client cancellations this ISO-week.
  final int weeklyCount;

  /// When rate-limit resets (429 path only).
  final DateTime? retryAfter;

  /// Running strike count (last 30 days).
  final int? strikeCount;

  /// Restriction tier ('yellow' or 'red').
  final String? restriction;

  /// Post-pickup client cancel pending approval.
  final bool pendingApproval;
}
