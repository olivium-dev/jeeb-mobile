// TEST-16: a persistent page-2 failure must not become a scroll retry loop.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/wallet/domain/wallet_ledger_repository.dart';
import 'package:jeeb_mobile/features/wallet/presentation/wallet_activity_list_screen.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

/// Page 1 lands; every later page fails. Counts the attempts.
class _LoadMoreFailingLedger implements WalletLedgerRepository {
  _LoadMoreFailingLedger(this.entries);

  final List<WalletLedgerEntry> entries;

  int pageTwoCalls = 0;

  @override
  Future<WalletLedgerPage> fetchLedger({
    int page = 1,
    int pageSize = 20,
  }) async {
    if (page > 1) {
      pageTwoCalls++;
      throw const WalletLedgerRepositoryException(
        WalletLedgerFailure.network,
        cause: NetworkFailure(),
      );
    }
    return WalletLedgerPage(entries: entries, page: 1, totalPages: 2);
  }
}

List<WalletLedgerEntry> _rows(int count) => <WalletLedgerEntry>[
  for (int i = 0; i < count; i++)
    WalletLedgerEntry(
      id: 'ldg-$i',
      type: WalletLedgerType.feeWon,
      amount: 0.9,
      sign: -1,
      ref: 'off-$i',
      timestamp: '2026-06-18T10:00:00Z',
      currency: 'USD',
    ),
];

void main() {
  Future<void> pump(
    WidgetTester tester,
    WalletLedgerRepository repo, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      wrapForTest(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: WalletActivityListScreen(repository: repo),
          ),
        ),
        locale: locale,
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    testWidgets('${locale.languageCode}: a page-2 failure renders the footer '
        'error, a further scroll does NOT re-fire it, and the retry does', (
      tester,
    ) async {
      useReduceMotion(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      final repo = _LoadMoreFailingLedger(_rows(12));
      await pump(tester, repo, locale: locale);

      // Reaching the foot fires the first (and failing) page-2 read.
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -4000));
      await tester.pumpAndSettle();

      expect(repo.pageTwoCalls, 1);
      expect(
        find.bySemanticsIdentifier('wallet_activity_load_more_error'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('wallet_activity_load_more_retry'),
        findsOneWidget,
      );

      // The loop guard: scrolling at the foot again must not re-fire.
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -4000));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -4000));
      await tester.pumpAndSettle();
      expect(repo.pageTwoCalls, 1);

      // Only the explicit tap retries.
      await tester.tap(
        find.bySemanticsIdentifier('wallet_activity_load_more_retry'),
      );
      await tester.pumpAndSettle();
      expect(repo.pageTwoCalls, 2);

      handle.dispose();
    });
  }
}
