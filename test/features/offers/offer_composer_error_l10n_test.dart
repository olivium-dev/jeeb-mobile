// JEBV4-246 + JEBV4-243: the offer-composer error snack must render LOCALIZED
// copy (not a hardcoded English string) and the draft must survive the error.

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
  _ThrowingRepo(this.failure);

  final OfferSubmissionFailure failure;

  @override
  Future<OfferSubmissionResult> submitOffer({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
    String? note,
  }) async {
    throw OfferSubmissionException(failure);
  }
}

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
}
