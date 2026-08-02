// Render tests for the BiometricPromptScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand.
//
// This screen is a hard case for "does this preview render ITS OWN state?".
// `_PromptAction` branches on three of `BiometricState`'s six values and
// returns `SizedBox.shrink()` for the other three, so `initial`, `failed` and
// `authenticated` are the SAME PICTURE: one fingerprint, one heading, one
// subtitle, nothing underneath. Screen copy therefore cannot separate them, and
// the previews carry a caption ([BiometricPromptScreenCaptions], the same
// device as `OtpVerificationScreenCaptions`) for `expectedText`. The groups
// below assert the real state behind each caption — which branch built, whether
// the CTA is mounted, whether a spinner is up — so a preview wired to the wrong
// fixture fails here instead of passing on its caption alone.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/biometric_login/presentation/biometric_prompt_screen.dart';

import '../preview_test_harness.dart';

/// The `Authenticate` CTA, mounted only on `BiometricState.available`.
final Finder _cta = find.byType(OmdsPrimaryButton);

/// `OmdsLoadingState`'s indeterminate spinner — the `checking` branch.
final Finder _spinner = find.byType(CircularProgressIndicator);

/// The 80 pt `Sizes.eightXLarge` mark every state renders.
final Finder _fingerprint = find.byIcon(Icons.fingerprint);

/// `l10n.useBiometrics` — the one localized string in `_PromptHeader`.
const String _headingEn = 'Use Biometrics';
const String _headingAr = 'استخدام القياسات الحيوية';

/// `_PromptHeader`'s subtitle. A string LITERAL in the screen: there is no
/// matching key in `lib/l10n/app_en.arb` or `lib/l10n/app_ar.arb`, so this is
/// what an Arabic user reads too.
const String _subtitleHardcoded = 'Sign in quickly with your fingerprint or face';

/// `_PromptAction`'s CTA label — a string literal for the same reason.
const String _ctaHardcoded = 'Authenticate';

/// `l10n.biometricNotAvailable` — the only copy any state swaps in.
const String _unavailableEn = 'Biometric authentication not available';
const String _unavailableAr = 'المصادقة بالقياسات الحيوية غير متاحة';

/// Pumps [preview] into a FRESH element tree.
///
/// The previews are keyed by caption, so back-to-back pumps already cannot
/// share a seeded cubit; clearing the tree makes it unconditional for the loops
/// that walk several states inside one test.
Future<void> _pumpFresh(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpPreview(tester, preview, locale: locale);
}

