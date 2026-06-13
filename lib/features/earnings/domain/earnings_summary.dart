import 'package:equatable/equatable.dart';

class EarningsDeliveryItem extends Equatable {
  const EarningsDeliveryItem({
    required this.deliveryId,
    required this.date,
    required this.tier,
    required this.fare,
    required this.commission,
    required this.currency,
  });

  factory EarningsDeliveryItem.fromJson(Map<String, dynamic> json) {
    return EarningsDeliveryItem(
      deliveryId: json['deliveryId'] as String? ?? '',
      date: json['date'] as String? ?? '',
      tier: json['tier'] as String? ?? '',
      fare: json['fare'] as int? ?? 0,
      commission: json['commission'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'LBP',
    );
  }

  final String deliveryId;
  final String date;
  final String tier;
  final int fare;
  final int commission;
  final String currency;

  @override
  List<Object?> get props => [deliveryId, date, tier, fare, commission, currency];
}

class EarningsSummary extends Equatable {
  const EarningsSummary({
    required this.totalEarnings,
    required this.currency,
    required this.deliveryCount,
    required this.commission,
    required this.netPayout,
    required this.periodLabel,
    this.averageRating,
    this.deliveries = const [],
  });

  factory EarningsSummary.fromJson(Map<String, dynamic> json) {
    final rawDeliveries = json['deliveries'] as List<dynamic>? ?? [];
    return EarningsSummary(
      totalEarnings: json['totalEarnings'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'LBP',
      deliveryCount: json['deliveryCount'] as int? ?? 0,
      commission: json['commission'] as int? ?? 0,
      netPayout: json['netPayout'] as int? ?? 0,
      periodLabel: json['periodLabel'] as String? ?? 'This month',
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      deliveries: rawDeliveries
          .whereType<Map<String, dynamic>>()
          .map(EarningsDeliveryItem.fromJson)
          .toList(),
    );
  }

  final int totalEarnings;
  final String currency;
  final int deliveryCount;
  final int commission;
  final int netPayout;
  final String periodLabel;
  final double? averageRating;
  final List<EarningsDeliveryItem> deliveries;

  @override
  List<Object?> get props => [
        totalEarnings,
        currency,
        deliveryCount,
        commission,
        netPayout,
        periodLabel,
        averageRating,
        deliveries,
      ];
}
