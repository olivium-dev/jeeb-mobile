// Render tests for the NoOfferTimeoutScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// This screen picks ONE of four bodies off `WaitingState` — shimmer, centred
// error, terminal exit, or the waiting surface — and then re-drives the waiting
// surface's header off three independent signals (offers, the clock, and
// whether the server sent a window at all). Most of these previews would
// therefore satisfy a render-only check while showing the wrong surface
// entirely: a "zero notified" preview whose fixture drifted into an elapsed
// window looks exactly like the no-coverage state to a render-only assertion,
// and that particular confusion IS the BUG-4 defect. Every state below pins a
// string only IT can produce, and the groups after that pin the contracts the
// pairs exist for: zero-notified vs window-elapsed, and network vs contract
// break.
//
// ## Fonts
//
// `loadInterTestFont()` runs before every test here, because the shared harness
// does not load fonts and Flutter's test face makes every glyph a 1-em square —
// Latin measures ~2x too wide, Arabic ~2.4x. No assertion in this file claims
// an overflow. The one geometry claim that could be distorted by the fake face
// (the compact 320 pt frame, in both locales) is measured through
// `withGoldenTestFonts`, which is the only way to get real Arabic metrics: the
// preview host builds `AppTheme.light()` unmodified and the theme carries no
// `fontFamilyFallback`, so under the shared harness every Arabic glyph still
// falls back to the test face.
//
// ## Why `Loading · cold read` is not in the shared suite
//
// Its body is an `OmdsShimmer`, i.e. a `Shimmer.fromColors` whose controller
// repeats forever. `pumpAndSettle` (which `pumpPreview` calls) never returns
// while one is on screen, so that preview gets the same three assertions the
// shared suite makes, driven by fixed pumps instead.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/previews/jeeb_preview.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/presentation/no_offer_timeout_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/load_test_fonts.dart';
import '../../support/sync_app_localizations.dart';
import '../preview_test_harness.dart';

/// One fragment of the customer-typed paragraph that ONLY the longest-content
/// fixture carries. Spelled out here rather than imported so a preview quietly
/// rewired to a short fixture fails instead of silently losing the one state
/// that contests the 320 pt frame.
const String _kLongestFragment =
    'Two sealed envelopes from the notary office on Bliss Street, then a 5 kg '
    'bag of cat litter and four bottles of sparkling water from the Spinneys '
    'downstairs — please ring the bell twice, the intercom on the third floor '
    'has been broken since March.';

/// `previewCanvas`, but with the deterministic Arabic face wired into the
/// theme. Used only where a geometry claim is being made.
Widget _noOfferTimeoutCanvasWithFonts(
  Widget Function() preview,
  Locale locale,
) {
  return MaterialApp(
    theme: withGoldenTestFonts(AppTheme.light()),
    darkTheme: withGoldenTestFonts(AppTheme.dark()),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object?>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: jeebPreviewHost(preview()),
  );
}

