// JEBV4-246 + JEBV4-243 + UX-41: the offer-composer failure is a PERSISTENT
// note, localized, and the draft survives it.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/network/network_reachability_signals.dart';
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
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(() => NetworkReachabilitySignals.instance.debugObserve(online: false));
  tearDown(NetworkReachabilitySignals.debugReset);
  group('Offer composer error snack — localized + draft survives', () {
    testWidgets('network failure shows the EN localized snack, not the old '
        'hardcoded string; draft survives (JEBV4-246/243)', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _harness(_ThrowingRepo(OfferSubmissionFailure.network)),
      );
      await tester.pumpAndSettle();

      await _submitValidDraft(tester);

      // UX-41: a persistent note, not a snack that vanishes while the Jeeber
      // is looking away.
      expect(
        find.bySemanticsIdentifier('offer_composer_error_note'),
        findsOneWidget,
      );
      expect(
        find.text('Check your connection and try again.'),
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
        find.bySemanticsIdentifier('offer_composer_error_note'),
        findsOneWidget,
      );
      expect(find.text('تحقّق من اتصالك وحاول مجددًا.'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('the note survives until the draft is edited (UX-41)',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _harness(_ThrowingRepo(OfferSubmissionFailure.network)),
      );
      await tester.pumpAndSettle();

      await _submitValidDraft(tester);
      expect(
        find.bySemanticsIdentifier('offer_composer_error_note'),
        findsOneWidget,
      );

      // Several seconds later it is still there — a snack would be gone.
      await tester.pump(const Duration(seconds: 8));
      expect(
        find.bySemanticsIdentifier('offer_composer_error_note'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(EditableText).first, '9');
      await tester.pump();
      expect(
        find.bySemanticsIdentifier('offer_composer_error_note'),
        findsNothing,
      );

      handle.dispose();
    });
  });
}
