import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/network/app_failure.dart';
import '../domain/settlement_repository.dart';
import '../domain/settlement_statement.dart';

class DioSettlementRepository implements SettlementRepository {
  const DioSettlementRepository(this._dio);

  final Dio _dio;

  static const _listPath = '/v1/wallet/jeeb/earnings/statements';

  @override
  Future<List<SettlementStatement>> fetchStatements() async {
    try {
      final response = await _dio.get<dynamic>(_listPath);
      return _parseList(response.data);
    } on SettlementException {
      rethrow;
    } on DioException catch (e) {
      throw _map(AppFailure.of(e));
    } catch (e) {
      throw SettlementException(
        SettlementFailure.server,
        cause: AppFailure.of(e),
      );
    }
  }

  @override
  Future<String> downloadPdf(String statementId) async {
    final path = '$_listPath/$statementId/pdf';
    try {
      final dir = await getTemporaryDirectory();
      final localPath = '${dir.path}/settlement_$statementId.pdf';
      await _dio.download(
        path,
        localPath,
        options: Options(responseType: ResponseType.bytes),
      );
      return localPath;
    } on DioException catch (e) {
      throw _map(AppFailure.of(e));
    } catch (e) {
      // `getTemporaryDirectory()` raises MissingPluginException on a host with
      // no path_provider, and a write raises FileSystemException (SET-01).
      throw SettlementException(
        SettlementFailure.fileWrite,
        cause: AppFailure.of(e),
      );
    }
  }

  /// `fromJson` casts with `as`, so a wrong-typed field raises a TypeError that
  /// used to escape every catch and pin the cubit on `loading` (SET-01).
  List<SettlementStatement> _parseList(dynamic data) {
    final Object? items = data is List
        ? data
        : (data is Map<String, dynamic> ? data['statements'] : null);
    // A body with no `statements` list is not "no statements" (§7-13a).
    if (items is! List) {
      throw const SettlementException(
        SettlementFailure.parse,
        cause: UnknownFailure(parse: true),
      );
    }
    try {
      return items
          .whereType<Map<String, dynamic>>()
          .map(SettlementStatement.fromJson)
          .toList(growable: false);
    } catch (e) {
      throw const SettlementException(
        SettlementFailure.parse,
        cause: UnknownFailure(parse: true),
      );
    }
  }

  SettlementException _map(AppFailure f) => switch (f) {
    NetworkFailure() || TimeoutFailure() => SettlementException(
      SettlementFailure.network,
      cause: f,
    ),
    NotFoundFailure() ||
    GoneFailure() => SettlementException(SettlementFailure.notFound, cause: f),
    _ => SettlementException(SettlementFailure.server, cause: f),
  };
}
