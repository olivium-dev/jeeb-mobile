// Render tests for the DmOnboardingScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/jeeber_onboarding/presentation/dm_onboarding_screen.dart';

import '../../support/load_test_fonts.dart';
import '../preview_test_harness.dart';

/// The coverage-probe failure copy (`dmOnboardingCoverageCheckFailed`).
const String _kCoverageFailedCopy =
    "Couldn't check coverage for this area. Please try again.";

/// The photo-pick failure copy (`dmOnboardingPhotoPickFailed`).
const String _kPhotoFailedCopy = "Couldn't use that photo. Please try again.";

/// The longest-content preview's home base. Declared here rather than imported
const String _kLongestLabel = 'Beirut Souks — Parking Level B2, Weygand Street';

/// Wraps [preview] in the golden fallback family.
Widget Function() _fonted(Widget Function() preview) => () => Builder(
      builder: (BuildContext context) => Theme(
        data: withGoldenTestFonts(Theme.of(context)),
        child: preview(),
      ),
    );

/// The phone frame — the wizard's own `Scaffold`.
Finder get _frame => find.byKey(DmOnboardingScreen.rootKey);

/// The wizard's shared Continue CTA, inside the phone frame.
Finder get _framedContinue => find.descendant(
      of: find.byKey(DmOnboardingScreen.rootKey),
      matching: find.bySemanticsIdentifier('dm_onboarding_continue'),
    );

/// Pumps [preview] with framework errors intercepted rather than recorded.
Future<List<FlutterErrorDetails>> _pumpCatchingErrors(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) async {
  final List<FlutterErrorDetails> caught = <FlutterErrorDetails>[];
  final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
  FlutterError.onError = caught.add;
  try {
    await pumpPreview(tester, preview, locale: locale);
  } finally {
    FlutterError.onError = previous;
  }
  return caught;
}

