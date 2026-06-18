import 'earnings_summary.dart';

enum EarningsPeriod { today, week, month }

abstract class EarningsRepository {
  Future<EarningsSummary> fetchEarnings({
    required String jeeberId,
    EarningsPeriod period = EarningsPeriod.week,
  });

  /// Downloads the earnings PDF and returns the local file path.
  /// Endpoint: `GET /v1/wallet/jeeb/earnings/export?format=pdf&period=<period>`.
  Future<String> exportEarningsPdf({
    required String jeeberId,
    EarningsPeriod period = EarningsPeriod.week,
  });
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
