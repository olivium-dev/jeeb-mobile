// Designed states for `EarningsDashboardScreen` (JM-052 earnings-fees-dashboard)

import 'dart:async';

import '../../../core/network/app_failure.dart';
import '../../../features/earnings/domain/earnings_repository.dart';
import '../../../features/earnings/domain/earnings_summary.dart';

/// Answers one canned [EarningsSummary] for every period, with no latency.
/// Period-independent on purpose: tapping a period pill in the canvas or the
/// catalog re-runs the load and lands on the SAME designed state, so a reviewer
class SeededEarningsRepository implements EarningsRepository {
  const SeededEarningsRepository(this._summary);

  final EarningsSummary _summary;

  @override
  Future<EarningsSummary> fetchEarnings({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async =>
      _summary;

  @override
  Future<String> exportEarningsPdf({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async =>
      throw const EarningsRepositoryException(EarningsErrorKind.network);
}

/// Every read throws — the cold-load failure that reaches the `OmdsErrorState`
/// body.
/// [kind] is carried even though the screen currently discards it: the body
class FailingEarningsRepository implements EarningsRepository {
  const FailingEarningsRepository([
    this.kind = EarningsErrorKind.network,
    this.failure,
  ]);

  final EarningsErrorKind kind;

  /// The classified failure the rung renders; null falls back to [kind].
  final AppFailure? failure;

  @override
  Future<EarningsSummary> fetchEarnings({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async =>
      throw EarningsRepositoryException(kind, null, failure);

  @override
  Future<String> exportEarningsPdf({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async =>
      throw EarningsRepositoryException(kind, null, failure);
}

/// A cold load that lands and every read after it that fails — the warm
/// failure note over a dashboard the jeeber is still reading (LR-16).
class RefreshFailingEarningsRepository implements EarningsRepository {
  RefreshFailingEarningsRepository(this._summary);

  final EarningsSummary _summary;

  bool _served = false;

  @override
  Future<EarningsSummary> fetchEarnings({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async {
    if (_served) {
      throw const EarningsRepositoryException(
        EarningsErrorKind.network,
        null,
        NetworkFailure(),
      );
    }
    _served = true;
    return _summary;
  }

  @override
  Future<String> exportEarningsPdf({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async =>
      throw const EarningsRepositoryException(EarningsErrorKind.network);
}

/// A dashboard that loads and an export that fails — the export snack.
class ExportFailingEarningsRepository implements EarningsRepository {
  const ExportFailingEarningsRepository(this._summary);

  final EarningsSummary _summary;

  @override
  Future<EarningsSummary> fetchEarnings({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async =>
      _summary;

  @override
  Future<String> exportEarningsPdf({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async =>
      throw const EarningsRepositoryException(
        EarningsErrorKind.server,
        null,
        ServerFailure(status: 500),
      );
}

/// The 5xx cold load — a retryable rung whose body must NOT blame the network.
const FailingEarningsRepository serverFailingEarningsRepository =
    FailingEarningsRepository(
  EarningsErrorKind.server,
  ServerFailure(status: 500),
);

/// The offline cold load — the one rung allowed to blame connectivity.
const FailingEarningsRepository networkFailingEarningsRepository =
    FailingEarningsRepository(
  EarningsErrorKind.network,
  NetworkFailure(offline: true),
);

/// A read that never resolves, freezing the screen on
/// `EarningsViewMode.loading` for as long as the host is open.
/// A [Completer] that is never completed holds no timer and no subscription; it
class StalledEarningsRepository implements EarningsRepository {
  const StalledEarningsRepository();

  @override
  Future<EarningsSummary> fetchEarnings({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) =>
      Completer<EarningsSummary>().future;

  @override
  Future<String> exportEarningsPdf({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) =>
      Completer<String>().future;
}

/// The designed states of `EarningsDashboardScreen`, as summaries plus the
/// repositories that answer with them.
class EarningsDashboardScreenPreviewFixtures {
  const EarningsDashboardScreenPreviewFixtures._();

  // ───────────────────────────── the summaries ─────────────────────────────

  /// Catalog "Populated — cash + fees + breakdown": a week with cash collected
  /// off-wallet, fees captured from the wallet, a join date and two breakdown
  static const EarningsSummary populatedWeek = EarningsSummary(
    totalCashEarned: 245,
    feesPaid: 24.5,
    currency: 'USD',
    deliveryCount: 7,
    memberSince: '2025-11-03T00:00:00Z',
    deliveries: <EarningsDeliveryItem>[
      EarningsDeliveryItem(
        deliveryId: 'ORD-4821',
        date: '2026-07-04T18:20:00Z',
        cashCollected: 35,
        feePaid: 3.5,
        currency: 'USD',
      ),
      EarningsDeliveryItem(
        deliveryId: 'ORD-4790',
        date: '2026-07-02T12:05:00Z',
        cashCollected: 50,
        feePaid: 5,
        currency: 'USD',
      ),
    ],
  );

  /// Catalog "Empty — no earnings this period": the all-zero summary
  /// [EarningsSummary.isEmpty] is the T11 / SW-01 guard for.
  static const EarningsSummary emptyPeriod = EarningsSummary(
    totalCashEarned: 0,
    feesPaid: 0,
    currency: 'USD',
    deliveryCount: 0,
  );

  /// Rollup totals with NO per-delivery rows and NO join date.
  /// Structurally reachable from the live wire, not a stress shape:
  static const EarningsSummary totalsOnly = EarningsSummary(
    totalCashEarned: 312.75,
    feesPaid: 31.28,
    currency: 'USD',
    deliveryCount: 9,
  );

  /// The layout ceiling: a busy month in Lebanese pounds, on a join date the
  /// wire did not send as ISO-8601.
  static const EarningsSummary longestContent = EarningsSummary(
    totalCashEarned: 128450000,
    feesPaid: 12845000,
    currency: 'LBP',
    deliveryCount: 1284,
    memberSince: '1730592000',
    deliveries: <EarningsDeliveryItem>[
      EarningsDeliveryItem(
        deliveryId: 'ORD-4821-REDELIVERY-ATTEMPT-3',
        date: '2026-07-04T18:20:00Z',
        cashCollected: 1450000,
        feePaid: 145000,
        currency: 'LBP',
      ),
      EarningsDeliveryItem(
        deliveryId: 'ORD-4790-EXPRESS-PHARMACY-RUN-BEIRUT-HAMRA',
        date: '2026-07-02T12:05:00Z',
        cashCollected: 2300000,
        feePaid: 230000,
        currency: 'LBP',
      ),
    ],
  );

  // ──────────────────────────── the repositories ───────────────────────────

  /// Catalog "Populated — cash + fees + breakdown".
  static EarningsRepository populated() =>
      const SeededEarningsRepository(populatedWeek);

  /// Catalog "Empty — no earnings this period (T11/SW-01 honest empty)".
  static EarningsRepository empty() =>
      const SeededEarningsRepository(emptyPeriod);

  /// Totals with an empty breakdown — see [totalsOnly].
  static EarningsRepository totalsWithoutRows() =>
      const SeededEarningsRepository(totalsOnly);

  /// The layout ceiling — see [longestContent].
  static EarningsRepository longest() =>
      const SeededEarningsRepository(longestContent);

  /// The cold read fails.
  static EarningsRepository failingLoad() => const FailingEarningsRepository();

  /// The cold read never resolves — the screen's loading body.
  static EarningsRepository stalledLoad() => const StalledEarningsRepository();
}
