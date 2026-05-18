import 'earnings_summary.dart';

abstract class EarningsRepository {
  Future<EarningsSummary> fetchEarnings({required String jeeberId});
}

class EarningsRepositoryException implements Exception {
  const EarningsRepositoryException(this.kind, [this.cause]);

  final EarningsErrorKind kind;
  final Object? cause;

  @override
  String toString() =>
      'EarningsRepositoryException(${kind.name}${cause == null ? '' : ', $cause'})';
}

enum EarningsErrorKind { network, server, parse }