Future<void> _pumpWithFonts(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(_noOfferTimeoutCanvasWithFonts(preview, locale));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await loadInterTestFont();
    loadPreviewArbs();
  });

  // Every preview except `Loading · cold read`, whose shimmer cannot settle.
  testPreviewsRender(
    'NoOfferTimeoutScreen',
    const <String, Widget Function()>{
      'Broadcasting · counting down': noOfferTimeoutScreenBroadcasting,
      'Offers arrived': noOfferTimeoutScreenOffersArrived,
      'No offers yet · window elapsed': noOfferTimeoutScreenNoOffersYet,
      'Zero notified · window still running': noOfferTimeoutScreenZeroNotified,
      'No countdown applies': noOfferTimeoutScreenNoCountdown,
      'Load failed · network': noOfferTimeoutScreenLoadFailed,
      'Contract violation': noOfferTimeoutScreenContractViolation,
      'Terminal · expired': noOfferTimeoutScreenTerminalExpired,
      'Longest content · compact 320': noOfferTimeoutScreenLongestContent,
    },
    expectedText: const <String, String>{
      // The frozen clock is what makes this an exact string rather than
      // "4:30-or-4:29 depending on how fast the fake resolved".
      'Broadcasting · counting down': '4:30 left to find a Jeeber',
      // Only a snapshot with offers in it renders the review CTA.
      'Offers arrived': 'Review offers',
      // The softened no-coverage title, which ONLY an elapsed window may raise.
      'No offers yet · window elapsed': 'No offers yet',
      // The neutral reassurance line — the other half of the BUG-4 pair.
      'Zero notified · window still running':
          "We're reaching out to Jeebers near you...",
      // P7: words, never a fabricated 0:00.
      'No countdown applies': 'Finding a Jeeber for you',
      // The transport failure copy.
      'Load failed · network':
          "We couldn't load your request status. Please try again.",
      // …and the contract-break copy, which must NOT say "connection".
      'Contract violation':
          'Your request status came back in an unexpected format. This is a '
              'server problem, not your connection.',
      // The terminal body's own title; the waiting surface can never show it.
      'Terminal · expired': 'Request expired',
      // The 24 h window, promoted to h:mm:ss — the `1433:18` regression, at the
      // width it broke on.
      'Longest content · compact 320': '23:53:18 left to find a Jeeber',
    },
  );

  // The loading body is an `OmdsShimmer`, i.e. a repeating animation.
  // `pumpAndSettle` never returns while one is on screen, so this preview gets
  // the shared suite's three assertions driven by fixed pumps. It has no text
  // of its own at all, so its state is pinned by the shimmer plus the absence
  // of every other body.
  group('NoOfferTimeoutScreen previews · Loading · cold read', () {
    Future<void> pumpLoading(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(
        previewCanvas(noOfferTimeoutScreenLoading, locale),
      );
      await tester.pump(); // the mount-time load() emit
      await tester.pump(const Duration(milliseconds: 16)); // one shimmer frame
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Loading · cold read · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpLoading(tester, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Loading · cold read renders its own state', (
      WidgetTester tester,
    ) async {
      await pumpLoading(tester);

      expect(find.byType(OmdsShimmer), findsOneWidget);
      // None of the three other bodies.
      expect(find.bySemanticsIdentifier('waiting_error_state'), findsNothing);
      expect(
        find.bySemanticsIdentifier('waiting_terminal_state'),
        findsNothing,
      );
      expect(
        find.bySemanticsIdentifier('waiting_countdown'),
        findsNothing,
      );
      // …and nothing to tap, including the free pre-accept cancel, for as long
      // as the read takes.
      expect(find.bySemanticsIdentifier('waiting_cancel_cta'), findsNothing);
    });
  });

  group('NoOfferTimeoutScreen preview specifics', () {
    // NB: one preview per test. Pumping a second preview into the same tester
    // does NOT rebuild these — `previewCanvas` produces the same widget types,
    // so the `BlocProvider` element is UPDATED rather than replaced and keeps
    // the cubit the first preview created.
    testWidgets('the phone previews pin a 390 pt frame, not the canvas width', (
      WidgetTester tester,
    ) async {
      // The harness pumps an 800 pt surface: a preview that left its width to
      // the host would measure 800 here, and none of this layout applies there.
      await pumpPreview(tester, noOfferTimeoutScreenBroadcasting);

      expect(tester.getSize(find.byType(NoOfferTimeoutScreen)).width, 390);
    });

    testWidgets('the longest-content preview pins the 320 x 568 floor', (
      WidgetTester tester,
    ) async {
      await _pumpWithFonts(tester, noOfferTimeoutScreenLongestContent);

      expect(
        tester.getSize(find.byType(NoOfferTimeoutScreen)),
        const Size(320, 568),
      );
    });

    testWidgets('the reference state carries the whole broadcast surface', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, noOfferTimeoutScreenBroadcasting);

      // AC1: the two broadcast signature ids, both re-driven off real signals.
      expect(find.text('Notified 6 nearby Jeebers'), findsOneWidget);
      expect(find.text('4:30 left to find a Jeeber'), findsOneWidget);
      // G1: the customer's own request text, echoed back under "Your request".
      expect(find.text('2 grocery bags from Spinneys'), findsOneWidget);
      // D48 + D69, and no review CTA while nobody has bid.
      expect(find.bySemanticsIdentifier('waiting_retarget_cta'), findsOneWidget);
      expect(find.bySemanticsIdentifier('waiting_cancel_cta'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('waiting_review_offers_cta'),
        findsNothing,
      );
      expect(
        find.bySemanticsIdentifier('waiting_no_coverage_state'),
        findsNothing,
      );
    });

    // The BUG-4 pair. `notifiedCount` is informational and effectively always
    // zero in production, so a screen that gated no-coverage on it told every
    // healthy waiting customer that nobody was nearby. Only the CLOCK may raise
    // that block, and these two fixtures differ only in the clock.
    testWidgets('zero notified with the window still running is NOT '
        'no-coverage (BUG-4)', (WidgetTester tester) async {
      await pumpPreview(tester, noOfferTimeoutScreenZeroNotified);

      expect(
        find.bySemanticsIdentifier('waiting_no_coverage_state'),
        findsNothing,
        reason: 'notifiedCount must not gate the no-coverage state',
      );
      expect(find.text("We're reaching out to Jeebers near you..."),
          findsOneWidget);
      // The count-zero copy the fix replaced must reach no pixel.
      expect(find.text('No Jeebers nearby yet'), findsNothing);
      expect(find.text('No offers yet'), findsNothing);
      // The countdown is still running and still visible.
      expect(find.text('3:00 left to find a Jeeber'), findsOneWidget);
    });

    testWidgets('an elapsed window with zero offers IS no-coverage', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, noOfferTimeoutScreenNoOffersYet);

      expect(
        find.bySemanticsIdentifier('waiting_no_coverage_state'),
        findsOneWidget,
      );
      // The block REPLACES the header: the customer loses both the count and
      // the countdown at the moment they have been waiting longest.
      expect(find.bySemanticsIdentifier('waiting_countdown'), findsNothing);
      expect(
        find.bySemanticsIdentifier('waiting_notified_count'),
        findsNothing,
      );
      // Both ways out are still offered — cancelling here is free (D69).
      expect(find.bySemanticsIdentifier('waiting_retarget_cta'), findsOneWidget);
      expect(find.bySemanticsIdentifier('waiting_cancel_cta'), findsOneWidget);
    });

    testWidgets('a null remaining says so instead of fabricating 0:00 (P7)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, noOfferTimeoutScreenNoCountdown);

      // The node stays mounted — Maestro flows resolve it — and reads as copy.
      expect(find.bySemanticsIdentifier('waiting_countdown'), findsOneWidget);
      expect(find.text('Finding a Jeeber for you'), findsOneWidget);
      expect(find.textContaining('0:00'), findsNothing);
      // A missing window is NOT an elapsed one.
      expect(
        find.bySemanticsIdentifier('waiting_no_coverage_state'),
        findsNothing,
      );
    });

    // The network/contract pair. Same body, same Retry, different claim — and
    // the whole reason `WaitingFailure.contractViolation` carries its own copy
    // is so a QA run reports a backend break rather than a flaky connection.
    testWidgets('the network failure blames the connection', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, noOfferTimeoutScreenLoadFailed);

      expect(find.bySemanticsIdentifier('waiting_error_state'), findsOneWidget);
      expect(
        find.text("We couldn't load your request status. Please try again."),
        findsOneWidget,
      );
      // The error body replaces everything, including the free cancel.
      expect(find.bySemanticsIdentifier('waiting_cancel_cta'), findsNothing);
      expect(find.bySemanticsIdentifier('waiting_countdown'), findsNothing);
    });

    testWidgets('the contract break blames the server, not the connection', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, noOfferTimeoutScreenContractViolation);

      expect(find.bySemanticsIdentifier('waiting_error_state'), findsOneWidget);
      expect(
        find.textContaining('This is a server problem, not your connection.'),
        findsOneWidget,
      );
      expect(
        find.text("We couldn't load your request status. Please try again."),
        findsNothing,
        reason: 'a contract break must never be reported as a network problem',
      );
    });

    testWidgets('the terminal state drops every waiting affordance', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, noOfferTimeoutScreenTerminalExpired);

      expect(
        find.bySemanticsIdentifier('waiting_terminal_state'),
        findsOneWidget,
      );
      expect(find.text('Request expired'), findsOneWidget);
      // One exit, and nothing that implies the request is still live.
      expect(
        find.bySemanticsIdentifier('waiting_terminal_home_cta'),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier('waiting_countdown'), findsNothing);
      expect(find.bySemanticsIdentifier('waiting_retarget_cta'), findsNothing);
      expect(find.bySemanticsIdentifier('waiting_cancel_cta'), findsNothing);
    });

    testWidgets('the ceiling state promotes the 24 h window and renders the '
        'paragraph in full', (WidgetTester tester) async {
      await _pumpWithFonts(tester, noOfferTimeoutScreenLongestContent);

      // `CountdownFormat` promotes the hours field instead of letting the
      // minute field run away — the `1433:18` regression.
      expect(find.text('23:53:18 left to find a Jeeber'), findsOneWidget);
      expect(find.text('1433:18 left to find a Jeeber'), findsNothing);
      // The echo card sets no `maxLines`, so the whole paragraph is laid out.
      expect(find.text(_kLongestFragment), findsOneWidget);
    });

    testWidgets('the ceiling state lays out in Arabic at 320 pt', (
      WidgetTester tester,
    ) async {
      await _pumpWithFonts(
        tester,
        noOfferTimeoutScreenLongestContent,
        locale: const Locale('ar'),
      );

      expect(tester.takeException(), isNull);
      // The Arabic countdown sentence takes the same preformatted clock run.
      expect(find.text('23:53:18 متبقٍّ للعثور على جيبر'), findsOneWidget);
    });
  });
}
