// Isolated native UI test — SettlementDetailScreen (jeeber-settlement-detail,
// T-MOB-032 AC2). The screen is a pure view over a required `statement` (no
// repository/cubit), so we pump it directly with an inline fixture. Covers a
// paid statement with per-delivery breakdown, a pending statement, and the paid
// statement in Arabic.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/settlement/domain/settlement_statement.dart';
import 'package:jeeb_mobile/features/settlement/presentation/settlement_detail_screen.dart';

import '../support/screen_harness.dart';

const _lines = <SettlementDeliveryLine>[
  SettlementDeliveryLine(
    deliveryId: 'dlv-101',
    date: 'Jun 23',
    tier: 'Standard',
    fare: 8.00,
    commission: 0.80,
    net: 7.20,
    currency: 'USD',
  ),
  SettlementDeliveryLine(
    deliveryId: 'dlv-102',
    date: 'Jun 25',
    tier: 'Express',
    fare: 12.00,
    commission: 1.20,
    net: 10.80,
    currency: 'USD',
  ),
];

SettlementStatement _statement({
  SettlementStatus status = SettlementStatus.paid,
  List<SettlementDeliveryLine> deliveries = _lines,
}) =>
    SettlementStatement(
      id: 'stmt-2026-w26',
      weekLabel: 'Jun 22 – Jun 28, 2026',
      totalPayout: 18.00,
      currency: 'USD',
      status: status,
      deliveries: deliveries,
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('settlement-detail: paid statement + breakdown (en)',
      (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      SettlementDetailScreen(statement: _statement()),
      'settlement-detail__paid',
    );
  });

  testWidgets('settlement-detail: pending statement (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      SettlementDetailScreen(
        statement: _statement(status: SettlementStatus.pending),
      ),
      'settlement-detail__pending',
    );
  });

  testWidgets('settlement-detail: paid statement (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      SettlementDetailScreen(statement: _statement()),
      'settlement-detail__ar',
      locale: const Locale('ar'),
    );
  });
}
