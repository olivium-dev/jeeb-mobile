// Isolated native UI test — WalletActivityListScreen (wallet-activity, JM-055).
// The screen builds a WalletLedgerCubit off the `repository` seam and calls
// load(), so injecting a scripted in-memory ledger avoids DI/network. Covers the
// populated typed-row list, the loaded+empty state, and a cold-load error (ar).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/wallet/domain/wallet_ledger_repository.dart';
import 'package:jeeb_mobile/features/wallet/presentation/wallet_activity_list_screen.dart';

import '../support/screen_harness.dart';

/// In-memory ledger repo serving one fixed page (or throwing). Inlined so the
/// integration test never reaches into test/support/.
class _FakeLedgerRepository implements WalletLedgerRepository {
  _FakeLedgerRepository({
    List<WalletLedgerEntry>? entries,
    this.throws,
  }) : _entries = entries ?? const <WalletLedgerEntry>[];

  final List<WalletLedgerEntry> _entries;
  final WalletLedgerFailure? throws;

  @override
  Future<WalletLedgerPage> fetchLedger({int page = 1, int pageSize = 20}) async {
    final f = throws;
    if (f != null) throw WalletLedgerRepositoryException(f);
    return WalletLedgerPage(entries: _entries, page: page, totalPages: 1);
  }
}

WalletLedgerEntry _row(
  String id, {
  WalletLedgerType type = WalletLedgerType.feeWon,
  double amount = 0.9,
  int sign = -1,
}) =>
    WalletLedgerEntry(
      id: id,
      type: type,
      amount: amount,
      sign: sign,
      ref: 'off-$id',
      timestamp: '2026-06-18T10:00:00Z',
      currency: 'USD',
    );

final _entries = <WalletLedgerEntry>[
  _row('led-a', type: WalletLedgerType.reserve, amount: 3.0),
  _row('led-b', type: WalletLedgerType.feeWon, amount: 0.9),
  _row('led-c', type: WalletLedgerType.released, amount: 3.0, sign: 1),
  _row('led-d', type: WalletLedgerType.topup, amount: 40, sign: 1),
  _row('led-e', type: WalletLedgerType.gift, amount: 10, sign: 1),
];

WalletActivityListScreen _screen({
  List<WalletLedgerEntry>? entries,
  WalletLedgerFailure? throws,
}) =>
    WalletActivityListScreen(
      repository: _FakeLedgerRepository(entries: entries, throws: throws),
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('wallet-activity: populated typed rows (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screen(entries: _entries),
      'wallet-activity__populated',
    );
  });

  testWidgets('wallet-activity: loaded + empty ledger (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screen(),
      'wallet-activity__empty',
    );
  });

  testWidgets('wallet-activity: cold-load error (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screen(throws: WalletLedgerFailure.network),
      'wallet-activity__ar',
      locale: const Locale('ar'),
    );
  });
}
