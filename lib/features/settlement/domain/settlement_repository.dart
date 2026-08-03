import 'settlement_statement.dart';

abstract class SettlementRepository {
  Future<List<SettlementStatement>> fetchStatements();

  Future<String> downloadPdf(String statementId);
}

enum SettlementFailure { network, server, notFound, fileWrite }

class SettlementException implements Exception {
  const SettlementException(this.failure, [this.message]);

  final SettlementFailure failure;
  final String? message;

  @override
  String toString() =>
      'SettlementException(${failure.name}'
      '${message == null ? '' : ': $message'})';
}
