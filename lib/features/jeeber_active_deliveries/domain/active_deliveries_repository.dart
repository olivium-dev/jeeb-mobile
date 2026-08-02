import 'active_delivery_summary.dart';

abstract class ActiveDeliveriesRepository {
  Future<List<ActiveDeliverySummary>> listActive();
}
