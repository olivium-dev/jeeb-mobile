import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/jeeber_onboarding/presentation/widgets/dm_onboarding_service_area_step.dart';

import '../../support/load_test_fonts.dart';
import '../preview_test_harness.dart';

/// Pumps [preview] at a real device box and returns the layout errors that
Future<String?> _layoutErrorsAt(
  WidgetTester tester,
  Widget Function() preview, {
  Size size = const Size(390, 640),
  double textScale = 1.0,
  Locale locale = const Locale('en'),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final List<String> errors = <String>[];
  final prior = FlutterError.onError;
  FlutterError.onError =
      (FlutterErrorDetails details) => errors.add(details.exception.toString());
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: previewCanvas(preview, locale),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
  FlutterError.onError = prior;

  return errors.isEmpty ? null : errors.join(' + ');
}

/// `A RenderFlex overflowed by 105 pixels on the right.` -> 105.
int _overflowPixels(String? errors, String edge) {
  final RegExpMatch? m = RegExp(
    'overflowed by (\\d+) pixels on the $edge',
  ).firstMatch(errors ?? '');
  expect(
    m,
    isNotNull,
    reason: 'expected an overflow on the $edge, got: $errors',
  );
  return int.parse(m!.group(1)!);
}

void main() {
  setUpAll(() async {
    loadPreviewArbs();
    await loadInterTestFont();
  });

  testPreviewsRender(
    'DmOnboardingServiceAreaStep',
    const <String, Widget Function()>{
      'No base pinned · Continue disabled': dmOnboardingServiceAreaStepUnpinned,
      'Base pinned · geocoded label': dmOnboardingServiceAreaStepPinned,
      'Pinned by the map screen · stub label': dmOnboardingServiceAreaStepStubLabel,
      'Long geocoded label · row overflow': dmOnboardingServiceAreaStepLongLabel,
      'Coverage check failed · no in-step surface':
          dmOnboardingServiceAreaStepCoverageFailed,
    },
    expectedText: const <String, String>{
      'No base pinned · Continue disabled': 'fixture: no home base',
      'Base pinned · geocoded label': 'fixture: geocoded label',
      'Pinned by the map screen · stub label':
          'fixture: stub base recorded on pop',
      'Long geocoded label · row overflow': 'fixture: long geocoded label',
      'Coverage check failed · no in-step surface':
          'fixture: coverage probe throws',
    },
  );

  group('DmOnboardingServiceAreaStep previews · Checking coverage', () {
    Future<void> pumpChecking(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(
        previewCanvas(dmOnboardingServiceAreaStepCheckingCoverage, locale),
      );
      await tester.pump(); // resolve localizations
      await tester.pump(const Duration(milliseconds: 16)); // one spinner frame
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Checking coverage · CTA spinner · ${locale.languageCode}', (
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

      expect(find.text('fixture: coverage probe never lands'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
      expect(find.text('Sassine Square, Ashrafieh'), findsNWidgets(2));
    });
  });

  group('DmOnboardingServiceAreaStep preview specifics', () {
    testWidgets('the entry state gates Continue and never says why', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, dmOnboardingServiceAreaStepUnpinned);

      expect(find.byIcon(Icons.map_outlined), findsOneWidget);
      expect(find.text('Tap Location to set your home base'), findsOneWidget);
      expect(find.text('Select'), findsOneWidget);
      expect(find.textContaining('required'), findsNothing);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('the disabled Continue declares no disabled state (a11y)', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, dmOnboardingServiceAreaStepUnpinned);

      expect(
        tester.getSemantics(
          find.bySemanticsIdentifier('dm_onboarding_continue'),
        ),
        isSemantics(
          identifier: 'dm_onboarding_continue',
          label: 'Continue',
          isButton: true,
          hasTapAction: false,
          hasEnabledState: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('a pinned base prints the same label twice', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, dmOnboardingServiceAreaStepPinned);

      expect(find.text('Sassine Square, Ashrafieh'), findsNWidgets(2));
      expect(find.byIcon(Icons.location_on), findsNWidgets(2));
      expect(find.text('Tap Location to set your home base'), findsNothing);
      expect(find.text('Select'), findsNothing);
    });

    testWidgets('the pinned CTA is the only one with a tap action', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, dmOnboardingServiceAreaStepPinned);

      expect(
        tester.getSemantics(
          find.bySemanticsIdentifier('dm_onboarding_continue'),
        ),
        isSemantics(
          identifier: 'dm_onboarding_continue',
          isButton: true,
          hasTapAction: true,
          hasEnabledState: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('what ships today: tapping the row labels the base "Location"',
        (WidgetTester tester) async {
      await pumpPreview(tester, dmOnboardingServiceAreaStepUnpinned);
      expect(find.text('Location'), findsOneWidget);

      await tester.tap(
        find.bySemanticsIdentifier('service_area_select_location'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Location'), findsNWidgets(3));
      expect(find.text('Select'), findsNothing);
      expect(
        find.text('fixture: no home base'),
        findsOneWidget,
        reason: 'still the unpinned preview: the label came from the tap, not '
            'from a different fixture',
      );
    });

    testWidgets('the stub-label preview is that same state, seeded', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, dmOnboardingServiceAreaStepStubLabel);

      expect(find.text('Location'), findsNWidgets(3));
    });

    testWidgets('the stub label is localized, not a hardcoded "Location"', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        dmOnboardingServiceAreaStepStubLabel,
        locale: const Locale('ar'),
      );

      expect(find.text('الموقع'), findsNWidgets(3));
      expect(find.text('Location'), findsNothing);
    });

    testWidgets('a failed coverage probe is indistinguishable from success', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, dmOnboardingServiceAreaStepCoverageFailed);

      expect(find.byType(SnackBar), findsNothing);
      expect(
        find.text("Couldn't check coverage for this area. Please try again."),
        findsNothing,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Sassine Square, Ashrafieh'), findsNWidgets(2));
    });
  });

  group('DmOnboardingServiceAreaStep preview geometry', () {
    testWidgets('a long place name overflows the selector row at 390 pt', (
      WidgetTester tester,
    ) async {
      final String? errors = await _layoutErrorsAt(
        tester,
        dmOnboardingServiceAreaStepLongLabel,
      );

      expect(errors, contains('on the right'));
      expect(
        _overflowPixels(errors, 'right'),
        greaterThan(60),
        reason: 'measured 105 pt over at 390 pt. `_SelectLocationRowBody` puts '
            'the value in a bare Text — no Flexible, no maxLines, no ellipsis '
            '— so the row cannot absorb it and the chevron is pushed off the '
            'trailing edge. If this is now clean the Text has been wrapped and '
            'the preview library note should go.',
      );
    });

    testWidgets('…and the 800 pt harness viewport hides it completely', (
      WidgetTester tester,
    ) async {
      final String? errors = await _layoutErrorsAt(
        tester,
        dmOnboardingServiceAreaStepLongLabel,
        size: const Size(800, 640),
      );

      expect(errors, isNull);
    });

    testWidgets('an ordinary address already overflows a 320 pt phone', (
      WidgetTester tester,
    ) async {
      expect(
        await _layoutErrorsAt(tester, dmOnboardingServiceAreaStepPinned),
        isNull,
        reason: 'the 390 pt box is where this state looks fine',
      );

      final String? narrow = await _layoutErrorsAt(
        tester,
        dmOnboardingServiceAreaStepPinned,
        size: const Size(320, 640),
      );

      expect(narrow, contains('on the right'));
      expect(
        _overflowPixels(narrow, 'right'),
        greaterThan(5),
        reason: 'measured 17 pt over at 320 pt (iPhone SE, small Android). The '
            'geocoded happy path does not fit the smallest supported phone.',
      );
    });

    testWidgets('the map placeholder clips its own hint at 200% text', (
      WidgetTester tester,
    ) async {
      final String? errors = await _layoutErrorsAt(
        tester,
        dmOnboardingServiceAreaStepUnpinned,
        textScale: 2.0,
      );

      expect(errors, contains('on the bottom'));
      expect(
        _overflowPixels(errors, 'bottom'),
        greaterThan(10),
        reason: 'measured 28 pt over at 390 pt / 200 % (68 pt in Arabic). The '
            'pin box is a hard Sizes.elevenXLarge = 100 pt under a ClipRRect, '
            'so the accessibility ceiling cuts "Tap Location to set your home '
            'base" — the only instruction on the step.',
      );
    });

    testWidgets('the one-word stub label is the only state 200% text spares', (
      WidgetTester tester,
    ) async {
      expect(
        await _layoutErrorsAt(
          tester,
          dmOnboardingServiceAreaStepStubLabel,
          textScale: 2.0,
        ),
        isNull,
      );

      final String? geocoded = await _layoutErrorsAt(
        tester,
        dmOnboardingServiceAreaStepPinned,
        textScale: 2.0,
      );

      expect(geocoded, contains('on the right'));
      expect(
        _overflowPixels(geocoded, 'right'),
        greaterThan(100),
        reason: 'measured 181 pt over at 390 pt / 200 %',
      );
    });
  });
}
