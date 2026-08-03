class DeliveryReceipt {
  const DeliveryReceipt({
    required this.deliveryId,
    required this.jeeberName,
    required this.cashAmount,
    required this.currency,
    required this.status,
    this.jeeberId,
    this.proofPhotoUrl,
  });

  final String deliveryId;

  final String jeeberName;

  final String? jeeberId;

  final double? cashAmount;

  bool get hasKnownAmount => (cashAmount ?? 0) > 0;

  final String currency;

  final String status;

  final String? proofPhotoUrl;

  bool get hasProofPhoto => (proofPhotoUrl ?? '').isNotEmpty;
}
