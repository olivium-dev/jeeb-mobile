import '../domain/order_summary.dart';
import '../domain/order_summary_repository.dart';

class FakeOrderSummaryRepository implements OrderSummaryRepository {
  FakeOrderSummaryRepository({OrderSummary? summary, this.failure})
      : _summary = summary;

  final OrderSummary? _summary;

  final OrderSummaryFailure? failure;

  @override
  Future<OrderSummary> fetchSummary(String deliveryId) async {
    final f = failure;
    if (f != null) throw OrderSummaryRepositoryException(f);
    return _summary ??
        OrderSummary(
          deliveryId: deliveryId,
          requestId: deliveryId,
          conversationId: '',
          price: 9.0,
          currency: 'USD',
          jeeberName: 'Kamal Hajj',
          tier: 'express',
          jeeberRating: 4.9,
          jeeberRatingCount: 312,
          etaMinutes: 20,
          itemSummary: 'Groceries from Spinneys',
        );
  }
}
