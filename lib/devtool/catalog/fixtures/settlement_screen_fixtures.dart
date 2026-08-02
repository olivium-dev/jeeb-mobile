// Shared dev-only fixtures for `SettlementScreen` (T-MOB-032).
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entry
//     (`lib/devtool/catalog/entries/batch_10_entries.dart`), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/settlement/presentation/settlement_screen.dart`.
//
// The catalog owned two private fakes (`_FakeSettlementRepository`,
// `_PendingSettlementRepository`); copying those into the preview section
// would have given the two surfaces two different fakes, free to drift. Both
// now import this file, so a change to the fixture behaviour shows up in the
// catalog and in the canvas together.
//
// The STATEMENTS the list renders are deliberately NOT declared here.
// `settlement_detail_screen_fixtures.dart` owns them, because the detail
// screen is what a row on this list opens: tapping row 1 must show the week
// row 1 describes, and two files declaring "week stmt-1" is exactly the drift
// this arrangement exists to prevent. [settlementScreenListedWeeks] is a local
// name for that shared list, so this file has one line to change if it moves.
//
// Everything here is a LOCAL fake: `SettlementScreen` takes a `repository:`
// AND a `cubit:` seam, so neither surface ever resolves the Dio-backed
// repository out of GetIt — `sl<SettlementRepository>()` (app_router.dart,
// the `/jeeber/settlement` route) is never reached. Network-free by
// construction, not merely by the `CatalogNetworkGuard` both hosts install.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

import 'dart:async';

import 'package:jeeb_mobile/features/settlement/application/settlement_cubit.dart';
import 'package:jeeb_mobile/features/settlement/domain/settlement_repository.dart';
import 'package:jeeb_mobile/features/settlement/domain/settlement_statement.dart';

import 'settlement_detail_screen_fixtures.dart';

/// The two designed weeks the statements LIST renders, owned by the detail
/// screen's fixtures and aliased here.
///
/// One indirection, on purpose: the list and the breakdown are the same data
/// seen twice, and the only way they cannot disagree is for one of them to
/// stop declaring it. If that list is ever renamed or moved, this is the one
/// line in the `SettlementScreen` fixtures that has to change.
const List<SettlementStatement> settlementScreenListedWeeks =
    settlementDetailScreenSampleWeeks;

/// A failure the data layer can produce that is NOT a [SettlementException].
///
/// `SettlementCubit.loadStatements` catches `on SettlementException` only, so
/// anything else — a `TypeError` out of `SettlementStatement.fromJson` on a
/// changed payload, a `DioException` that escaped the repository, a
/// `FormatException` — escapes the cubit entirely: no `error` state is ever
/// emitted and the screen is left on its spinner. This type exists so that
/// state is reachable from a fixture and can be looked at.
class SettlementScreenUnmappedFailure implements Exception {
  const SettlementScreenUnmappedFailure();

  @override
  String toString() =>
      'SettlementScreenUnmappedFailure: the data layer threw something that is '
      'not a SettlementException';
}

/// Canned [SettlementRepository]. No Dio, no GetIt, no network.
///
/// `const`-constructible so both hosts can keep building
/// `const SettlementScreen(repository: ...)`.
class SettlementScreenFakeRepository implements SettlementRepository {
  const SettlementScreenFakeRepository({
    this.statements,
    this.fetchFailure,
    this.fetchThrowsUnmapped = false,
    this.downloadFailure,
    this.downloadPending = false,
  });

  /// What `GET /v1/wallet/jeeb/earnings/statements` resolves to. `null` is the
  /// empty list — the "no statements yet" surface, not a failure.
  final List<SettlementStatement>? statements;

  /// When non-null the list read throws a [SettlementException] carrying this
  /// typed failure, which is how the live repository fails. The specific value
  /// picks which of the four `_mapError` strings the screen renders.
  final SettlementFailure? fetchFailure;

  /// When true the list read throws a [SettlementScreenUnmappedFailure] — a
  /// failure the cubit's `on SettlementException` clause does not catch.
  final bool fetchThrowsUnmapped;

  /// When non-null the PDF read throws a [SettlementException] carrying this
  /// typed failure, which drives the export-error snackbar.
  final SettlementFailure? downloadFailure;

  /// When true the PDF read never lands, holding the screen on
  /// `SettlementExportMode.exporting` for as long as the surface is open.
  final bool downloadPending;

