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

  String? get proofPhotoNetworkUrl =>
      normalizeProofPhotoNetworkUrl(proofPhotoUrl);

  String? get proofPhotoObjectRef =>
      normalizeProofPhotoObjectRef(proofPhotoUrl);

  bool get hasProofPhoto =>
      proofPhotoNetworkUrl != null || proofPhotoObjectRef != null;

  static String? normalizeProofEvidence(Object? raw) =>
      normalizeProofPhotoNetworkUrl(raw) ?? normalizeProofPhotoObjectRef(raw);

  static String? normalizeProofPhotoNetworkUrl(Object? raw) {
    if (raw is! String) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return null;
    return value;
  }

  static String? normalizeProofPhotoObjectRef(Object? raw) {
    if (raw is! String) return null;
    final value = raw.trim();
    if (value.isEmpty || value.contains(RegExp(r'\s'))) return null;
    final isBrokerRef = value.startsWith('cdn://obj/proof_of_delivery/');
    final isLegacyPathRef = value.startsWith('proof_of_delivery/');
    if (!isBrokerRef && !isLegacyPathRef) return null;
    if (value.contains('..') || value.endsWith('/')) return null;
    return value;
  }
}
