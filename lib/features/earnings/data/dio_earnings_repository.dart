import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/network/app_failure.dart';
import '../domain/earnings_repository.dart';
import '../domain/earnings_summary.dart';

class DioEarningsRepository implements EarningsRepository {
  DioEarningsRepository(this._dio);

  final Dio _dio;

  static const _basePath = '/v1/jeeb/earnings';
  static const _exportPath = '/v1/jeeb/earnings/export';

  @override
  Future<EarningsSummary> fetchEarnings({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _basePath,
        queryParameters: {
          if (jeeberId.isNotEmpty) 'jeeberId': jeeberId,
          'period': _periodParam(period),
        },
      );
      final data = response.data;
      if (data == null) {
        throw const EarningsRepositoryException(
          EarningsErrorKind.parse,
          null,
          UnknownFailure(parse: true),
        );
      }
      // `fromJson` casts with `as`, so a wrong-typed field raises a TypeError
      // that no `on FormatException` would ever catch (EARN-01).
      try {
        return EarningsSummary.fromJson(data);
      } catch (e) {
        throw EarningsRepositoryException(
          EarningsErrorKind.parse,
          e,
          const UnknownFailure(parse: true),
        );
      }
    } on EarningsRepositoryException {
      rethrow;
    } on DioException catch (e) {
      throw _map(AppFailure.of(e), e);
    } catch (e) {
      throw EarningsRepositoryException(
        EarningsErrorKind.server,
        e,
        AppFailure.of(e),
      );
    }
  }

  @override
  Future<String> exportEarningsPdf({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/earnings_${_periodParam(period)}.pdf';
      await _dio.download(
        _exportPath,
        filePath,
        queryParameters: {
          if (jeeberId.isNotEmpty) 'jeeberId': jeeberId,
          'format': 'pdf',
          'period': _periodParam(period),
        },
      );
      return filePath;
    } on DioException catch (e) {
      throw _map(AppFailure.of(e), e);
    } catch (e) {
      // `getTemporaryDirectory()` raises MissingPluginException on a host with
      // no path_provider — it must not pin the CTA on `exporting`.
      throw EarningsRepositoryException(
        EarningsErrorKind.server,
        e,
        AppFailure.of(e),
      );
    }
  }

  EarningsRepositoryException _map(AppFailure f, Object cause) {
    final kind = switch (f) {
      NetworkFailure() || TimeoutFailure() => EarningsErrorKind.network,
      _ => EarningsErrorKind.server,
    };
    return EarningsRepositoryException(kind, cause, f);
  }

  static String _periodParam(EarningsPeriod period) {
    switch (period) {
      case EarningsPeriod.today:
        return 'today';
      case EarningsPeriod.week:
        return 'week';
      case EarningsPeriod.month:
        return 'month';
    }
  }
}
