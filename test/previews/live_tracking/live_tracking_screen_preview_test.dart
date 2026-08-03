// Render tests for the LiveTrackingScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/previews/jeeb_preview.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/live_tracking_screen_fixtures.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/live_tracking_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/load_test_fonts.dart';
import '../../support/sync_app_localizations.dart';
import '../preview_test_harness.dart';

/// The one fragment of the customer-typed item summary that only the
/// longest-content fixture carries.
const String _kLongestItemFragment = 'sealed envelope from the notary office';

/// `previewCanvas`, but with the deterministic Arabic face wired into the theme.
/// The shared harness cannot do this — it builds `AppTheme.light()` directly —
Widget _liveTrackingCanvasWithFonts(
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
  await tester.pumpWidget(_liveTrackingCanvasWithFonts(preview, locale));
  await tester.pumpAndSettle();
}

/// Pumps [canvas] with the framework's error reporting redirected into a list,
/// and returns everything the frame reported.
Future<List<String>> _frameErrors(
  WidgetTester tester,
  Widget canvas,
) async {
  final List<String> reported = <String>[];
  final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
  FlutterError.onError =
      (FlutterErrorDetails details) => reported.add(details.exceptionAsString());
  try {
    await tester.pumpWidget(canvas);
    await tester.pumpAndSettle();
  } finally {
    FlutterError.onError = previous;
  }
  return reported;
}

/// Everything the frame reported for [preview], laid out through the real faces
/// — the honest way to make an overflow claim.
Future<List<String>> _frameErrorsWithFonts(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) =>
    _frameErrors(tester, _liveTrackingCanvasWithFonts(preview, locale));

/// Everything the frame reported for [preview] the way the canvas's **200%
/// text** rendering draws it, through the real faces.
Future<List<String>> _frameErrorsAtDoubleText(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) =>
    _frameErrors(
      tester,
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: _liveTrackingCanvasWithFonts(preview, locale),
      ),
    );