void main() {
  setUpAll(loadPreviewArbs);

  // Every preview whose surface both settles and lays out cleanly. Two are
  // excluded and get their own groups below:
  //
  //   * `Checking` — `OmdsLoadingState` wraps a `CircularProgressIndicator`
  //     whose controller `repeat()`s forever, so `pumpAndSettle` (which
  //     `pumpPreview` calls) never returns on it;
  //   * `Unavailable · compact at 200% text` — it OVERFLOWS by design, and a
  //     `RenderFlex` overflow is a `FlutterError` that would fail this suite's
  //     `takeException(), isNull`. That group asserts the overflow instead.
  testPreviewsRender(
    'BiometricPromptScreen',
    const <String, Widget Function()>{
      'Initial · before the probe': biometricPromptScreenInitial,
      'Available · authenticate CTA': biometricPromptScreenAvailable,
      'Unavailable · nothing enrolled': biometricPromptScreenUnavailable,
      'Failed · no error, no retry': biometricPromptScreenFailed,
      'Authenticated · success is invisible': biometricPromptScreenAuthenticated,
    },
    expectedText: const <String, String>{
      // The captions, not the copy: `Use Biometrics` and the hardcoded subtitle
      // are rendered by all five, and three of them render nothing else.
      'Initial · before the probe': BiometricPromptScreenCaptions.initial,
      'Available · authenticate CTA': BiometricPromptScreenCaptions.available,
      'Unavailable · nothing enrolled':
          BiometricPromptScreenCaptions.unavailable,
      'Failed · no error, no retry': BiometricPromptScreenCaptions.failed,
      'Authenticated · success is invisible':
          BiometricPromptScreenCaptions.authenticated,
    },
  );

  /// `pumpAndSettle` cannot be used on a repeating animation, so the spinning
  /// preview gets the same three assertions the shared suite makes (builds in
  /// EN, builds in AR, renders its OWN state) driven by fixed pumps instead.
  Future<void> pumpSpinning(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      previewCanvas(biometricPromptScreenChecking, locale),
    );
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  group('BiometricPromptScreen previews · Checking', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Checking · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpSpinning(tester, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Checking renders its own state', (WidgetTester tester) async {
      await pumpSpinning(tester);

      expect(find.text(BiometricPromptScreenCaptions.checking), findsOneWidget);
      // The spinner is up...
      expect(_spinner, findsOneWidget);
      // ...and none of the settled branches is.
      expect(_cta, findsNothing);
      expect(find.text(_unavailableEn), findsNothing);
      // Nothing labels the spinner — `OmdsLoadingState` is built with no
      // `message`, and there is no ARB key for one.
      expect(find.text('Checking'), findsNothing);
      expect(find.textContaining('Checking your'), findsNothing);
    });
  });

  group('BiometricPromptScreen previews · the state behind the caption', () {
    testWidgets('Available is the only state with an affordance', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, biometricPromptScreenAvailable);

      expect(_cta, findsOneWidget);
      expect(tester.widget<OmdsPrimaryButton>(_cta).text, _ctaHardcoded);
      expect(find.text(_ctaHardcoded), findsOneWidget);
      expect(_spinner, findsNothing);
      expect(find.text(_unavailableEn), findsNothing);
      // The a11y handle the E2E suite drives.
      expect(
        find.bySemanticsIdentifier('biometric_prompt_authenticate_cta'),
        findsOneWidget,
      );
    });

    testWidgets('Unavailable swaps in the only copy any state owns', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, biometricPromptScreenUnavailable);

      expect(find.text(_unavailableEn), findsOneWidget);
      expect(_cta, findsNothing);
      expect(_spinner, findsNothing);
      // ...directly under an invitation to do the thing it just said is
      // impossible. Both are on screen at once.
      expect(find.text(_subtitleHardcoded), findsOneWidget);
    });

    testWidgets('initial, failed and authenticated are the SAME picture', (
      WidgetTester tester,
    ) async {
      // `_PromptAction` has no branch for any of the three, so each falls
      // through to `SizedBox.shrink()`. A user rejected by the OS prompt and a
      // user who has not been asked yet and a user who just SUCCEEDED are shown
      // identical surfaces.
      for (final Widget Function() preview in <Widget Function()>[
        biometricPromptScreenInitial,
        biometricPromptScreenFailed,
        biometricPromptScreenAuthenticated,
      ]) {
        await _pumpFresh(tester, preview);

        expect(_fingerprint, findsOneWidget);
        expect(find.text(_headingEn), findsOneWidget);
        expect(find.text(_subtitleHardcoded), findsOneWidget);
        // Nothing else. No CTA, no spinner, no error, no retry, and no
        // password fallback.
        expect(_cta, findsNothing);
        expect(_spinner, findsNothing);
        expect(find.text(_unavailableEn), findsNothing);
        expect(find.byType(TextButton), findsNothing);
        expect(find.textContaining('Try again'), findsNothing);
        expect(find.textContaining('password'), findsNothing);
      }
    });

    testWidgets('the failed state offers no way out at all', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, biometricPromptScreenFailed);

      // The screen has no app bar and no back affordance of its own, and the
      // only control it ever mounts is gone in this state.
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(BackButton), findsNothing);
      expect(_cta, findsNothing);
    });
  });

  group('BiometricPromptScreen previews · Arabic', () {
    testWidgets('the heading localizes and the two strings below it do not', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        biometricPromptScreenAvailable,
        locale: const Locale('ar'),
      );

      // `l10n.useBiometrics` — the one localized string on this screen.
      expect(find.text(_headingAr), findsOneWidget);
      expect(find.text(_headingEn), findsNothing);
      // `_PromptHeader`'s subtitle and `_PromptAction`'s label are literals.
      // An Arabic user gets an Arabic heading over two English lines.
      expect(find.text(_subtitleHardcoded), findsOneWidget);
      expect(find.text(_ctaHardcoded), findsOneWidget);
    });

    testWidgets('the unavailable message IS localized', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        biometricPromptScreenUnavailable,
        locale: const Locale('ar'),
      );

      expect(find.text(_unavailableAr), findsOneWidget);
      expect(find.text(_unavailableEn), findsNothing);
    });
  });

  group('BiometricPromptScreen previews · compact at 200% text', () {
    /// Pumps the clipping preview and CONSUMES the layout error it provokes,
    /// so the caller can assert on it instead of being failed by it.
    ///
    /// `RenderFlex` reports an overflow exactly once per render object
    /// (`paintOverflowIndicator` clears its own report flag), so one
    /// `takeException` drains the frame.
    Future<Object?> pumpClipped(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await pumpPreview(
        tester,
        biometricPromptScreenCompactLargeText,
        locale: locale,
      );
      return tester.takeException();
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Unavailable · compact at 200% text · ${locale.languageCode}',
          (WidgetTester tester) async {
        final Object? error = await pumpClipped(tester, locale: locale);

        // The ONLY thing that goes wrong here is the overflow. Anything else
        // out of this preview would surface as a different message.
        expect(error, isA<FlutterError>());
        expect(error.toString(), contains('overflowed'));
      });
    }

    testWidgets('it renders its own state', (WidgetTester tester) async {
      await pumpPreview(tester, biometricPromptScreenCompactLargeText);

      expect(
        find.text(BiometricPromptScreenCaptions.compactLargeText),
        findsOneWidget,
      );
      expect(find.text(_unavailableEn), findsOneWidget);
      expect(tester.takeException(), isA<FlutterError>());
    });

    testWidgets('the window is really 320 x 568, not the 800 x 600 surface', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, biometricPromptScreenCompactLargeText);

      // The frame is pinned by the fixture rather than by the canvas `size:`,
      // which is the whole reason the measurement below means anything: under
      // test everything else would be laid out on an 800 x 600 surface and this
      // state would silently stop clipping.
      expect(
        tester.getSize(find.byType(BiometricPromptScreen)),
        const Size(320, 568),
      );
      expect(tester.takeException(), isA<FlutterError>());
    });

    testWidgets('the centred column does not fit and nothing scrolls it', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, biometricPromptScreenCompactLargeText);

      final Rect frame = tester.getRect(find.byType(BiometricPromptScreen));
      final Rect message = tester.getRect(find.text(_unavailableEn));

      // `_PromptColumn` is a bare `Column` inside `Center` inside `SafeArea`
      // with no scroll view above it, so at the accessibility ceiling on the
      // smallest supported display the composition is laid out past the bottom
      // edge of the device and clipped — there is no way for the user to reach
      // it. (`RenderFlex` clamps `remainingSpace` at zero, so a centred column
      // that does not fit overflows downward only, which is why the fingerprint
      // stays put and the message is what falls off.)
      expect(message.bottom, greaterThan(frame.bottom));
      expect(
        find.descendant(
          of: find.byType(BiometricPromptScreen),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
      // 260 px at the time of writing. Asserted loosely so a copy or spacing
      // tweak does not fail the test for the wrong reason — the claim is "it
      // does not fit", not "it misses by exactly this much".
      expect(
        tester.takeException().toString(),
        contains('A RenderFlex overflowed by'),
      );
    });
  });
}
