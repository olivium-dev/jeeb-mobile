import 'package:equatable/equatable.dart';

import '../../../core/jeeb_commission.dart';

/// Legacy fallback fee rate for older mock payloads that omit explicit fees.
/// Live gateway payloads carry `commission`/`totalCommission`, and those values
/// are used instead of deriving a fee.
///
/// No longer holds its own literal. It was one of three unrelated copies of the
/// platform rate; it is now an alias of the single source,
/// [kJeebCommissionRate]. Kept as a name because it reads correctly at the one
/// call site that uses it (`_deriveFee`) and because deleting a public symbol
/// is a separate change from de-duplicating a number.
const double kJeebFeeRate = kJeebCommissionRate;

/// A single delivery's contribution to earnings (fee-only framing).
///
/// The legacy mock `GET /wallet-service/v1/jeeb/earnings` entry shape is
/// `{ id, deliveryId, type, amount:{value,currency}, syncedAt }`. The live
/// gateway shape is `{ deliveryId, gross, commission, currency, deliveredAt }`.
class EarningsDeliveryItem extends Equatable {
  const EarningsDeliveryItem({
    required this.deliveryId,
    required this.date,
    required this.cashCollected,
    required this.feePaid,
    required this.currency,
  });

  factory EarningsDeliveryItem.fromJson(Map<String, dynamic> json) {
    // Mock wire shape: `{ deliveryId, amount:{value,currency}, syncedAt }`.
    // Live gateway shape: `{ deliveryId, gross, commission, currency,
    // deliveredAt }`.
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
    // Explicit fee if the backend ever surfaces one; otherwise derive (D37).
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

  /// The fallback fee implied by a legacy mock cash-collected amount.
  static double _deriveFee(double cashCollected) =>
      cashCollected * kJeebFeeRate;

  final String deliveryId;
  final String date;

  /// Cash collected directly from the customer (off-wallet COD, D41).
  final double cashCollected;

  /// Platform fee captured from the wallet for this delivery.
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

/// Cash and fees earnings summary.
///
/// The economics are framed as cash collected and fees paid:
///   * [totalCashEarned] — total cash the Jeeber collected directly from
///     customers, off-wallet (COD). This never moves through Jeeb.
///   * [feesPaid] — the total platform fees the Jeeber paid from their
///     pre-charged wallet on won offers.
///   * [netPerOffer] — average cash kept per delivery after the fee.
///   * [memberSince] — the Jeeber's join date (NOT exposed when the wire omits
///     it — never fabricated).
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

    // Total cash earned (off-wallet COD): prefer the mock `totalEarnings`
    // rollup, then the live gateway `totalGross`, then the entry sum.
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

    // Fees paid: prefer explicit wire totals; live gateway calls this
    // `totalCommission`.
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

  /// Total cash collected directly from customers, off-wallet (COD, D41).
  final double totalCashEarned;

  /// Total platform fees paid from the wallet.
  final double feesPaid;
  final String currency;
  final int deliveryCount;

  /// The Jeeber's join date (ISO-8601), or null when the wire omits it.
  final String? memberSince;
  final List<EarningsDeliveryItem> deliveries;

  /// Average cash kept per delivery after the fee (net-per-offer, D44).
  double get netPerOffer {
    if (deliveryCount == 0) return 0;
    return (totalCashEarned - feesPaid) / deliveryCount;
  }

  /// True when the wire carries no earnings for the selected period — no
  /// deliveries, no cash, no fees. T11 / SW-01: the dashboard must render an
  /// honest empty/pending state here, NOT confident "0.00 USD earned · 0
  /// Deliveries · 0.00 fees" cards, which read as a betrayal ten minutes after a
  /// completed cash delivery. A real earnings row always moves at least one of
  /// these off zero, so all-zero means "nothing recorded yet", not "you earned
  /// exactly zero".
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
