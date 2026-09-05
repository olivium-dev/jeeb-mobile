import 'package:dio/dio.dart';

import '../../../core/network/app_failure.dart';
import '../../active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import '../domain/active_deliveries_repository.dart';
import '../domain/active_delivery_summary.dart';

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
    } on DioException catch (e) {
      throw AppFailure.of(e);
    }
  }

  List<ActiveDeliverySummary> _parse(Map<String, dynamic> data) {
    final items = data['items'] as List? ?? const <dynamic>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(ActiveDeliverySummary.fromJson)
        .where((d) => d.id.isNotEmpty && !d.status.isTerminal)
        .toList(growable: false);
  }
}
