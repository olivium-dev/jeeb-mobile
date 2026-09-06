import '../../../core/network/app_failure.dart';
import 'settlement_statement.dart';

abstract class SettlementRepository {
  Future<List<SettlementStatement>> fetchStatements();

  Future<String> downloadPdf(String statementId);
}

enum SettlementFailure { network, server, notFound, fileWrite, parse }

class SettlementException implements Exception {
  const SettlementException(this.failure, {this.cause});

  final SettlementFailure failure;

  /// The classified transport failure; never rendered verbatim (SET-02).
  final AppFailure? cause;

  @override
  String toString() => 'SettlementException(${failure.name})';
}
