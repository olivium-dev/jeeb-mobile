// JEBV4-246 + JEBV4-243: the offer-composer error snack must render LOCALIZED

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/offers/domain/offer_submission_repository.dart';
import 'package:jeeb_mobile/features/offers/presentation/offer_submission_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// Repository that always fails the submit with [failure].
class _ThrowingRepo implements OfferSubmissionRepository {
  _ThrowingRepo(this.failure, {this.capInfo});

  final OfferSubmissionFailure failure;
  final OfferCapInfo? capInfo;

  @override
  Future<OfferSubmissionResult> submitOffer({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
    String? note,
  }) async {
    throw OfferSubmissionException(failure, capInfo: capInfo);
  }
}

/// The FROZEN copy, read from the ARB itself (CONTRACT §5) — never retyped
/// here, so a copy edit can only pass by editing the contract's own value.
String _frozen(String key, {String lang = 'en'}) =>
    debugLoadAppLocalizationsSync(
      Locale(lang),
      File('lib/l10n/app_$lang.arb').readAsStringSync(),
    ).byKey(key)!;

Widget _harness(
  OfferSubmissionRepository repo, {
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
      repository: repo,
      onWithdrawn: () {},
    ),
  );
}

/// Fills a valid draft (price + ETA) and taps Send.
Future<void> _submitValidDraft(WidgetTester tester) async {
  await tester.enterText(find.byType(EditableText).first, '7');
  await tester.pump();
  await tester.tap(find.bySemanticsIdentifier('offer_composer_eta_dropdown'));
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsIdentifier('offer_composer_eta_option_0'));
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsIdentifier('offer_composer_send_cta'));
  // Do NOT pumpAndSettle — the transient snack would auto-dismiss first.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('Offer composer error snack — localized + draft survives', () {
    testWidgets('network failure shows the EN localized snack, not the old '
        'hardcoded string; draft survives (JEBV4-246/243)', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _harness(_ThrowingRepo(OfferSubmissionFailure.network)),
      );
      await tester.pumpAndSettle();

      await _submitValidDraft(tester);

      expect(
        find.text('No connection. Check your network and try again.'),
        findsOneWidget,
      );
      // The previously-shipped hardcoded English is gone.
      expect(find.text('No internet connection'), findsNothing);

      // Draft survives: the price field still holds the entered value.
      final priceField =
          tester.widget<EditableText>(find.byType(EditableText).first);
      expect(priceField.controller.text, '7');

      handle.dispose();
    });

    testWidgets('network failure shows the ARABIC localized snack (JEBV4-246)',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _harness(
          _ThrowingRepo(OfferSubmissionFailure.network),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      await _submitValidDraft(tester);

      expect(
        find.text('لا يوجد اتصال. تحقق من شبكتك وحاول مجدداً.'),
        findsOneWidget,
      );

      handle.dispose();
    });
  });

  group('Offer composer error snack — wallet-guard copy (CONTRACT §5)', () {
    Future<void> expectSnack(
      WidgetTester tester,
      _ThrowingRepo repo,
      String expected, {
      Locale locale = const Locale('en'),
    }) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness(repo, locale: locale));
      await tester.pumpAndSettle();

      await _submitValidDraft(tester);

      expect(find.text(expected), findsOneWidget);
      handle.dispose();
    }

    testWidgets('E3 holder-unresolved shows the C-1 copy', (tester) async {
      await expectSnack(
        tester,
        _ThrowingRepo(OfferSubmissionFailure.holderUnresolved),
        _frozen('walletGuardErrorHolderUnresolved'),
      );
    });

    testWidgets('E3 holder-unresolved shows the ARABIC C-1 copy',
        (tester) async {
      await expectSnack(
        tester,
        _ThrowingRepo(OfferSubmissionFailure.holderUnresolved),
        _frozen('walletGuardErrorHolderUnresolved', lang: 'ar'),
        locale: const Locale('ar'),
      );
    });

    testWidgets('E4 fee-unresolvable shows the C-2 copy', (tester) async {
      await expectSnack(
        tester,
        _ThrowingRepo(OfferSubmissionFailure.feeUnresolvable),
        _frozen('walletGuardErrorFeeUnresolvable'),
      );
    });

    testWidgets('E5 exposure-unresolvable shows the C-3 copy', (tester) async {
      await expectSnack(
        tester,
        _ThrowingRepo(OfferSubmissionFailure.exposureUnresolvable),
        _frozen('walletGuardErrorExposureUnresolvable'),
      );
    });

    testWidgets('E2 cap shows the C-4 copy substituting the SERVER limit',
        (tester) async {
      await expectSnack(
        tester,
        _ThrowingRepo(
          OfferSubmissionFailure.offerCapReached,
          capInfo: const OfferCapInfo(limit: 7, live: 7),
        ),
        _frozen('walletGuardErrorOfferLimitReached').replaceFirst('{limit}', '7'),
      );
    });

    testWidgets('E2 cap without a limit falls back to the documented 20',
        (tester) async {
      await expectSnack(
        tester,
        _ThrowingRepo(OfferSubmissionFailure.offerCapReached),
        _frozen('walletGuardErrorOfferLimitReached')
            .replaceFirst('{limit}', '$kDefaultMaxLiveOffersFallback'),
      );
    });
  });
}
