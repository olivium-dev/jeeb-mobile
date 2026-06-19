import '../domain/order_summary.dart';
import '../domain/order_summary_repository.dart';

/// In-memory [OrderSummaryRepository] test seam (JM-031).
///
/// NEVER registered in DI (guardrail §6.4) — it is a constructor override the
/// `OrderSummaryScreen` / `OrderSummaryPinned` host passes in widget tests, and
/// the safe default the standalone screen falls back to when GetIt has no
/// `OrderSummaryRepository` bound (so a cold dev-seam capture still renders a
/// representative summary instead of an error state).
class FakeOrderSummaryRepository implements OrderSummaryRepository {
  FakeOrderSummaryRepository({OrderSummary? summary, this.failure})
      : _summary = summary;

  final OrderSummary? _summary;

  /// When set, [fetchSummary] throws this failure instead of returning data.
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
