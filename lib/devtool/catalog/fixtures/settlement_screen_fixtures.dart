import 'dart:async';

import 'package:jeeb_mobile/features/settlement/application/settlement_cubit.dart';
import 'package:jeeb_mobile/features/settlement/domain/settlement_repository.dart';
import 'package:jeeb_mobile/features/settlement/domain/settlement_statement.dart';

import 'settlement_detail_screen_fixtures.dart';

/// The two designed weeks the statements LIST renders, owned by the detail
const List<SettlementStatement> settlementScreenListedWeeks =
    settlementDetailScreenSampleWeeks;

/// A failure the data layer can produce that is NOT a [SettlementException].
class SettlementScreenUnmappedFailure implements Exception {
  const SettlementScreenUnmappedFailure();

  @override
  String toString() =>
      'SettlementScreenUnmappedFailure: the data layer threw something that is '
      'not a SettlementException';
}

/// Canned [SettlementRepository]. No Dio, no GetIt, no network.
class SettlementScreenFakeRepository implements SettlementRepository {
  const SettlementScreenFakeRepository({
    this.statements,
    this.fetchFailure,
    this.fetchThrowsUnmapped = false,
    this.downloadFailure,
    this.downloadPending = false,
  });

  /// What `GET /v1/wallet/jeeb/earnings/statements` resolves to. `null` is the
  final List<SettlementStatement>? statements;

  /// When non-null the list read throws a [SettlementException] carrying this
  final SettlementFailure? fetchFailure;

  /// When true the list read throws a [SettlementScreenUnmappedFailure] — a
  final bool fetchThrowsUnmapped;

  /// When non-null the PDF read throws a [SettlementException] carrying this
  final SettlementFailure? downloadFailure;

  /// When true the PDF read never lands, holding the screen on
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
class SettlementScreenPendingRepository extends SettlementScreenFakeRepository {
  const SettlementScreenPendingRepository() : super(downloadPending: true);

  @override
  Future<List<SettlementStatement>> fetchStatements() =>
      Completer<List<SettlementStatement>>().future;
}

/// The layout ceiling for the LIST — the worst page the gateway plausibly
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
void settlementScreenDriveExport(SettlementCubit cubit, String statementId) {
  unawaited(
    cubit.loadStatements().then((_) => cubit.downloadPdf(statementId)),
  );
}
