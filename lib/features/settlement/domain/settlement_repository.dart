import 'settlement_statement.dart';

/// Domain contract for settlement statements (T-MOB-032).
///
/// Endpoints verified against Mockoon :3055 (useMockPrefixes=false):
///   GET  /v1/wallet/jeeb/earnings/statements          → list of statements
///   GET  /v1/wallet/jeeb/earnings/statements/{id}/pdf → binary PDF
abstract class SettlementRepository {
  /// Fetch the list of weekly settlement statements.
  Future<List<SettlementStatement>> fetchStatements();

  /// Download the PDF for [statementId] and return the local file path.
  ///
  /// Throws [SettlementException] on failure.
  Future<String> downloadPdf(String statementId);
}

/// Typed failures for the settlement repository.
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
