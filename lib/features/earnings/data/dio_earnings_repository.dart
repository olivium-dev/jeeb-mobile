import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/earnings_repository.dart';
import '../domain/earnings_summary.dart';

/// Dio-backed [EarningsRepository].
///
/// Endpoint contract (JM-052 — path rewrite CONFIRMED, 20_GAP_MAP / AC):
///   GET  /v1/jeeb/earnings?jeeberId=&period={today|week|month}  → 200
///   GET  /v1/jeeb/earnings/export?jeeberId=&format=pdf&period=  → 200
///
/// The app posts the gateway-relative `/v1/jeeb/earnings`; `MockGatewayClient`
/// rewrites it to `/wallet-service/v1/jeeb/earnings` on :4010 (the live mount).
/// The previous path here was `/v1/wallet/jeeb/earnings`, which has NO rewrite
/// key and never reached the wallet-service — the divergence the JM-052 AC
/// flags ("confirm earnings path rewrite `/v1/wallet/jeeb/earnings*` vs
/// `/wallet-service/v1/...`"). Fixed to the keyed `/v1/jeeb/earnings`.
class DioEarningsRepository implements EarningsRepository {
  DioEarningsRepository(this._dio);

  final Dio _dio;

  static const _basePath = '/v1/jeeb/earnings';
  static const _exportPath = '/v1/jeeb/earnings/export';

  @override
  Future<EarningsSummary> fetchEarnings({
    required String jeeberId,
    EarningsPeriod period = EarningsPeriod.week,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _basePath,
        queryParameters: {
          'jeeberId': jeeberId,
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
    required String jeeberId,
    EarningsPeriod period = EarningsPeriod.week,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/earnings_${_periodParam(period)}.pdf';
      await _dio.download(
        _exportPath,
        filePath,
        queryParameters: {
          'jeeberId': jeeberId,
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
