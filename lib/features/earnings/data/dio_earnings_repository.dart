import 'package:dio/dio.dart';

import '../domain/earnings_repository.dart';
import '../domain/earnings_summary.dart';

class DioEarningsRepository implements EarningsRepository {
  DioEarningsRepository(this._dio);

  final Dio _dio;

  static const _path = '/v1/jeeb/earnings';

  @override
  Future<EarningsSummary> fetchEarnings({required String jeeberId}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _path,
        queryParameters: {'jeeberId': jeeberId},
      );
      final data = response.data;
      if (data == null) {
        throw const EarningsRepositoryException(EarningsErrorKind.parse);
      }
      return EarningsSummary.fromJson(data);
    } on DioException catch (e) {
      throw EarningsRepositoryException(
        e.response == null
            ? EarningsErrorKind.network
            : EarningsErrorKind.server,
        e,
      );
    } on FormatException catch (e) {
      throw EarningsRepositoryException(EarningsErrorKind.parse, e);
    }
  }
}
