import 'goods_cost.dart';

enum GoodsCostFailure {
  network,

  notFound,

  validation,

  unknown,
}

class GoodsCostRepositoryException implements Exception {
  const GoodsCostRepositoryException(this.failure, [this.message]);
  final GoodsCostFailure failure;
  final String? message;

  @override
  String toString() => 'GoodsCostRepositoryException($failure, $message)';
}

abstract class GoodsCostRepository {
  Future<String> fetchCurrency(String deliveryId);

  Future<GoodsCost> recordGoodsCost({
    required String deliveryId,
    required double amount,
  });
}
