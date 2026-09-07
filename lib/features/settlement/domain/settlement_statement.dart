import 'package:equatable/equatable.dart';

enum SettlementStatus { pending, paid }

extension SettlementStatusX on SettlementStatus {
  static SettlementStatus fromApi(String value) {
    if (value == 'paid') return SettlementStatus.paid;
    return SettlementStatus.pending;
  }
}

class SettlementDeliveryLine extends Equatable {
  const SettlementDeliveryLine({
    required this.deliveryId,
    required this.date,
    required this.tier,
    required this.fare,
    required this.commission,
    required this.net,
    required this.currency,
  });

  factory SettlementDeliveryLine.fromJson(Map<String, dynamic> json) {
    return SettlementDeliveryLine(
      deliveryId: json['deliveryId'] as String? ?? '',
      date: json['date'] as String? ?? '',
      tier: json['tier'] as String? ?? '',
      fare: (json['fare'] as num?)?.toDouble() ?? 0.0,
      commission: (json['commission'] as num?)?.toDouble() ?? 0.0,
      net: (json['net'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'USD',
    );
  }

  final String deliveryId;
  final String date;
  final String tier;
  final double fare;
  final double commission;
  final double net;
  final String currency;

  @override
  List<Object?> get props => [
    deliveryId,
    date,
    tier,
    fare,
    commission,
    net,
    currency,
  ];
}

class SettlementStatement extends Equatable {
  const SettlementStatement({
    required this.id,
    required this.weekLabel,
    required this.totalPayout,
    required this.currency,
    required this.status,
    required this.deliveries,
  });

  factory SettlementStatement.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status'] as String? ?? 'pending';
    final rawDeliveries = json['deliveries'] as List<dynamic>? ?? [];
    return SettlementStatement(
      id: json['id'] as String? ?? '',
      weekLabel:
          json['weekLabel'] as String? ?? json['periodLabel'] as String? ?? '',
      totalPayout: (json['totalPayout'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'USD',
      status: SettlementStatusX.fromApi(rawStatus),
      deliveries: rawDeliveries
          .whereType<Map<String, dynamic>>()
          .map(SettlementDeliveryLine.fromJson)
          .toList(growable: false),
    );
  }

  final String id;
  final String weekLabel;
  final double totalPayout;
  final String currency;
  final SettlementStatus status;
  final List<SettlementDeliveryLine> deliveries;

  @override
  List<Object?> get props => [
    id,
    weekLabel,
    totalPayout,
    currency,
    status,
    deliveries,
  ];
}
