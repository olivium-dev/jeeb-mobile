import '../../../core/network/app_failure.dart';
import '../domain/goods_cost.dart';
import '../domain/goods_cost_repository.dart';

/// Release-path stand-in for an unregistered [GoodsCostRepository]: it fails
/// rather than pop a fabricated success (GEN-01).
class UnavailableGoodsCostRepository implements GoodsCostRepository {
  const UnavailableGoodsCostRepository();

  @override
  Future<String> fetchCurrency(String deliveryId) => Future<String>.error(
    const GoodsCostRepositoryException(GoodsCostFailure.currencyUnavailable),
  );

  @override
  Future<GoodsCost> recordGoodsCost({
    required String deliveryId,
    required double amount,
  }) => Future<GoodsCost>.error(
    const GoodsCostRepositoryException(
      GoodsCostFailure.unknown,
      cause: UnknownFailure(),
    ),
  );
}
