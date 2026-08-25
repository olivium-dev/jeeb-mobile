// redesign-2026-08 screen 17: the money field's `−1` / `+1` pills and the CTA
// that restates what the Jeeber keeps.
//
// The stepper floors at 0 — there is no invented ceiling (the cubit validates
// `price > 0` only, so a numeric cap here would fabricate a product rule).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/formatting/money_format.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/offers/domain/offer_submission_repository.dart';
import 'package:jeeb_mobile/features/offers/presentation/offer_submission_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// Never-called repository — these tests never submit.
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

Widget _harness() {
  return MaterialApp(
    theme: AppTheme.light(),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const OfferSubmissionScreen(
      requestId: 'req-1',
      submissionService: null,
      repository: _InertRepo(),
      onWithdrawn: _noop,
    ),
  );
}

void _noop() {}

String _priceText(WidgetTester tester) => tester
    .widget<EditableText>(find.byType(EditableText).first)
    .controller
    .text;

void main() {
  group('Offer composer price stepper (screen 17)', () {
    testWidgets('both stepper identifiers resolve', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('offer_composer_price_decrement'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('offer_composer_price_increment'),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('+1 from empty enters 1.00 and the CTA restates the net', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      await tester.tap(
        find.bySemanticsIdentifier('offer_composer_price_increment'),
      );
      await tester.pumpAndSettle();

      expect(_priceText(tester), '1.00');
      // 1.00 − 10% platform fee = 0.90 kept, restated on the CTA.
      expect(
        find.text('Send offer — net ${MoneyFormat.format(0.9)} after Jeeb fee'),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('−1 at empty is a no-op and the CTA stays generic', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      await tester.tap(
        find.bySemanticsIdentifier('offer_composer_price_decrement'),
      );
      await tester.pumpAndSettle();

      expect(_priceText(tester), isEmpty);
      expect(find.text('Send offer'), findsOneWidget);
      expect(find.textContaining('Send offer — net'), findsNothing);

      handle.dispose();
    });

    testWidgets('−1 floors at 0: 1.00 → cleared, never a zero bid', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      await tester.tap(
        find.bySemanticsIdentifier('offer_composer_price_increment'),
      );
      await tester.pumpAndSettle();
      expect(_priceText(tester), '1.00');

      await tester.tap(
        find.bySemanticsIdentifier('offer_composer_price_decrement'),
      );
      await tester.pumpAndSettle();

      expect(_priceText(tester), isEmpty);

      handle.dispose();
    });

    testWidgets('typing a price drives the breakdown and the CTA together', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(EditableText).first, '8');
      await tester.pumpAndSettle();

      // The three frozen money lines + the new offer line, all from one price.
      expect(find.text(MoneyFormat.format(8)), findsOneWidget);
      expect(find.textContaining(MoneyFormat.format(0.8)), findsWidgets);
      expect(find.text(MoneyFormat.format(7.2)), findsOneWidget);
      expect(
        find.text('Send offer — net ${MoneyFormat.format(7.2)} after Jeeb fee'),
        findsOneWidget,
      );

      handle.dispose();
    });
  });
}
