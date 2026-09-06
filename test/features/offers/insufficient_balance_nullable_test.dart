// UX-15: a malformed 402 must not fabricate a $0.00 needed-vs-available pair.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/offers/domain/offer_submission_repository.dart';
import 'package:jeeb_mobile/features/offers/presentation/offer_submission_screen.dart';
import 'package:jeeb_mobile/features/wallet/domain/wallet_repository.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _InsufficientRepo implements OfferSubmissionRepository {
  _InsufficientRepo(this.balance);

  final InsufficientBalanceInfo? balance;

  @override
  Future<OfferSubmissionResult> submitOffer({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
    String? note,
  }) async =>
      throw OfferSubmissionException(
        OfferSubmissionFailure.insufficientBalance,
        balance: balance,
      );
}

/// A funded snapshot, so the test proves the sheet does not substitute it.
class _FundedWallet implements WalletRepository {
  const _FundedWallet();

  @override
  Future<WalletBalance> fetchBalance() async => const WalletBalance(
        availableBalance: 25,
        affordabilityState: WalletAffordability.enough,
        reservedNow: 0,
        giftCredit: 0,
        currency: 'USD',
      );
}

Future<void> _pumpAndSend(
  WidgetTester tester,
  InsufficientBalanceInfo? balance, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    wrapForTest(
      OfferSubmissionScreen(
        requestId: 'req-1',
        submissionService: null,
        repository: _InsufficientRepo(balance),
        walletRepository: const _FundedWallet(),
        walletRefreshSignals: const Stream<void>.empty(),
        onWithdrawn: () {},
      ),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(EditableText).first, '7');
  await tester.pump();
  await tester.tap(find.bySemanticsIdentifier('offer_composer_eta_option_0'));
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsIdentifier('offer_composer_send_cta'));
  await tester.pumpAndSettle();
}

void main() {
  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String tag = locale.languageCode;

    testWidgets('$tag: an EMPTY 402 body opens the sheet with NEITHER amount '
        'row and no fabricated zero', (tester) async {
      useReduceMotion(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pumpAndSend(tester, null, locale: locale);

      expect(
        find.bySemanticsIdentifier('insufficient_balance_sheet'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('insufficient_balance_needed_amount'),
        findsNothing,
      );
      expect(
        find.bySemanticsIdentifier('insufficient_balance_available_amount'),
        findsNothing,
      );
      // The composer's own `0.00` placeholder sits behind the sheet, so the
      // assertion is scoped to the sheet subtree.
      expect(
        find.descendant(
          of: find.bySemanticsIdentifier('insufficient_balance_sheet'),
          matching: find.textContaining('0.00'),
        ),
        findsNothing,
      );
      // The explanation still stands on its own.
      expect(
        find.bySemanticsIdentifier('insufficient_topup_cta'),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('$tag: a 402 carrying both figures shows both rows',
        (tester) async {
      useReduceMotion(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pumpAndSend(
        tester,
        const InsufficientBalanceInfo(
          needed: 12.50,
          available: 3.75,
          currency: 'USD',
        ),
        locale: locale,
      );

      expect(
        find.bySemanticsIdentifier('insufficient_balance_needed_amount'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('insufficient_balance_available_amount'),
        findsOneWidget,
      );

      handle.dispose();
    });
  }

  testWidgets('a partial 402 shows only the figure the server sent',
      (tester) async {
    useReduceMotion(tester);
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pumpAndSend(
      tester,
      const InsufficientBalanceInfo(needed: 12.50, currency: 'USD'),
    );

    expect(
      find.bySemanticsIdentifier('insufficient_balance_needed_amount'),
      findsOneWidget,
    );
    // The local wallet snapshot is NEVER substituted for a server figure.
    expect(
      find.bySemanticsIdentifier('insufficient_balance_available_amount'),
      findsNothing,
    );

    handle.dispose();
  });
}
