import 'package:dio/dio.dart';

import '../../active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import '../domain/active_deliveries_repository.dart';
import '../domain/active_delivery_summary.dart';

/// Dio-backed [ActiveDeliveriesRepository].
///
/// Endpoint (live gateway contract — `JeebOrdersListController.ListDeliveries`):
///   GET /v1/deliveries?role=jeeber
///     → { items: [ OrderListItem ], page, pageSize, totalCount, totalPages }
///
/// `role=jeeber` makes the gateway scope to the bearer jeeber's ASSIGNED
/// deliveries (the rows where `JeeberId == <caller>`) — the cross-client
/// available-jobs feed (`?status=pending`) and the owner-scoped client Orders
/// list (`?role=client`) are separate scopes. The identity comes from the
/// bearer, so no jeeber id is passed here (40_GUARDRAILS_ARCH §4 — never
/// hardcode an id/host/prefix).
class DioActiveDeliveriesRepository implements ActiveDeliveriesRepository {
  const DioActiveDeliveriesRepository(this._dio);

  final Dio _dio;

  static const String _path = '/v1/deliveries';

  @override
  Future<List<ActiveDeliverySummary>> listActive() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _path,
        queryParameters: const {'role': 'jeeber'},
      );
      return _parse(response.data ?? const <String, dynamic>{});
    } on DioException {
      return const <ActiveDeliverySummary>[];
    }
  }

  List<ActiveDeliverySummary> _parse(Map<String, dynamic> data) {
    final items = data['items'] as List? ?? const <dynamic>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(ActiveDeliverySummary.fromJson)
        // Every terminal (successful, cancelled, expired, or disputed) belongs
        // to history/support surfaces, never the active-delivery banner.
        .where((d) => d.id.isNotEmpty && !d.status.isTerminal)
        .toList(growable: false);
  }
}
