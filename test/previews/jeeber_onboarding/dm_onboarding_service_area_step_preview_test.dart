// Render tests for the DmOnboardingServiceAreaStep previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. Every state pins a DISTINCT string — the step
// prints the chosen place label twice (map caption + selector row), so the
// fixture caption each preview carries is the only string unique to it, and
// without those pins six cards of the same step would all pass while showing
// the same thing.
//
// Two things this file does that the shared harness cannot:
//
//   * It loads the production Inter faces. Every geometry number below is a
//     device number; with the square test font they are all roughly double.
//   * It pumps a PHONE viewport. `preview_test_harness.dart` uses 800 x 600,
//     which is wider than any phone and lays out every state in this file
//     clean — including the one that overflows by 105 pt at 390 pt.
//
// The in-flight preview is driven outside `testPreviewsRender` because an
// indeterminate spinner never settles.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/previews/jeeber_onboarding/dm_onboarding_service_area_step_preview.dart';

import '../../support/load_test_fonts.dart';
import '../preview_test_harness.dart';

/// Pumps [preview] at a real device box and returns the layout errors that
/// frame produced, joined, or null when it laid out clean.
///
/// Errors are intercepted rather than left for `takeException` so a state that
/// overflows twice (map box AND row) reports both instead of collapsing to
/// "Multiple exceptions (2) were detected".
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
///
/// [edge] disambiguates the frames that overflow twice: at 200 % text a pinned
/// step reports the map box going over the bottom AND the row going over the
/// right, in that order.
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
    // Geometry, not glyphs, is what these previews are for — the numbers below
    // are meaningless under the square test font.
    await loadInterTestFont();
  });

  testPreviewsRender(
    'DmOnboardingServiceAreaStep',
    const <String, Widget Function()>{
      'No base pinned · Continue disabled': dmOnboardingServiceAreaUnpinned,
      'Base pinned · geocoded label': dmOnboardingServiceAreaPinned,
      'Pinned by the map screen · stub label': dmOnboardingServiceAreaStubLabel,
      'Long geocoded label · row overflow': dmOnboardingServiceAreaLongLabel,
      'Coverage check failed · no in-step surface':
          dmOnboardingServiceAreaCoverageFailed,
    },
    // The fixture caption, because the place label is never unique in the tree
    // (map caption + row value) and three of these five states differ by
    // nothing else a text finder can see.
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

  // `isSubmitting: true` renders `OmdsButtonLoading`, i.e. an indeterminate
  // `CircularProgressIndicator`. `pumpAndSettle` (which `pumpPreview` calls)
  // never returns while one is on screen, so this preview gets the same three
  // assertions the shared suite makes — builds in EN, builds in AR, renders its
  // OWN state — driven by fixed pumps instead.
  group('DmOnboardingServiceAreaStep previews · Checking coverage', () {
    Future<void> pumpChecking(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(
        previewCanvas(dmOnboardingServiceAreaCheckingCoverage, locale),
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
      // The CTA label is gone, replaced by the spinner — true of no other
      // preview in this file.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
      // …while the base it is checking is still on screen and still editable.
      expect(find.text('Sassine Square, Ashrafieh'), findsNWidgets(2));
    });
  });

  group('DmOnboardingServiceAreaStep preview specifics', () {
    testWidgets('the entry state gates Continue and never says why', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, dmOnboardingServiceAreaUnpinned);

      // The empty map reads as an intentional empty map, not a broken pin.
      expect(find.byIcon(Icons.map_outlined), findsOneWidget);
      expect(find.text('Tap Location to set your home base'), findsOneWidget);
      expect(find.text('Select'), findsOneWidget);
      // …and that hint is the ONLY instruction. Nothing on the step ties the
      // dimmed CTA to the missing base.
      expect(find.textContaining('required'), findsNothing);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('the disabled Continue declares no disabled state (a11y)', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, dmOnboardingServiceAreaUnpinned);

      expect(
        tester.getSemantics(
          find.bySemanticsIdentifier('dm_onboarding_continue'),
        ),
        isSemantics(
          identifier: 'dm_onboarding_continue',
          label: 'Continue',
          isButton: true,
          hasTapAction: false,
          // The gap: `_ContinueButton` passes `isEnabled: false` to
          // `OmdsLoadingButton`, which spends it on a 60 %-alpha fill, and
          // wraps the CTA in a `Semantics(button: true)` that never sets
          // `enabled:`. So the node carries no enabled state at all — TalkBack
          // and VoiceOver announce a plain button and say nothing about it
          // being inert. Dropping the tap action is the only machine-readable
          // signal, and it is not one screen readers announce.
          hasEnabledState: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('a pinned base prints the same label twice', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, dmOnboardingServiceAreaPinned);

      expect(find.text('Sassine Square, Ashrafieh'), findsNWidgets(2));
      expect(find.byIcon(Icons.location_on), findsNWidgets(2));
      expect(find.text('Tap Location to set your home base'), findsNothing);
      expect(find.text('Select'), findsNothing);
    });

    testWidgets('the pinned CTA is the only one with a tap action', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, dmOnboardingServiceAreaPinned);

      expect(
        tester.getSemantics(
          find.bySemanticsIdentifier('dm_onboarding_continue'),
        ),
        isSemantics(
          identifier: 'dm_onboarding_continue',
          isButton: true,
          hasTapAction: true,
          // Still no enabled state, even now that it IS enabled: the flag is
          // simply never set either way.
          hasEnabledState: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('what ships today: tapping the row labels the base "Location"',
        (WidgetTester tester) async {
      // No `GoRouter` above a preview, so this takes `_pickHomeBase`'s fallback
      // branch — the same stub base the real branch records after the
      // `capture-location` screen pops, because no reverse geocode is wired.
      await pumpPreview(tester, dmOnboardingServiceAreaUnpinned);
      expect(find.text('Location'), findsOneWidget);

      await tester.tap(
        find.bySemanticsIdentifier('service_area_select_location'),
      );
      await tester.pumpAndSettle();

      // Row label, row value, map caption — the same word three times.
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
      await pumpPreview(tester, dmOnboardingServiceAreaStubLabel);

      expect(find.text('Location'), findsNWidgets(3));
    });

    testWidgets('the stub label is localized, not a hardcoded "Location"', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        dmOnboardingServiceAreaStubLabel,
        locale: const Locale('ar'),
      );

      expect(find.text('الموقع'), findsNWidgets(3));
      expect(find.text('Location'), findsNothing);
    });

    testWidgets('a failed coverage probe is indistinguishable from success', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, dmOnboardingServiceAreaCoverageFailed);

      // The cubit emitted `submitFailed`; the step's only listener for it is
      // `DmOnboardingScreen`, which is not in this tree. Nothing here says so.
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

  // The reason this widget needed a canvas. Measured with Inter at real device
  // widths; the shared suite's 800 pt viewport reports every one of these clean.
  group('DmOnboardingServiceAreaStep preview geometry', () {
    testWidgets('a long place name overflows the selector row at 390 pt', (
      WidgetTester tester,
    ) async {
      final String? errors = await _layoutErrorsAt(
        tester,
        dmOnboardingServiceAreaLongLabel,
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
      // Not a curiosity: it is why `testPreviewsRender` passes this preview.
      // Every horizontal assertion in this group has to set a phone width
      // first, or it asserts nothing.
      final String? errors = await _layoutErrorsAt(
        tester,
        dmOnboardingServiceAreaLongLabel,
        size: const Size(800, 640),
      );

      expect(errors, isNull);
    });

    testWidgets('an ordinary address already overflows a 320 pt phone', (
      WidgetTester tester,
    ) async {
      // 'Sassine Square, Ashrafieh' is 25 characters — nothing exotic, and the
      // exact address the saved-address seam seeds.
      expect(
        await _layoutErrorsAt(tester, dmOnboardingServiceAreaPinned),
        isNull,
        reason: 'the 390 pt box is where this state looks fine',
      );

      final String? narrow = await _layoutErrorsAt(
        tester,
        dmOnboardingServiceAreaPinned,
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
        dmOnboardingServiceAreaUnpinned,
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
      // The map hint is gone once a base is pinned, and "Location" is short
      // enough for the row. So today's shipping state passes the accessibility
      // ceiling that both real place names fail — the layout is only healthy
      // while reverse geocoding is missing.
      expect(
        await _layoutErrorsAt(
          tester,
          dmOnboardingServiceAreaStubLabel,
          textScale: 2.0,
        ),
        isNull,
      );

      final String? geocoded = await _layoutErrorsAt(
        tester,
        dmOnboardingServiceAreaPinned,
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
