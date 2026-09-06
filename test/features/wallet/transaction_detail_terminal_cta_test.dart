// R6/F14/CR-01 + ES-18: an unrecoverable kind gets the way out, never Retry.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/wallet/data/unavailable_wallet_transaction_repository.dart';
import 'package:jeeb_mobile/features/wallet/domain/wallet_transaction_repository.dart';
import 'package:jeeb_mobile/features/wallet/presentation/transaction_detail_screen.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _FailingTransactionRepository implements WalletTransactionRepository {
  const _FailingTransactionRepository(this.failure, this.cause);

  final WalletTransactionFailure failure;
  final AppFailure cause;

  @override
  Future<WalletTransaction> fetchTransaction(String id) async {
    throw WalletTransactionRepositoryException(failure, cause: cause);
  }
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    WalletTransactionRepository repo, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      wrapForTest(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: TransactionDetailScreen(
              transactionId: 'txn-1',
              repository: repo,
            ),
          ),
        ),
        locale: locale,
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    testWidgets(
      '${locale.languageCode}: a 404 gets the exit CTA and NO retry',
      (tester) async {
        useReduceMotion(tester);
        final SemanticsHandle handle = tester.ensureSemantics();
        await pump(
          tester,
          const _FailingTransactionRepository(
            WalletTransactionFailure.notFound,
            NotFoundFailure(),
          ),
          locale: locale,
        );

        expect(find.bySemanticsIdentifier('txn_detail_error'), findsOneWidget);
        expect(
          find.bySemanticsIdentifier('txn_detail_exit_cta'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('txn_detail_retry_cta'),
          findsNothing,
        );

        handle.dispose();
      },
    );

    testWidgets('${locale.languageCode}: a 500 gets the retry', (tester) async {
      useReduceMotion(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      await pump(
        tester,
        const _FailingTransactionRepository(
          WalletTransactionFailure.unknown,
          ServerFailure(status: 500),
        ),
        locale: locale,
      );

      expect(find.bySemanticsIdentifier('txn_detail_error'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('txn_detail_retry_cta'),
        findsOneWidget,
      );

      handle.dispose();
    });
  }

  testWidgets('ES-18: the loading rung is findable too', (tester) async {
    useReduceMotion(tester);
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrapForTest(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: TransactionDetailScreen(
              transactionId: 'txn-1',
              repository: _StalledTransactionRepository(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsIdentifier('txn_detail_loading'), findsOneWidget);
    expect(find.bySemanticsIdentifier('txn_detail_error'), findsNothing);

    handle.dispose();
  });

  testWidgets('an offline network failure blames the connection', (tester) async {
    useReduceMotion(tester);
    await pump(
      tester,
      const _FailingTransactionRepository(
        WalletTransactionFailure.network,
        NetworkFailure(offline: true),
      ),
    );
    expect(find.text('Check your connection and try again.'), findsOneWidget);
  });

  test('GEN-01: the release-path stand-in THROWS rather than answer with a '
      'fabricated platform-fee row', () async {
    await expectLater(
      const UnavailableWalletTransactionRepository().fetchTransaction('t'),
      throwsA(isA<WalletTransactionRepositoryException>()),
    );
  });

  testWidgets('a 500 does NOT blame the connection', (tester) async {
    useReduceMotion(tester);
    await pump(
      tester,
      const _FailingTransactionRepository(
        WalletTransactionFailure.unknown,
        ServerFailure(status: 500),
      ),
    );
    expect(find.text('Check your connection and try again.'), findsNothing);
    expect(find.bySemanticsIdentifier('txn_detail_error'), findsOneWidget);
  });
}

/// A read that never lands — pins the loading rung.
class _StalledTransactionRepository implements WalletTransactionRepository {
  _StalledTransactionRepository();

  final Completer<WalletTransaction> _never = Completer<WalletTransaction>();

  @override
  Future<WalletTransaction> fetchTransaction(String id) => _never.future;
}
