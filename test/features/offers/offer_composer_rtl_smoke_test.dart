// redesign-2026-08 screen 17, guardrail 4: the composer must survive Arabic
// mirroring at 200% text — no overflow — and every amount must stay an LTR run
// inside the RTL sentence (JEBV4-98: a bare `$0.80` reorders in Arabic).

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
  const _StubWallet();

  @override
  Future<WalletBalance> fetchBalance() async => const WalletBalance(
        availableBalance: 6.40,
        affordabilityState: WalletAffordability.enough,
        reservedNow: 0,
        giftCredit: 0,
        currency: 'USD',
      );
}

Widget _harness({required double textScale}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('ar'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: const OfferSubmissionScreen(
      requestId: 'req-1',
      submissionService: null,
      repository: _InertRepo(),
      walletRepository: _StubWallet(),
      onWithdrawn: _noop,
    ),
  );
}

void _noop() {}

void main() {
  group('Offer composer AR/RTL (screen 17)', () {
    testWidgets('mirrors and survives 200% text with no overflow',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness(textScale: 2));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        Directionality.of(
          tester.element(find.bySemanticsIdentifier('offer_composer_root')),
        ),
        TextDirection.rtl,
      );

      // Fill a price, then re-check: the money rows are the widest content.
      await tester.enterText(find.byType(EditableText).first, '8');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      handle.dispose();
    });

    testWidgets('amounts render as LTR-isolated runs inside Arabic copy',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness(textScale: 1));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(EditableText).first, '8');
      await tester.pumpAndSettle();

      // MoneyFormat wraps every token in U+2066…U+2069.
      final kept = MoneyFormat.format(7.2);
      expect(kept.codeUnitAt(0), 0x2066);
      expect(kept.codeUnitAt(kept.length - 1), 0x2069);

      expect(find.text(kept), findsOneWidget);
      expect(find.text('أرسل العرض — تحتفظ بـ $kept'), findsOneWidget);
      expect(
        find.text('المحفظة: ${MoneyFormat.format(6.4)} متاح'),
        findsOneWidget,
      );

      handle.dispose();
    });
  });
}
