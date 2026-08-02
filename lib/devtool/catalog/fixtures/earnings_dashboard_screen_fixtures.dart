// Designed states for `EarningsDashboardScreen` (JM-052 earnings-fees-dashboard)
// — ONE source of truth, two consumers.
//
//   lib/devtool/catalog/entries/batch_03_entries.dart   the designer-facing,
//                                                       on-device Screen Catalog
//   lib/features/earnings/presentation/
//     earnings_dashboard_screen.dart                    the JEEB PREVIEWS
//                                                       section at its bottom
//
// The catalog's two states (`Populated — cash + fees + breakdown`, `Empty — no
// earnings this period`) were hand-built inside the entry file behind a private
// `_FakeEarningsRepository` and a private `_earningsHost`. They moved here whole
// when the screen got a preview section, VALUES UNCHANGED, because two copies of
// the same "designed state" drift and the catalog is the one a designer signs
// off against. The four states the preview section adds beyond those two are
// engineer-facing and are deliberately not listed in the catalog.
//
// ## Why a repository and not a seeded state
//
// The screen has no cubit seam of its own: it reads `EarningsCubit` off a
// `BlocProvider` ancestor, and `EarningsCubit` has no `seed:` constructor — it
// takes an [EarningsRepository] and calls `loadEarnings()` from its own
// constructor body. So a designed state is described here by what the repository
// ANSWERS, and the real cold-load path runs in the catalog and in the canvas
// exactly as it does in production.
//
// NOTHING here touches the network. Every repository answers from a `const`
// summary, throws, or never completes. The `CatalogNetworkGuard` both hosts
// install is a net, not the plan.
//
// ## Exporting always FAILS here, in both hosts
//
// `EarningsDashboardScreen._onStateChange` hands a successful export path
// straight to `OpenFile.open` — a platform-channel call that has no
// implementation in the preview canvas and would open a nonexistent file on a
// designer's device. Every fixture below therefore fails `exportEarningsPdf`
// with the repository's own exception type, which `EarningsCubit.exportPdf`
// catches, so a stray tap on "Export PDF" lands inside the designed error path
// instead of a plugin exception. This is the same choice the `EarningsTab`
// preview fixtures already make.

import 'dart:async';

import '../../../features/earnings/domain/earnings_repository.dart';
import '../../../features/earnings/domain/earnings_summary.dart';

/// Answers one canned [EarningsSummary] for every period, with no latency.
///
/// Period-independent on purpose: tapping a period pill in the canvas or the
/// catalog re-runs the load and lands on the SAME designed state, so a reviewer
/// cannot accidentally leave the state they were sent to look at.
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
///
/// [kind] is carried even though the screen currently discards it: the body
/// renders the localized `earningsLoadFailed` and never reads
/// `state.errorMessage`, so `network`, `server` and `parse` are today
/// indistinguishable on screen. Keeping the axis here means a fixture already
/// exists the day that is fixed.
class FailingEarningsRepository implements EarningsRepository {
  const FailingEarningsRepository([this.kind = EarningsErrorKind.network]);

  final EarningsErrorKind kind;

  @override
  Future<EarningsSummary> fetchEarnings({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async =>
      throw EarningsRepositoryException(kind);

  @override
  Future<String> exportEarningsPdf({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async =>
      throw EarningsRepositoryException(kind);
}

/// A read that never resolves, freezing the screen on
/// `EarningsViewMode.loading` for as long as the host is open.
///
/// A [Completer] that is never completed holds no timer and no subscription; it
/// simply never settles.
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
  /// rows.
  ///
  /// Values are the catalog entry's, unchanged by the extraction.
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
  ///
  /// Structurally reachable from the live wire, not a stress shape:
  /// `EarningsSummary.fromJson` reads `deliveryCount` from `deliveryCount` /
  /// `rowCount` independently of the `items` array, and `memberSince` is null
  /// whenever the payload omits both `memberSince` and `createdAt`. So a
  /// paginated or rollup-only response lands exactly here — nine deliveries
  /// counted, none listed.
  static const EarningsSummary totalsOnly = EarningsSummary(
    totalCashEarned: 312.75,
    feesPaid: 31.28,
    currency: 'USD',
    deliveryCount: 9,
  );

  /// The layout ceiling: a busy month in Lebanese pounds, on a join date the
  /// wire did not send as ISO-8601.
  ///
  /// Three things are long at once. `MoneyFormat` renders non-USD as
  /// `LBP 128,450,000.00` — the widest money token this screen can emit, in the
  /// launch market's own currency, not an invented one. The delivery ids are
  /// gateway-shaped and long enough to contest the `ListTile` title against its
  /// trailing amount.
  ///
  /// And `memberSince` is epoch SECONDS delivered as a string, which
  /// `EarningsSummary.fromJson` accepts (it only casts to `String?`) and
  /// `_MemberSinceRow._formatDate` then mis-parses rather than rejects:
  /// `DateTime.tryParse('1730592000')` reads it as the basic-ISO
  /// `yyyyyy-mm-dd` `173059-20-00`, normalizes the out-of-range month, and
  /// returns `173060-07-31`. The `tryParse == null` fallback never fires, so the
  /// row renders a confident "Jul 173060". Do not "fix" this fixture by making
  /// it ISO — the wrong date is the point.
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
