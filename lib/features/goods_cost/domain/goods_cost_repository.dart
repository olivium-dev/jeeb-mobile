import '../../../core/network/app_failure.dart';
import 'goods_cost.dart';

enum GoodsCostFailure {
  network,

  notFound,

  validation,

  /// The delivery carried no currency, so the amount's unit is unknown.
  currencyUnavailable,

  /// The write returned no amount, so nothing confirms what was recorded.
  amountUnconfirmed,

  unknown,
}

class GoodsCostRepositoryException implements Exception {
  const GoodsCostRepositoryException(this.failure, {this.cause});

  final GoodsCostFailure failure;

  /// The classified transport failure; never rendered verbatim.
  final AppFailure? cause;

  @override
  String toString() => 'GoodsCostRepositoryException(${failure.name})';
}

abstract class GoodsCostRepository {
  Future<String> fetchCurrency(String deliveryId);

  Future<GoodsCost> recordGoodsCost({
    required String deliveryId,
    required double amount,
  });
}
