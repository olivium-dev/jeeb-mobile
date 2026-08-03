import 'earnings_summary.dart';

enum EarningsPeriod { today, week, month }

abstract class EarningsRepository {
  Future<EarningsSummary> fetchEarnings({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  });

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
