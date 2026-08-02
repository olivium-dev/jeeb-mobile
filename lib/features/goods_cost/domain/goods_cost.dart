import 'package:equatable/equatable.dart';

class GoodsCost extends Equatable {
  const GoodsCost({
    required this.deliveryId,
    required this.amount,
    required this.currency,
  });

  final String deliveryId;

  final double amount;

  final String currency;

  @override
  List<Object?> get props => [deliveryId, amount, currency];
}