void main() {
  setUpAll(() async {
    await loadInterTestFont();
    loadPreviewArbs();
  });

  // Every preview except `Step 3 · Checking coverage`, whose spinner cannot
  testPreviewsRender(
    'DmOnboardingScreen',
    <String, Widget Function()>{
      'Step 1 · Photo · nothing chosen': _fonted(dmOnboardingScreenPhotoStep),
      'Step 2 · Personal details · empty':
          _fonted(dmOnboardingScreenAddressStep),
      'Step 3 · Service area · no home base':
          _fonted(dmOnboardingScreenServiceArea),
      'Step 3 · Coverage check failed':
          _fonted(dmOnboardingScreenCoverageFailed),
      'Step 1 · Camera permission denied':
          _fonted(dmOnboardingScreenPhotoPickDenied),
    },
    expectedText: const <String, String>{
      'Step 1 · Photo · nothing chosen': 'fixture: step 1, no photo chosen',
      'Step 2 · Personal details · empty': 'fixture: step 2, empty address',
      'Step 3 · Service area · no home base': 'fixture: step 3, no home base',
      'Step 3 · Coverage check failed':
          'fixture: step 3, coverage probe throws',
      'Step 1 · Camera permission denied':
          'fixture: step 1, camera permission denied',
    },
  );

  // The in-flight state. `OmdsLoadingButton` renders an indeterminate
  group('DmOnboardingScreen previews · Step 3 · Checking coverage', () {
    Future<void> pumpChecking(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(
        previewCanvas(_fonted(dmOnboardingScreenCheckingCoverage), locale),
      );
      await tester.pump(); // resolve localizations
      await tester.pump(const Duration(milliseconds: 16)); // one spinner frame
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Step 3 · Checking coverage · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpChecking(tester, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Checking coverage renders its own state', (
      WidgetTester tester,
    ) async {
      await pumpChecking(tester);

      expect(
        find.text('fixture: step 3, coverage probe never lands'),
        findsOneWidget,
      );
      // The CTA label is gone, replaced by the spinner — true of no other
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
      // The probe is in flight and nothing has failed yet.
      expect(find.byType(SnackBar), findsNothing);
      // …and the base being checked is still on screen, still re-pinnable: the
      expect(find.text('Sassine Square, Ashrafieh'), findsNWidgets(2));
    });
  });

  // The layout ceiling, on the narrowest phone the app supports. It overflows,
  group('DmOnboardingScreen previews · Longest content · compact 320', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Longest content · compact 320 · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        final List<FlutterErrorDetails> caught = await _pumpCatchingErrors(
          tester,
          _fonted(dmOnboardingScreenLongestContent),
          locale: locale,
        );

        expect(
          caught,
          isNotEmpty,
          reason: 'a 47-character place name in a 320 pt frame must still '
              'overflow `_SelectLocationRowBody` — if this is now clean the '
              'row has been given a Flexible and the preview note should go',
        );
        for (final FlutterErrorDetails details in caught) {
          expect(
            details.exception.toString(),
            contains('overflowed'),
            reason: 'only the documented row overflow is tolerated here',
          );
        }
        // Nothing may reach the binding either — an error raised outside the
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Longest content · compact 320 renders its own state', (
      WidgetTester tester,
    ) async {
      await _pumpCatchingErrors(
        tester,
        _fonted(dmOnboardingScreenLongestContent),
      );

      expect(
        find.text('fixture: step 3, longest geocoded label'),
        findsOneWidget,
      );
      // Printed twice: centred under the map pin, where it wraps and looks
      expect(find.text(_kLongestLabel), findsNWidgets(2));
    });

    testWidgets('the compact preview pins the 320 x 568 floor', (
      WidgetTester tester,
    ) async {
      await _pumpCatchingErrors(
        tester,
        _fonted(dmOnboardingScreenLongestContent),
      );

      // Width is exact; height is the 568 pt box minus the fixture caption.
      expect(tester.getSize(find.byType(DmOnboardingScreen)).width, 320);
    });
  });

  group('DmOnboardingScreen preview specifics', () {
    // NB: one preview per test. Pumping a second preview into the same tester
    testWidgets('the phone previews pin a 390 pt frame, not the canvas width', (
      WidgetTester tester,
    ) async {
      // The harness pumps an 800 pt surface: a preview that left its width to
      await pumpPreview(tester, _fonted(dmOnboardingScreenPhotoStep));

      expect(tester.getSize(find.byType(DmOnboardingScreen)).width, 390);
    });

    testWidgets('each step preview carries its own app-bar title', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, _fonted(dmOnboardingScreenPhotoStep));
      expect(find.text('Image'), findsOneWidget);
      expect(find.text('Personal Details'), findsNothing);
      expect(find.text('Service Area'), findsNothing);
    });

    testWidgets('step 2 is the address step, gated on nothing', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, _fonted(dmOnboardingScreenAddressStep));

      expect(find.text('Personal Details'), findsOneWidget);
      // D20 (JM-037): no vehicle field — state / country / street / address.
      expect(find.byType(TextField), findsNWidgets(4));
      // …and every one of them may be left blank: the address step passes no
      expect(
        tester.getSemantics(_framedContinue),
        matchesSemantics(
          identifier: 'dm_onboarding_continue',
          label: 'Continue',
          isButton: true,
          hasTapAction: true,
        ),
      );
    });

    testWidgets('step 3 gates Continue until a base is pinned', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, _fonted(dmOnboardingScreenServiceArea));

      expect(find.text('Service Area'), findsOneWidget);
      expect(find.text('Tap Location to set your home base'), findsOneWidget);
      // The gate is a colour and a dropped tap action; nothing on the step says
      expect(find.textContaining('required'), findsNothing);
    });

    // The JEBV4-13 P1-5 fix, which lives ONLY on this screen: the same cubit
    testWidgets('a failed coverage probe raises the honest error copy', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, _fonted(dmOnboardingScreenCoverageFailed));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(_kCoverageFailedCopy),
        ),
        findsOneWidget,
      );
      // The probe is finished and the CTA is live again — the failure is the
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Continue'), findsOneWidget);
    });

    // The one thing the CANVAS gets wrong about this screen, pinned so nobody
    testWidgets('the toast escapes the phone frame in the preview host, and '
        'lands on the CTA on a device', (WidgetTester tester) async {
      await pumpPreview(tester, _fonted(dmOnboardingScreenCoverageFailed));

      expect(
        find.descendant(of: _frame, matching: find.byType(SnackBar)),
        findsNothing,
        reason: 'the nested host Scaffold, not the wizard, presents it',
      );

      // A floating SnackBar is bottom-anchored to the Scaffold presenting it,
      final Rect toast = tester.getRect(find.byType(SnackBar));
      final Rect frame = tester.getRect(_frame);
      final Rect cta = tester.getRect(_framedContinue);
      final Rect onDevice = toast.translate(0, frame.bottom - toast.bottom);

      expect(
        onDevice.overlaps(cta),
        isTrue,
        reason: 'showOmdsErrorSnackbar raises a FLOATING SnackBar at the '
            'bottom of the Scaffold and DmOnboardingStepLayout pins Continue '
            'to the bottom of the same Scaffold, so for the toast\'s four '
            'seconds the message covers the only way to try again',
      );
    });

    testWidgets('the error is one-shot: the wizard keeps no trace of it', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, _fonted(dmOnboardingScreenCoverageFailed));
      expect(find.byType(SnackBar), findsOneWidget);

      // The listener acknowledges immediately, so once the toast times out
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      expect(find.textContaining("Couldn't"), findsNothing);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Sassine Square, Ashrafieh'), findsNWidgets(2));
    });

    // The wizard's shared back button does two different things, and only one
    testWidgets('Back steps the wizard on step 2, and needs a router on step 1',
        (WidgetTester tester) async {
      await pumpPreview(tester, _fonted(dmOnboardingScreenAddressStep));

      await tester.tap(find.bySemanticsIdentifier('dm_onboarding_back'));
      await tester.pumpAndSettle();
      // A cubit call — no router involved.
      expect(find.text('Image'), findsOneWidget);
      expect(find.text('Personal Details'), findsNothing);

      // …and now Back is the leave-the-wizard branch, which reaches for
      await tester.tap(find.bySemanticsIdentifier('dm_onboarding_back'));
      await tester.pump();
      expect(tester.takeException(), isNotNull);
    });

    testWidgets('a denied camera permission gets photo copy, not coverage copy',
        (WidgetTester tester) async {
      await pumpPreview(tester, _fonted(dmOnboardingScreenPhotoPickDenied));

      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(_kPhotoFailedCopy),
        ),
        findsOneWidget,
      );
      expect(find.text(_kCoverageFailedCopy), findsNothing);
      // The copy blames the photo, offers no route to Settings, and leaves the
      expect(find.textContaining('Settings'), findsNothing);
      expect(
        tester.getSemantics(_framedContinue),
        matchesSemantics(
          identifier: 'dm_onboarding_continue',
          label: 'Continue',
          isButton: true,
          hasTapAction: false,
        ),
      );
    });
  });
}
