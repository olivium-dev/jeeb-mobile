import 'earnings_summary.dart';

enum EarningsPeriod { today, week, month }

abstract class EarningsRepository {
  /// DEFECT-B: [jeeberId] is optional — the live gateway scopes earnings to the
  /// authenticated bearer token and ignores any `?jeeberId=` param. Production
  /// passes none (empty); the mock seam / tests may still supply a fixture id.
  Future<EarningsSummary> fetchEarnings({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  });

  /// Downloads the earnings PDF and returns the local file path.
  /// Endpoint: `GET /v1/jeeb/earnings/export?format=pdf&period=`
  /// (gateway-rewritten to `/wallet-service/v1/jeeb/earnings/export`).
  /// [jeeberId] is optional — see [fetchEarnings] (DEFECT-B).
  Future<String> exportEarningsPdf({
    String jeeberId = '',
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
