// Widget tests for WalletActivityListScreen (JM-055). Proves the screen renders

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/features/wallet/domain/wallet_ledger_repository.dart';
import 'package:jeeb_mobile/features/wallet/presentation/wallet_activity_list_screen.dart';
import 'package:jeeb_mobile/features/wallet/presentation/widgets/wallet_activity_row.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _ScriptedLedgerRepository implements WalletLedgerRepository {
  _ScriptedLedgerRepository({
    List<WalletLedgerEntry>? entries,
    this.throws,
  }) : _entries = entries ?? const <WalletLedgerEntry>[];

  final List<WalletLedgerEntry> _entries;
  final WalletLedgerFailure? throws;

  @override
  Future<WalletLedgerPage> fetchLedger({int page = 1, int pageSize = 20}) async {
    final f = throws;
    if (f != null) throw WalletLedgerRepositoryException(f);
    return WalletLedgerPage(
      entries: _entries,
      page: page,
      totalPages: 1,
    );
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

void main() {
  Future<void> pump(WidgetTester tester, WalletLedgerRepository repo) async {
    await tester.pumpWidget(
      wrapForTest(
        // MIDNIGHT: the empty/loading/error illustration loops ∞ by design, so
        // `pumpAndSettle` cannot settle without reduce motion (wave-B ruling).
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: WalletActivityListScreen(repository: repo),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('AC: root + typed rows render with the per-row id', (tester) async {
    await pump(
      tester,
      _ScriptedLedgerRepository(entries: [
        _row('led-a', type: WalletLedgerType.reserve),
        _row('led-b', type: WalletLedgerType.feeWon),
        _row('led-c', type: WalletLedgerType.gift, sign: 1),
      ]),
    );

    expect(find.bySemanticsIdentifier('wallet_activity_root'), findsOneWidget);
    expect(find.bySemanticsIdentifier('wallet_activity_row_led-a'),
        findsOneWidget);
    expect(find.bySemanticsIdentifier('wallet_activity_row_led-b'),
        findsOneWidget);
    expect(find.bySemanticsIdentifier('wallet_activity_row_led-c'),
        findsOneWidget);
  });

  testWidgets('D30 empty: loaded + no rows → wallet_activity_empty',
      (tester) async {
    await pump(tester, _ScriptedLedgerRepository());
    expect(find.bySemanticsIdentifier('wallet_activity_empty'), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('wallet_activity_row_led-a'),
      findsNothing,
    );
  });

  testWidgets('D30 error: cold-load failure → error + retry_cta', (tester) async {
    await pump(
      tester,
      _ScriptedLedgerRepository(throws: WalletLedgerFailure.network),
    );
    expect(find.bySemanticsIdentifier('wallet_activity_error'), findsOneWidget);
    expect(find.bySemanticsIdentifier('wallet_activity_retry_cta'),
        findsOneWidget);
  });

  testWidgets('tap a row → transaction-detail (/wallet/transactions/:id)',
      (tester) async {
    final repo = _ScriptedLedgerRepository(entries: [_row('led-x')]);

    final router = GoRouter(
      initialLocation: '/wallet/activity',
      routes: [
        GoRoute(
          name: 'wallet-activity',
          path: '/wallet/activity',
          builder: (context, state) =>
              WalletActivityListScreen(repository: repo),
        ),
        GoRoute(
          name: 'transaction-detail',
          path: '/wallet/transactions/:id',
          builder: (context, state) => Scaffold(
            body: Semantics(
              identifier: 'stub_txn_detail',
              container: true,
              child: Text('txn ${state.pathParameters['id']}'),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: ThemeData.light(),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          SyncAppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
    await tester.pumpAndSettle();

    // Tap the row's InkWell (the Semantics wrapper is zero-size for hit-test;
    await tester.tap(find.descendant(
      of: find.byType(WalletActivityRow),
      matching: find.byType(InkWell),
    ));
    await tester.pumpAndSettle();

    // Navigation happened: the transaction-detail target rendered with the
    expect(find.bySemanticsIdentifier('stub_txn_detail'), findsOneWidget);
    expect(find.text('txn led-x'), findsOneWidget);
  });
}
