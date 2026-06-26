import 'package:equatable/equatable.dart';

/// The goods-cost declaration for a delivery: the amount the Jeeber paid for
/// the purchased goods up-front, which the Client reimburses on receipt
/// (qa/test-plan-settlement.md — `goods_cost = G`).
///
/// [currency] is the ISO code returned by the gateway VERBATIM — there is no
/// client-side currency math or conversion (40_GUARDRAILS_ARCH §5). The amount
/// the screen renders and the amount it records are the gross figure the Jeeber
/// typed; only the currency label is gateway-authoritative.
class GoodsCost extends Equatable {
  const GoodsCost({
    required this.deliveryId,
    required this.amount,
    required this.currency,
  });

  /// The delivery this cost belongs to.
  final String deliveryId;

  /// The gross goods cost the Jeeber declared (gateway-confirmed on record).
  final double amount;

  /// ISO currency code from the gateway (e.g. `USD`, `LBP`). Display-only.
  final String currency;

  @override
  List<Object?> get props => [deliveryId, amount, currency];
}
