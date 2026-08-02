import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

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
        throw const EarningsRepositoryException(EarningsErrorKind.parse);
      }
      return EarningsSummary.fromJson(data);
    } on DioException catch (e) {
      throw EarningsRepositoryException(
        e.response == null ? EarningsErrorKind.network : EarningsErrorKind.server,
        e,
      );
    } on FormatException catch (e) {
      throw EarningsRepositoryException(EarningsErrorKind.parse, e);
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
      throw EarningsRepositoryException(
        e.response == null ? EarningsErrorKind.network : EarningsErrorKind.server,
        e,
      );
    } on IOException catch (e) {
      throw EarningsRepositoryException(EarningsErrorKind.parse, e);
    }
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
