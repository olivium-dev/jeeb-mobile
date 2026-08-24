// redesign-2026-08 screen 17: the wallet strip is the screen's only orange
// affordance — and it is ABSENT when there is no wallet snapshot. Rendering
// "$0.00 available" from a failed/missing read would be a number the Jeeber
// could act on (JEBV4-176).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/formatting/money_format.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/offers/domain/offer_submission_repository.dart';
import 'package:jeeb_mobile/features/offers/presentation/offer_submission_screen.dart';
import 'package:jeeb_mobile/features/wallet/domain/wallet_repository.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _InertRepo implements OfferSubmissionRepository {
  const _InertRepo();

  @override
  Future<OfferSubmissionResult> submitOffer({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
    String? note,
  }) async {
    throw UnimplementedError();
  }
}

class _StubWallet implements WalletRepository {
  const _StubWallet(this.balance);

  final WalletBalance balance;

  @override
  Future<WalletBalance> fetchBalance() async => balance;
}

class _FailingWallet implements WalletRepository {
  const _FailingWallet();

  @override
  Future<WalletBalance> fetchBalance() async =>
      throw const WalletRepositoryException(WalletFailure.network);
}

const WalletBalance _wallet = WalletBalance(
  availableBalance: 6.40,
  affordabilityState: WalletAffordability.enough,
  reservedNow: 0,
  giftCredit: 0,
  currency: 'USD',
);

Widget _harness(
  WalletRepository? wallet, {
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: OfferSubmissionScreen(
      requestId: 'req-1',
      submissionService: null,
      repository: const _InertRepo(),
      walletRepository: wallet,
      onWithdrawn: _noop,
    ),
  );
}

void _noop() {}

void main() {
  group('Offer composer wallet strip (screen 17)', () {
    testWidgets('renders the balance and the top-up link with a wallet', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness(const _StubWallet(_wallet)));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('offer_composer_wallet_strip'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('offer_composer_wallet_topup_cta'),
        findsOneWidget,
      );
      expect(
        find.text('Fee balance: ${MoneyFormat.format(6.4)} available'),
        findsOneWidget,
      );
      expect(
        find.textContaining('The customer pays your full offer in cash.'),
        findsOneWidget,
      );
      expect(find.textContaining('in-app payment'), findsNothing);

      handle.dispose();
    });

    testWidgets('Arabic keeps the same full-cash and fee-balance boundary', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _harness(const _StubWallet(_wallet), locale: const Locale('ar')),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('رصيد الرسوم:'), findsOneWidget);
      expect(
        find.textContaining('يدفع العميل قيمة عرضك كاملة نقداً.'),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('is absent when no wallet repository is wired', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness(null));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('offer_composer_wallet_strip'),
        findsNothing,
      );
      expect(find.textContaining('0.00 available'), findsNothing);

      handle.dispose();
    });

    testWidgets('is absent when the wallet read fails', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness(const _FailingWallet()));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('offer_composer_wallet_strip'),
        findsNothing,
      );
      // The composer still works — the strip is context, never a gate (D35).
      expect(
        find.bySemanticsIdentifier('offer_composer_send_cta'),
        findsOneWidget,
      );

      handle.dispose();
    });
  });
}
