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
/// GET /v1/deliveries/{id}.
class JeeberDelivery extends Equatable {
  const JeeberDelivery({
    required this.id,
    required this.status,
    required this.dropOff,
    this.clientName,
    this.conversationId,
  });

  factory JeeberDelivery.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status'] as String? ?? 'ordered';
    final dropOffJson = json['dropOff'] as Map<String, dynamic>? ??
        json['dropoffLocation'] as Map<String, dynamic>? ??
        <String, dynamic>{};
    return JeeberDelivery(
      id: json['id'] as String? ?? json['deliveryId'] as String? ?? '',
      status: JeeberDeliveryStatusX.fromApi(rawStatus),
      dropOff: DropOffAddress.fromJson(dropOffJson),
      clientName: json['clientName'] as String?,
      conversationId: json['conversationId'] as String?,
    );
  }

  final String id;
  final JeeberDeliveryStatus status;
  final DropOffAddress dropOff;
  final String? clientName;
  final String? conversationId;

  @override
  List<Object?> get props => [id, status, dropOff, clientName, conversationId];
}
