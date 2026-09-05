import 'package:equatable/equatable.dart';

class GoodsCost extends Equatable {
  const GoodsCost({
    required this.deliveryId,
    required this.amount,
    this.currency,
  });

  final String deliveryId;

  final double amount;

  /// Null when the gateway sent none — a money screen never invents one.
  final String? currency;

  @override
  List<Object?> get props => [deliveryId, amount, currency];
}