/// Pumps the in-transit card and then drains the 4 s snackbar timer it arms, so
/// the case can end without a pending timer. See the header note.
Future<void> _pumpInTransit(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
}) async {
  await pumpPreview(tester, liveTrackingScreenInTransit, locale: locale);
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await loadInterTestFont();
    loadPreviewArbs();
  });

  testPreviewsRender(
    'LiveTrackingScreen',
    const <String, Widget Function()>{
      'Loading · cold read': liveTrackingScreenColdRead,
      'Ordered · no jeeber yet': liveTrackingScreenOrdered,
      'Picked up · full active layout': liveTrackingScreenPickedUp,
      'At the door · code inline': liveTrackingScreenAtDoor,
      'At the door · code NOT cached': liveTrackingScreenAtDoorNoCode,
      'Cancelled · terminal': liveTrackingScreenCancelled,
      'Expired · terminal': liveTrackingScreenExpired,
      'Under review · still live': liveTrackingScreenUnderReview,
      'Error · delivery not found': liveTrackingScreenNotFound,
      'Error · network': liveTrackingScreenNetworkError,
      'Longest content': liveTrackingScreenLongestContent,
    },
    expectedText: const <String, String>{
      'Loading · cold read': LiveTrackingScreenCaptions.coldRead,
      'Ordered · no jeeber yet': LiveTrackingScreenCaptions.ordered,
      'Picked up · full active layout': LiveTrackingScreenCaptions.pickedUp,
      'At the door · code inline': LiveTrackingScreenCaptions.atDoor,
      'At the door · code NOT cached': LiveTrackingScreenCaptions.atDoorNoCode,
      'Cancelled · terminal': LiveTrackingScreenCaptions.cancelled,
      'Expired · terminal': LiveTrackingScreenCaptions.expired,
      'Under review · still live': LiveTrackingScreenCaptions.underReview,
      'Error · delivery not found': LiveTrackingScreenCaptions.notFound,
      'Error · network': LiveTrackingScreenCaptions.networkError,
      'Longest content': LiveTrackingScreenCaptions.longestContent,
    },
  );

  group('LiveTrackingScreen preview specifics', () {
    // NB: one preview per test. Pumping a second preview into the same tester

    testWidgets('the phone previews pin a 390 pt frame, not the canvas width', (
      WidgetTester tester,
    ) async {
      // The harness pumps an 800 pt surface: a preview that left its width to
      await pumpPreview(tester, liveTrackingScreenPickedUp);

      expect(tester.getSize(find.byType(LiveTrackingScreen)).width, 390);
    });

    testWidgets('the compact preview pins the 320 pt floor', (
      WidgetTester tester,
    ) async {
      // Capture the overflow rather than letting the binding record it — an
      await _frameErrorsWithFonts(tester, liveTrackingScreenCompact);

      expect(tester.getSize(find.byType(LiveTrackingScreen)).width, 320);
      expect(find.text(LiveTrackingScreenCaptions.compact), findsOneWidget);
    });

    testWidgets('the cold read is a bare spinner with none of the CTAs', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, liveTrackingScreenColdRead);

      expect(find.byType(OmdsLoadingState), findsOneWidget);
      // The app-bar title is the only screen copy on the card.
      expect(find.text('Live tracking'), findsOneWidget);
      // Nothing from `_TrackingBody` exists yet — every affordance on this
      expect(find.bySemanticsIdentifier('tracking_stepper'), findsNothing);
      expect(find.bySemanticsIdentifier('tracking_map'), findsNothing);
      expect(find.text('Delivery code'), findsNothing);
      expect(find.text('Report a problem'), findsNothing);
      expect(find.text("Jeeber didn't show up"), findsNothing);
    });

    testWidgets('ordered mounts neither the pinned header nor the courier card', (
      WidgetTester tester,
    ) async {
      // The floor this screen degrades to between accept and pickup:
      await pumpPreview(tester, liveTrackingScreenOrdered);

      expect(find.bySemanticsIdentifier('order_summary_pinned'), findsNothing);
      expect(find.text('Rami K.'), findsNothing);
      expect(find.text('Distance updating…'), findsOneWidget);
      expect(find.text('Estimated time: —'), findsOneWidget);
      // …but the stepper, the map and both CTAs are already there.
      expect(find.bySemanticsIdentifier('tracking_stepper'), findsOneWidget);
      expect(find.bySemanticsIdentifier('tracking_map'), findsOneWidget);
      expect(find.bySemanticsIdentifier('tracking_dispute_cta'), findsOneWidget);
      expect(find.bySemanticsIdentifier('tracking_noshow_cta'), findsOneWidget);
    });

    testWidgets('the reference reading mounts all seven blocks at once', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, liveTrackingScreenPickedUp);

      expect(
        find.bySemanticsIdentifier('order_summary_pinned'),
        findsOneWidget,
      );
      expect(find.text('Kamal Hajj'), findsOneWidget);
      expect(find.text('Groceries from Spinneys'), findsOneWidget);
      expect(find.text('Pay cash on delivery'), findsOneWidget);
      expect(find.bySemanticsIdentifier('tracking_stepper'), findsOneWidget);
      expect(find.bySemanticsIdentifier('tracking_map'), findsOneWidget);
      // The matched-courier card, mounted only because `info.jeeber` is set.
      expect(find.text('Rami K.'), findsOneWidget);
      // The quiet hand-over row, with the accept-time code in it.
      expect(
        find.bySemanticsIdentifier('tracking_handover_code_row'),
        findsOneWidget,
      );
      expect(find.text('Delivery code'), findsOneWidget);
      expect(find.text(LiveTrackingScreenFixtures.handoverCode), findsOneWidget);
      expect(find.text('3 km away from you'), findsOneWidget);
      expect(find.text('Estimated time: 20 min'), findsOneWidget);
      expect(find.text('Report a problem'), findsOneWidget);
      expect(find.text("Jeeber didn't show up"), findsOneWidget);
      // The delivered step is never lit on this surface — see the finding.
      expect(tester.takeException(), isNull);
    });

    testWidgets('the at-door card renders the code inline and drops the panel', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, liveTrackingScreenAtDoor);

      expect(find.text('Your Jeeber is at the door!'), findsOneWidget);
      expect(
        find.text('Share this code with your Jeeber when they arrive'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('tracking_at_door_code'),
        findsOneWidget,
      );
      // The pre-at-door surfaces are gone: the quiet row and the status panel
      expect(
        find.bySemanticsIdentifier('tracking_handover_code_row'),
        findsNothing,
      );
      expect(
        find.bySemanticsIdentifier('tracking_status_panel'),
        findsNothing,
      );
    });

    testWidgets('without a cached code the door card degrades to "Show OTP"', (
      WidgetTester tester,
    ) async {
      // The reinstall case. The difference between this card and the one above
      await pumpPreview(tester, liveTrackingScreenAtDoorNoCode);

      expect(find.text('Your Jeeber is at the door!'), findsOneWidget);
      expect(
        find.text('Share your code with your Jeeber to confirm the handover.'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('tracking_at_door_code'),
        findsNothing,
      );
      expect(find.text(LiveTrackingScreenFixtures.handoverCode), findsNothing);
      expect(find.text('Show OTP'), findsOneWidget);
    });

    testWidgets('a cancelled row loses every trace of WHICH delivery it was', (
      WidgetTester tester,
    ) async {
      // The finding, pinned. `_TrackingCancelledBody` takes no arguments, so the
      await pumpPreview(tester, liveTrackingScreenCancelled);

      expect(
        find.byKey(const Key('live-tracking-cancelled-state')),
        findsOneWidget,
      );
      expect(find.text('Delivery cancelled'), findsOneWidget);
      expect(find.text('Back to Home'), findsOneWidget);
      // Nothing names the order.
      expect(find.textContaining('DLV-'), findsNothing);
      expect(find.textContaining('REQ-'), findsNothing);
      expect(find.bySemanticsIdentifier('order_summary_pinned'), findsNothing);
      expect(find.bySemanticsIdentifier('tracking_stepper'), findsNothing);
      expect(find.bySemanticsIdentifier('tracking_map'), findsNothing);
    });

    testWidgets('expired is its own body with its own copy, not cancelled', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, liveTrackingScreenExpired);

      expect(
        find.byKey(const Key('live-tracking-expired-state')),
        findsOneWidget,
      );
      expect(find.text('Delivery expired'), findsOneWidget);
      // The pre-fix bug: expired reused the cancelled copy verbatim.
      expect(
        find.byKey(const Key('live-tracking-cancelled-state')),
        findsNothing,
      );
      expect(find.text('Delivery cancelled'), findsNothing);
    });

    testWidgets('under review offers no exit at all', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, liveTrackingScreenUnderReview);

      expect(
        find.byKey(const Key('live-tracking-under-review-state')),
        findsOneWidget,
      );
      expect(find.text('Delivery under review'), findsOneWidget);
      // Deliberately no home CTA — the row is still live — which leaves the
      expect(find.text('Back to Home'), findsNothing);
      expect(
        find.bySemanticsIdentifier('tracking_cancelled_home_cta'),
        findsNothing,
      );
      expect(
        find.bySemanticsIdentifier('tracking_expired_home_cta'),
        findsNothing,
      );
      // …and no stepper rewound to step 1, which was the pre-fix symptom.
      expect(find.bySemanticsIdentifier('tracking_stepper'), findsNothing);
    });

    testWidgets('the 404 gets its own heading and a neutral icon', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, liveTrackingScreenNotFound);

      expect(find.byType(OmdsErrorState), findsOneWidget);
      expect(
        find.byKey(const Key('live-tracking-error-state')),
        findsOneWidget,
      );
      expect(find.text('Delivery not found'), findsOneWidget);
      expect(find.text('Refresh now'), findsOneWidget);
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    });

    testWidgets('the network error has no heading and the GPS-lost icon', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, liveTrackingScreenNetworkError);

      expect(
        find.text('Unable to connect. Check your internet.'),
        findsOneWidget,
      );
      expect(find.text('Delivery not found'), findsNothing);
      expect(find.byIcon(Icons.location_off_outlined), findsOneWidget);
    });

    testWidgets('the error copy is hard-coded English, even in Arabic', (
      WidgetTester tester,
    ) async {
      // The finding, pinned. `LiveTrackingCubit._mapError` and `_mapErrorTitle`
      await _pumpWithFonts(
        tester,
        liveTrackingScreenNotFound,
        locale: const Locale('ar'),
      );

      expect(find.text('Delivery not found'), findsOneWidget);
      expect(
        find.text(
          "We can't find this delivery yet. It may still be getting "
          'ready — pull to retry in a moment.',
        ),
        findsOneWidget,
      );
      // The retry label beside it, and the app-bar title above it, DID localize.
      expect(find.text('تحديث الآن'), findsOneWidget);
      expect(find.text('Refresh now'), findsNothing);
    });

    testWidgets('the longest content wraps rather than clipping', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, liveTrackingScreenLongestContent);

      expect(find.textContaining(_kLongestItemFragment), findsOneWidget);
      expect(
        find.text('Abdulrahman Al-Muhandis Al-Trabulsi'),
        findsOneWidget,
      );
      expect(find.text('12.4 km away from you'), findsOneWidget);
      expect(find.text('Estimated time: 145 min'), findsOneWidget);
    });

    // ONE LOCALE PER CASE, and this is not stylistic. `RenderFlex` inherits
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('the ORDINARY active layout does not fit 320x568 · '
          '${locale.languageCode}', (WidgetTester tester) async {
        // The finding, pinned, and the reason this state is not in the shared
        final List<String> reported = await _frameErrorsWithFonts(
          tester,
          liveTrackingScreenCompact,
          locale: locale,
        );

        expect(reported, isNotEmpty);
        expect(reported.first, contains('overflowed'));
        expect(tester.getSize(find.byType(LiveTrackingScreen)).width, 320);
      });
    }

    testWidgets('the phone frame does not survive the 200% text ceiling', (
      WidgetTester tester,
    ) async {
      // The third rendering of the matrix, measured. Same non-scrolling
      final List<String> doubled = await _frameErrorsAtDoubleText(
        tester,
        liveTrackingScreenPickedUp,
      );

      expect(doubled, isNotEmpty);
      expect(doubled.every((String e) => e.contains('overflowed')), isTrue,
          reason: 'every reported error should be a layout overflow: $doubled');
    });

    testWidgets('opening tracking on a moving delivery GREETS the customer, '
        'every time', (WidgetTester tester) async {
      // The finding, pinned. `_detectEvent` reads
      await _pumpInTransit(tester);

      expect(find.text('Jeeber is on the way!'), findsNothing,
          reason: 'the snackbar has been drained by the 5 s pump');
      // The state itself is the ordinary active layout …
      expect(find.bySemanticsIdentifier('tracking_stepper'), findsOneWidget);
      // … in which the pinned header names a courier the body never shows:
      expect(find.text('Kamal Hajj'), findsOneWidget);
      expect(find.text('Scooter'), findsNothing);
    });

    testWidgets('the greeting snackbar is really on screen before it drains', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, liveTrackingScreenInTransit);

      expect(find.text('Jeeber is on the way!'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);

      // Drain it so the case ends with no pending timer.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('the in-transit card renders in Arabic too', (
      WidgetTester tester,
    ) async {
      // The AR half of the coverage `testPreviewsRender` gives every other
      await _pumpInTransit(tester, locale: const Locale('ar'));

      expect(tester.takeException(), isNull);
      expect(find.text(LiveTrackingScreenCaptions.inTransit), findsOneWidget);
    });
  });
}
