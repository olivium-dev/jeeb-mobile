import 'package:equatable/equatable.dart';

import '../../active_delivery_jeeber/domain/jeeber_delivery_status.dart';

class ActiveDeliverySummary extends Equatable {
  const ActiveDeliverySummary({
    required this.id,
    required this.status,
    this.conversationId,
    this.title,
    this.dropoffAddress,
    this.pickupAddress,
  });

  factory ActiveDeliverySummary.fromJson(Map<String, dynamic> json) {
    final id =
        json['id'] as String? ?? json['deliveryId'] as String? ?? json['requestId'] as String? ?? '';
    return ActiveDeliverySummary(
      id: id,
      status: JeeberDeliveryStatusX.fromApi(json['status'] as String? ?? 'ordered'),
      conversationId: _normalize(json['conversationId'] as String? ??
          json['conversation_id'] as String?),
      title: _normalize(json['title'] as String?),
      pickupAddress: _address(json['pickup']),
      dropoffAddress: _address(json['dropoff'] ?? json['dropOff']),
    );
  }

  final String id;

  final JeeberDeliveryStatus status;

  final String? conversationId;

  final String? title;

  final String? pickupAddress;
  final String? dropoffAddress;

  bool get isActive => !status.isTerminal;

  String get chatRouteId => id.isNotEmpty ? id : (conversationId ?? '');

  static String? _normalize(String? v) =>
      (v == null || v.trim().isEmpty) ? null : v;

  static String? _address(Object? raw) {
    if (raw is Map) {
      final addr = raw['address'] as String? ?? raw['label'] as String?;
      return _normalize(addr);
    }
    return null;
  }

  @override
  List<Object?> get props =>
      [id, status, conversationId, title, pickupAddress, dropoffAddress];
}
