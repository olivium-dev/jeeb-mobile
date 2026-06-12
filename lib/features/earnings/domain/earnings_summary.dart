import 'package:equatable/equatable.dart';

class EarningsSummary extends Equatable {
  const EarningsSummary({
    required this.totalEarnings,
    required this.currency,
    required this.deliveryCount,
    required this.commission,
    required this.netPayout,
    required this.periodLabel,
    this.averageRating,
  });

  factory EarningsSummary.fromJson(Map<String, dynamic> json) {
    return EarningsSummary(
      totalEarnings: json['totalEarnings'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'LBP',
      deliveryCount: json['deliveryCount'] as int? ?? 0,
      commission: json['commission'] as int? ?? 0,
      netPayout: json['netPayout'] as int? ?? 0,
      periodLabel: json['periodLabel'] as String? ?? 'This month',
      averageRating: (json['averageRating'] as num?)?.toDouble(),
    );
  }

  final int totalEarnings;
  final String currency;
  final int deliveryCount;
  final int commission;
  final int netPayout;
  final String periodLabel;
  final double? averageRating;

  @override
  List<Object?> get props => [
        totalEarnings,
        currency,
        deliveryCount,
        commission,
        netPayout,
        periodLabel,
        averageRating,
      ];
}
