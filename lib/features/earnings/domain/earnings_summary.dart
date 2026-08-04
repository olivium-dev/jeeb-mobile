import 'package:equatable/equatable.dart';

import '../../../core/jeeb_commission.dart';

const double kJeebFeeRate = kJeebCommissionRate;

class EarningsDeliveryItem extends Equatable {
  const EarningsDeliveryItem({
    required this.deliveryId,
    required this.date,
    required this.cashCollected,
    required this.feePaid,
    required this.currency,
  });

  factory EarningsDeliveryItem.fromJson(Map<String, dynamic> json) {
    final amount = json['amount'];
    final double cash = amount is Map<String, dynamic>
        ? _asDouble(amount['value']) ?? 0
        : _asDouble(json['gross']) ??
              _asDouble(json['net']) ??
              _asDouble(json['value']) ??
              0;
    final String currency = amount is Map<String, dynamic>
        ? amount['currency'] as String? ?? 'USD'
        : json['currency'] as String? ?? 'USD';
    final explicitFee = _asDouble(json['fee']) ?? _asDouble(json['commission']);
    return EarningsDeliveryItem(
      deliveryId: json['deliveryId'] as String? ?? '',
      date:
          json['syncedAt'] as String? ??
          json['deliveredAt'] as String? ??
          json['date'] as String? ??
          '',
      cashCollected: cash,
      feePaid: explicitFee ?? _deriveFee(cash),
      currency: currency,
    );
  }

  static double _deriveFee(double cashCollected) =>
      cashCollected * kJeebFeeRate;

  final String deliveryId;
  final String date;

  final double cashCollected;

  final double feePaid;
  final String currency;

  @override
  List<Object?> get props => [
    deliveryId,
    date,
    cashCollected,
    feePaid,
    currency,
  ];
}

class EarningsSummary extends Equatable {
  const EarningsSummary({
    required this.totalCashEarned,
    required this.feesPaid,
    required this.currency,
    required this.deliveryCount,
    this.memberSince,
    this.deliveries = const [],
  });

  factory EarningsSummary.fromJson(Map<String, dynamic> json) {
    final rawDeliveries =
        (json['items'] as List<dynamic>? ??
                json['entries'] as List<dynamic>? ??
                json['deliveries'] as List<dynamic>? ??
                const [])
            .whereType<Map<String, dynamic>>()
            .map(EarningsDeliveryItem.fromJson)
            .toList();

    final totalEarnings = json['totalEarnings'];
    final double totalCash = totalEarnings is Map<String, dynamic>
        ? _asDouble(totalEarnings['value']) ?? _sumCash(rawDeliveries)
        : _asDouble(totalEarnings) ??
              _asDouble(json['totalGross']) ??
              _asDouble(json['totalNet']) ??
              _sumCash(rawDeliveries);
    final String currency = totalEarnings is Map<String, dynamic>
        ? totalEarnings['currency'] as String? ??
              (rawDeliveries.isNotEmpty ? rawDeliveries.first.currency : 'USD')
        : json['currency'] as String? ??
              (rawDeliveries.isNotEmpty ? rawDeliveries.first.currency : 'USD');

    final totalFees = json['totalFees'];
    final explicitFees =
        _asDouble(json['feesPaid']) ??
        (totalFees is Map<String, dynamic>
            ? _asDouble(totalFees['value'])
            : _asDouble(totalFees)) ??
        _asDouble(json['totalCommission']);

    return EarningsSummary(
      totalCashEarned: totalCash,
      feesPaid: explicitFees ?? _sumFees(rawDeliveries),
      currency: currency,
      deliveryCount:
          _asInt(json['deliveryCount']) ??
          _asInt(json['rowCount']) ??
          rawDeliveries.length,
      memberSince:
          json['memberSince'] as String? ?? json['createdAt'] as String?,
      deliveries: rawDeliveries,
    );
  }

  static double _sumCash(List<EarningsDeliveryItem> items) =>
      items.fold(0, (sum, e) => sum + e.cashCollected);

  static double _sumFees(List<EarningsDeliveryItem> items) =>
      items.fold(0, (sum, e) => sum + e.feePaid);

  final double totalCashEarned;

  final double feesPaid;
  final String currency;
  final int deliveryCount;

  final String? memberSince;
  final List<EarningsDeliveryItem> deliveries;

  double get netPerOffer {
    if (deliveryCount == 0) return 0;
    return (totalCashEarned - feesPaid) / deliveryCount;
  }

  bool get isEmpty =>
      deliveryCount == 0 &&
      deliveries.isEmpty &&
      totalCashEarned <= 0 &&
      feesPaid <= 0;

  @override
  List<Object?> get props => [
    totalCashEarned,
    feesPaid,
    currency,
    deliveryCount,
    memberSince,
    deliveries,
  ];
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
