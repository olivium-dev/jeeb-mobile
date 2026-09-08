import '../../../core/network/app_failure.dart';
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
  const EarningsRepositoryException(this.kind, [this.cause, this.failure]);

  final EarningsErrorKind kind;
  final Object? cause;

  /// The classified transport failure, so a 5xx and a 4xx no longer render the
  /// same dead end (NET-09). Never rendered verbatim.
  final AppFailure? failure;

  @override
  String toString() => 'EarningsRepositoryException(${kind.name})';
}

enum EarningsErrorKind { network, server, parse }