  @override
  Future<List<SettlementStatement>> fetchStatements() async {
    if (fetchThrowsUnmapped) throw const SettlementScreenUnmappedFailure();
    final SettlementFailure? f = fetchFailure;
    if (f != null) throw SettlementException(f);
    return statements ?? const <SettlementStatement>[];
  }

  @override
  Future<String> downloadPdf(String statementId) {
    if (downloadPending) return Completer<String>().future;
    final SettlementFailure? f = downloadFailure;
    if (f != null) {
      return Future<String>.error(SettlementException(f));
    }
    return Future<String>.value('/tmp/statement-$statementId.pdf');
  }
}

/// A list read that never lands, holding the screen on
/// `SettlementListMode.loading`.
///
/// The cubit emits `loading` from `loadStatements()` and only leaves it when
/// the future completes, so this is the only way to inspect the centered
/// spinner without a real slow connection.
class SettlementScreenPendingRepository extends SettlementScreenFakeRepository {
  const SettlementScreenPendingRepository() : super(downloadPending: true);

  @override
  Future<List<SettlementStatement>> fetchStatements() =>
      Completer<List<SettlementStatement>>().future;
}

/// The layout ceiling for the LIST — the worst page the gateway plausibly
/// returns, front-loaded so the awkward rows are the ones a reviewer (and the
/// render test) sees first:
///
///   * row 0 carries the longest week label a period can produce (a
///     year-boundary range with an adjustment note) beside a five-figure
///     payout — the pair that starves the row's text column, since the status
///     chip and the download button sit in a trailing [Column] that is NOT
///     inside the `Expanded`;
///   * row 1 is what `SettlementStatement.fromJson` builds when the gateway
///     omits `weekLabel`/`periodLabel` and `totalPayout`: `''` and `0.0`. It
///     is a REAL 200 response, and it renders a card whose title line is
///     blank;
///   * row 2 is the same blank-label case with a payout, so the two are
///     distinguishable in the canvas;
///   * rows 3-9 are ordinary alternating weeks that fill the page past one
///     screen, so the scroll behaviour and the card rhythm are real.
List<SettlementStatement> settlementScreenLongestStatements() =>
    <SettlementStatement>[
      const SettlementStatement(
        id: 'stmt-long',
        weekLabel:
            'Dec 29, 2025 – Jan 4, 2026 (year-boundary adjustment, includes '
            'the Dec 24 surge correction)',
        totalPayout: 12345.67,
        currency: 'USD',
        status: SettlementStatus.pending,
        deliveries: <SettlementDeliveryLine>[],
      ),
      const SettlementStatement(
        id: 'stmt-blank',
        weekLabel: '',
        totalPayout: 0,
        currency: 'USD',
        status: SettlementStatus.pending,
        deliveries: <SettlementDeliveryLine>[],
      ),
      const SettlementStatement(
        id: 'stmt-blank-paid',
        weekLabel: '',
        totalPayout: 42.75,
        currency: 'USD',
        status: SettlementStatus.paid,
        deliveries: <SettlementDeliveryLine>[],
      ),
      for (int i = 3; i <= 9; i++)
        SettlementStatement(
          id: 'stmt-page-$i',
          weekLabel: 'Week $i, 2026',
          totalPayout: 60 + i * 7.5,
          currency: 'USD',
          status: i.isEven ? SettlementStatus.paid : SettlementStatus.pending,
          deliveries: const <SettlementDeliveryLine>[],
        ),
    ];

/// Drives one PDF export the way a user drives it: load the list, then tap
/// download on [statementId].
///
/// Both export states — `exporting` and the export `error` — are emitted by
/// `SettlementCubit.downloadPdf`, and only a tap calls it, so there is no fake
/// repository shape that produces them on its own. Which of the two you land
/// on is decided by the fake: `downloadPending: true` parks on `exporting`,
/// `downloadFailure:` lands on `error`.
///
/// WHEN this runs matters, which is why it is a function the caller schedules
/// rather than something a cubit factory does for you. `_Body` reacts to the
/// export result in a `BlocConsumer.listener`, and a listener only sees
/// changes that happen AFTER it subscribes — drive the cubit before the screen
/// is mounted and the export snackbar never appears at all. The preview host
/// calls this from a post-frame callback for exactly that reason.
void settlementScreenDriveExport(SettlementCubit cubit, String statementId) {
  unawaited(
    cubit.loadStatements().then((_) => cubit.downloadPdf(statementId)),
  );
}
