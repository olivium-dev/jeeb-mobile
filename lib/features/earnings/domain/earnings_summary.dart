import 'package:equatable/equatable.dart';

/// Fee rate applied to every won offer (D37 — exact 10%). The platform NEVER
/// takes a cut of the delivery price; the customer pays the full price in cash
/// directly to the Jeeber (off-wallet COD), and only this flat fee moves through
/// the wallet. This rate is the single source of truth for the fee-only reframe
/// (D41/D44) when the earnings endpoint does not surface an explicit fee total.
const double kJeebFeeRate = 0.10;

/// A single delivery's contribution to earnings (fee-only framing).
///
/// The mock `GET /wallet-service/v1/jeeb/earnings` entry shape is
/// `{ id, deliveryId, type, amount:{value,currency}, syncedAt }` — `amount` is
/// the **cash the Jeeber collected off-wallet** for that delivery (COD, D41).
/// The 10% fee (D37) is taken from the pre-charged wallet separately; the
/// earnings entry does not carry it, so it is derived per [kJeebFeeRate] unless
/// the wire surfaces an explicit `fee`.
class EarningsDeliveryItem extends Equatable {
  const EarningsDeliveryItem({
    required this.deliveryId,
    required this.date,
    required this.cashCollected,
    required this.feePaid,
    required this.currency,
  });

  factory EarningsDeliveryItem.fromJson(Map<String, dynamic> json) {
    // LIVE wire shape (gateway `GET /v1/jeeb/earnings` entry, §6B-confirmed):
    //   `{ deliveryId, gross, commission, net, currency, deliveredAt, tierName }`
    // — `net` is the cash the Jeeber keeps for that delivery (after the platform
    // commission), `commission` is the captured platform fee (D37). The legacy
    // mock shape `{ amount:{value,currency}, syncedAt }` is still tolerated
    // (defensive parse, §4) so the existing fixtures/tests keep passing.
    final amount = json['amount'];
    final double cash = (json['net'] as num?)?.toDouble() ??
        (amount is Map<String, dynamic>
            ? (amount['value'] as num?)?.toDouble() ?? 0
            : (json['value'] as num?)?.toDouble() ?? 0);
    final String currency = (json['currency'] as String?) ??
        (amount is Map<String, dynamic>
            ? amount['currency'] as String? ?? 'USD'
            : 'USD');
    // Explicit fee: the live `commission`, else a surfaced `fee`; otherwise
    // derive (D37).
    final explicitFee =
        (json['commission'] as num?)?.toDouble() ?? (json['fee'] as num?)?.toDouble();
    return EarningsDeliveryItem(
      deliveryId: json['deliveryId'] as String? ?? '',
      date: json['deliveredAt'] as String? ??
          json['syncedAt'] as String? ??
          json['date'] as String? ??
          '',
      cashCollected: cash,
      feePaid: explicitFee ?? _deriveFee(cash),
      currency: currency,
    );
  }

  /// The 10% fee implied by a cash-collected (off-wallet COD) amount. The COD
  /// the Jeeber collects IS the full delivery price, so the captured fee is a
  /// flat 10% of it (D37).
  static double _deriveFee(double cashCollected) => cashCollected * kJeebFeeRate;

  final String deliveryId;
  final String date;

  /// Cash collected directly from the customer (off-wallet COD, D41).
  final double cashCollected;

  /// The flat 10% platform fee captured from the wallet for this delivery (D37).
  final double feePaid;
  final String currency;

  @override
  List<Object?> get props => [deliveryId, date, cashCollected, feePaid, currency];
}

/// Fee-only earnings summary (D41/D44 reframe).
///
/// The economics are framed as **fee-only**, NOT gross/commission/net-payout
/// (the platform-takes-a-cut model the previous screen used, which violated
/// D41/D44):
///   * [totalCashEarned] — total cash the Jeeber collected directly from
///     customers, off-wallet (COD). This never moves through Jeeb.
///   * [feesPaid] — the total captured 10% platform fees (D37) the Jeeber paid
///     from their pre-charged wallet on won offers.
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
    // LIVE wire shape (gateway `GET /v1/jeeb/earnings`, §6B-confirmed):
    //   `{ rowCount, totalGross, totalCommission, totalNet, currency,
    //      entries:[{ deliveryId, gross, commission, net, ... }] }`
    // The previous parser keyed on `items`/`totalEarnings`/`feesPaid`/
    // `deliveryCount`, NONE of which the gateway emits — so every value bound to
    // 0 even though the 200 body carried real earnings (the §6B FAIL: net 115.37
    // rendered as 0.00). Read the real keys, keeping the legacy mock keys as
    // fallbacks so existing fixtures/tests are unaffected.
    final rawDeliveries = (json['entries'] as List<dynamic>? ??
            json['items'] as List<dynamic>? ??
            json['deliveries'] as List<dynamic>? ??
            const [])
        .whereType<Map<String, dynamic>>()
        .map(EarningsDeliveryItem.fromJson)
        .toList();

    // Total cash the Jeeber keeps (net, off-wallet COD): prefer the live
    // `totalNet` rollup, then the legacy `totalEarnings`, else sum the entries.
    final totalEarnings = json['totalEarnings'];
    final double totalCash = (json['totalNet'] as num?)?.toDouble() ??
        (totalEarnings is Map<String, dynamic>
            ? (totalEarnings['value'] as num?)?.toDouble() ??
                _sumCash(rawDeliveries)
            : (totalEarnings as num?)?.toDouble() ?? _sumCash(rawDeliveries));
    final String currency = (json['currency'] as String?) ??
        (totalEarnings is Map<String, dynamic>
            ? totalEarnings['currency'] as String? ??
                (rawDeliveries.isNotEmpty ? rawDeliveries.first.currency : 'USD')
            : (rawDeliveries.isNotEmpty ? rawDeliveries.first.currency : 'USD'));

    // Platform fees: prefer the live `totalCommission` rollup, then a surfaced
    // `feesPaid`/`totalFees`, else sum the per-delivery commission/derived fee.
    final explicitFees = (json['totalCommission'] as num?)?.toDouble() ??
        (json['feesPaid'] as num?)?.toDouble() ??
        ((json['totalFees'] as Map<String, dynamic>?)?['value'] as num?)
            ?.toDouble();

    return EarningsSummary(
      totalCashEarned: totalCash,
      feesPaid: explicitFees ?? _sumFees(rawDeliveries),
      currency: currency,
      deliveryCount: (json['rowCount'] as num?)?.toInt() ??
          json['deliveryCount'] as int? ??
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

  /// Total captured 10% platform fees paid from the wallet (D37).
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
