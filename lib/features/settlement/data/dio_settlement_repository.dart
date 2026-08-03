import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

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
    } on DioException catch (e) {
      throw _mapError(e);
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
      throw _mapError(e);
    } on FileSystemException {
      throw const SettlementException(SettlementFailure.fileWrite);
    }
  }

  List<SettlementStatement> _parseList(dynamic data) {
    final items = data is List
        ? data
        : (data is Map<String, dynamic>
            ? (data['statements'] as List<dynamic>? ?? [])
            : <dynamic>[]);
    return items
        .whereType<Map<String, dynamic>>()
        .map(SettlementStatement.fromJson)
        .toList(growable: false);
  }

  SettlementException _mapError(DioException e) {
    if (e.response?.statusCode == 404) {
      return const SettlementException(SettlementFailure.notFound);
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return const SettlementException(SettlementFailure.network);
    }
    return SettlementException(
      SettlementFailure.server,
      'HTTP ${e.response?.statusCode}',
    );
  }
}
