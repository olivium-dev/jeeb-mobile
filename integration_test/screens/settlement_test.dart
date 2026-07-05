// Isolated native UI test — SettlementScreen (jeeber-settlement, T-MOB-032).
// The screen builds a SettlementCubit from the `repository` seam and calls
// loadStatements(), so injecting a scripted fake avoids DI/network. Covers the
// populated list (paid + pending chips), the empty state, and the load error.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/settlement/domain/settlement_repository.dart';
import 'package:jeeb_mobile/features/settlement/domain/settlement_statement.dart';
import 'package:jeeb_mobile/features/settlement/presentation/settlement_screen.dart';

import '../support/screen_harness.dart';

class _FakeSettlementRepo implements SettlementRepository {
  const _FakeSettlementRepo(this._statements, {this.throwsList = false});
  final List<SettlementStatement> _statements;
  final bool throwsList;
  @override
  Future<List<SettlementStatement>> fetchStatements() async {
    if (throwsList) throw const SettlementException(SettlementFailure.server);
    return _statements;
  }

  @override
  Future<String> downloadPdf(String statementId) async => 'stub.pdf';
}

const _statements = <SettlementStatement>[
  SettlementStatement(
    id: 'stmt-2026-w26',
    weekLabel: 'Jun 22 – Jun 28, 2026',
    totalPayout: 312.50,
    currency: 'USD',
    status: SettlementStatus.paid,
    deliveries: [],
  ),
  SettlementStatement(
    id: 'stmt-2026-w27',
    weekLabel: 'Jun 29 – Jul 5, 2026',
    totalPayout: 148.00,
    currency: 'USD',
    status: SettlementStatus.pending,
    deliveries: [],
  ),
];

SettlementScreen _settlement({
  List<SettlementStatement> statements = const [],
  bool throwsList = false,
}) =>
    SettlementScreen(
      repository: _FakeSettlementRepo(statements, throwsList: throwsList),
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('settlement: populated statements (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _settlement(statements: _statements),
      'settlement__populated',
    );
  });

  testWidgets('settlement: empty statements (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _settlement(),
      'settlement__empty',
    );
  });

  testWidgets('settlement: load error (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _settlement(throwsList: true),
      'settlement__error-ar',
      locale: const Locale('ar'),
    );
  });
}
