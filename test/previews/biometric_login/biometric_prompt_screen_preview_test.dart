// Render tests for the BiometricPromptScreen previews.

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
const String _subtitleHardcoded = 'Sign in quickly with your fingerprint or face';

/// `_PromptAction`'s CTA label — a string literal for the same reason.
const String _ctaHardcoded = 'Authenticate';

/// `l10n.biometricNotAvailable` — the only copy any state swaps in.
const String _unavailableEn = 'Biometric authentication not available';
const String _unavailableAr = 'المصادقة بالقياسات الحيوية غير متاحة';

/// Pumps [preview] into a FRESH element tree.
/// The previews are keyed by caption, so back-to-back pumps already cannot
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
      expect(find.text(_subtitleHardcoded), findsOneWidget);
    });

    testWidgets('initial, failed and authenticated are the SAME picture', (
      WidgetTester tester,
    ) async {
      // `_PromptAction` has no branch for any of the three, so each falls
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
      expect(message.bottom, greaterThan(frame.bottom));
      expect(
        find.descendant(
          of: find.byType(BiometricPromptScreen),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
      // 260 px at the time of writing. Asserted loosely so a copy or spacing
      expect(
        tester.takeException().toString(),
        contains('A RenderFlex overflowed by'),
      );
    });
  });
}
