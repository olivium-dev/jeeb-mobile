import '../domain/goods_cost.dart';
import '../domain/goods_cost_repository.dart';

/// In-memory [GoodsCostRepository] for widget tests and the DI-less screen
/// fallback (NEVER the production default — 40_GUARDRAILS_ARCH §6/DO-NOT;
/// production resolves the Dio impl). Mirrors `FakeDeliveryReceiptRepository`.
class FakeGoodsCostRepository implements GoodsCostRepository {
  FakeGoodsCostRepository({
    this.currency = 'USD',
    this.fetchFailure,
    this.recordFailure,
  });

  /// Currency the fake reports for the entry-field label.
  final String currency;
  final GoodsCostFailure? fetchFailure;
  final GoodsCostFailure? recordFailure;

  GoodsCost? recorded;

  @override
  Future<String> fetchCurrency(String deliveryId) async {
    final failure = fetchFailure;
    if (failure != null) {
      throw GoodsCostRepositoryException(failure);
    }
    return currency;
  }

  @override
  Future<GoodsCost> recordGoodsCost({
    required String deliveryId,
    required double amount,
  }) async {
    final failure = recordFailure;
    if (failure != null) {
      throw GoodsCostRepositoryException(failure);
    }
    final result = GoodsCost(
      deliveryId: deliveryId,
      amount: amount,
      currency: currency,
    );
    recorded = result;
    return result;
  }
}
