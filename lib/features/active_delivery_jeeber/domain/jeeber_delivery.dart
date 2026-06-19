import 'package:equatable/equatable.dart';

import 'jeeber_delivery_status.dart';

/// Drop-off address for display on the active-delivery map and stepper.
class DropOffAddress extends Equatable {
  const DropOffAddress({
    required this.label,
    required this.lat,
    required this.lng,
    this.detail,
  });

  factory DropOffAddress.fromJson(Map<String, dynamic> json) {
    return DropOffAddress(
      label: json['label'] as String? ??
          json['address'] as String? ??
          'Destination',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      detail: json['detail'] as String?,
    );
  }

  final String label;
  final double lat;
  final double lng;
  final String? detail;

  @override
  List<Object?> get props => [label, lat, lng, detail];
}

/// Snapshot of the Jeeber's active delivery fetched from
/// `GET /v1/delivery/{id}` (real mock: `delivery-service.ts`).
class JeeberDelivery extends Equatable {
  const JeeberDelivery({
    required this.id,
    required this.status,
    required this.dropOff,
    this.clientName,
    this.conversationId,
    this.amountText,
    this.cashNote,
    this.proofPhotoUrl,
  });

  factory JeeberDelivery.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status'] as String? ?? 'ordered';
    // The real seed (journey-seed.ts `seedDeliveryRow`) keys the destination
    // as `dropoff`; older fixtures used `dropOff`/`dropoffLocation`. Accept all.
    final dropOffJson = json['dropoff'] as Map<String, dynamic>? ??
        json['dropOff'] as Map<String, dynamic>? ??
        json['dropoffLocation'] as Map<String, dynamic>? ??
        <String, dynamic>{};
    return JeeberDelivery(
      id: json['id'] as String? ?? json['deliveryId'] as String? ?? '',
      status: JeeberDeliveryStatusX.fromApi(rawStatus),
      dropOff: DropOffAddress.fromJson(dropOffJson),
      clientName: json['clientName'] as String? ??
          json['jeeberName'] as String?,
      conversationId: json['conversationId'] as String?,
      amountText: _amountText(json['amount']),
      cashNote: _normalize(json['cashNote'] as String?),
      proofPhotoUrl: _normalize(json['proofPhotoUrl'] as String? ??
          json['evidenceUrl'] as String?),
    );
  }

  final String id;
  final JeeberDeliveryStatus status;
  final DropOffAddress dropOff;
  final String? clientName;
  final String? conversationId;

  /// Display amount the customer pays in cash on delivery, e.g. `"10.00 USD"`
  /// (D11). Derived from the `amount` value-object the mock returns.
  final String? amountText;

  /// "Customer confirms receipt and pays cash on delivery." copy seeded by the
  /// mock (JM-051 AC1). Falls back to a localized default when absent.
  final String? cashNote;

  /// Proof-of-delivery photo URL once captured/uploaded (D3). Null until the
  /// Jeeber captures it on this screen.
  final String? proofPhotoUrl;

  /// Returns a copy with the proof photo URL stamped (after upload).
  JeeberDelivery withProofPhoto(String url) => JeeberDelivery(
        id: id,
        status: status,
        dropOff: dropOff,
        clientName: clientName,
        conversationId: conversationId,
        amountText: amountText,
        cashNote: cashNote,
        proofPhotoUrl: url,
      );

  bool get hasProofPhoto => proofPhotoUrl != null && proofPhotoUrl!.isNotEmpty;

  static String? _normalize(String? v) =>
      (v == null || v.trim().isEmpty) ? null : v;

  /// Parse the `amount` value-object the mock emits (`usd(10.0)` →
  /// `{ value, currency, minorUnits }`) into a display string. Tolerates a bare
  /// number or a missing/odd shape.
  static String? _amountText(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toStringAsFixed(2);
    if (raw is Map) {
      final value = (raw['value'] as num?)?.toDouble();
      final currency = raw['currency'] as String?;
      if (value == null) return null;
      final amount = value.toStringAsFixed(2);
      return currency == null ? amount : '$amount $currency';
    }
    return null;
  }

  @override
  List<Object?> get props => [
        id,
        status,
        dropOff,
        clientName,
        conversationId,
        amountText,
        cashNote,
        proofPhotoUrl,
      ];
}
