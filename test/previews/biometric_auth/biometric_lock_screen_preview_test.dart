// Render tests for the BiometricLockScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/devtool/catalog/fixtures/biometric_lock_screen_fixtures.dart';
import 'package:jeeb_mobile/features/biometric_auth/application/biometric_lock_cubit.dart';
import 'package:jeeb_mobile/features/biometric_auth/presentation/biometric_lock_screen.dart';

import '../preview_test_harness.dart';

/// The shipped EN copy, verbatim from `lib/l10n/app_en.arb`. These are the
/// per-state fingerprints: the `prompt` sub-status swaps the CTA label and adds
const String _title = 'Unlock Jeeb';
const String _cta = 'Authenticate';
const String _retryCta = 'Try biometrics again';
const String _failureHint = 'Biometric check failed. Try again or use your PIN.';
const String _passwordLink = 'Use password instead';

/// The AR CTA, needed by the one test that has to tap in Arabic.
const String _ctaAr = 'مصادقة';

/// `BiometricLockCubit._osPromptReason` — private to the cubit, so it is
/// transcribed here. It is the string handed to the platform biometric dialog.
const String _osPromptReason = "Confirm it's you to open Jeeb";

/// The smallest display the app supports, mirrored from the fixture so a
/// preview quietly rewired to another window fails here instead of looking
const Size _compactFrame = Size(320, 568);

/// `OmdsPrimaryButton`'s fixed height — the CTA and the link are both one of
/// these, and the overflow assertions are stated in terms of it.
const double _buttonHeight = 48;

/// Hosts one seeded cubit the way the preview section does, for the states that
/// exist to be INTERACTED with rather than looked at (the succeeding gateway,
Widget Function() _hosted(
  BiometricLockCubit Function() create, {
  BiometricLockScreenWindow window = BiometricLockScreenWindows.phone,
  required String caption,
}) =>
    () => BiometricLockScreenPreviewHost(
          key: ValueKey<String>(caption),
          create: create,
          window: window,
          caption: caption,
          screen: const BiometricLockScreen(),
        );

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'BiometricLockScreen',
    const <String, Widget Function()>{
      'Awaiting authentication': biometricLockScreenAwaiting,
      'Prompting': biometricLockScreenPrompting,
      'Failed attempt': biometricLockScreenFailed,
      'Compact 320 × 568': biometricLockScreenCompact,
      'Failed · Compact 320 × 568': biometricLockScreenFailedCompact,
      'Phone · 200% text': biometricLockScreenLargeText,
    },
    // Every state names its own cubit state AND its own window. The screen shows
    expectedText: const <String, String>{
      'Awaiting authentication': 'Awaiting authentication · Phone 390 × 844',
      'Prompting': 'Prompting · Phone 390 × 844',
      'Failed attempt': 'Failed attempt · Phone 390 × 844',
      'Compact 320 × 568': 'Awaiting authentication · Compact 320 × 568',
      'Failed · Compact 320 × 568': 'Failed attempt · Compact 320 × 568',
      'Phone · 200% text':
          'Awaiting authentication · Phone 390 × 844 · 200% text',
    },
  );

  group('BiometricLockScreen preview specifics', () {
    testWidgets('the idle state offers the CTA and no failure copy', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, biometricLockScreenAwaiting);

      expect(find.text(_title), findsOneWidget);
      expect(find.text(_cta), findsOneWidget);
      expect(find.text(_passwordLink), findsOneWidget);
      // A first-frame failure hint would tell a returning user their biometric
      expect(find.text(_failureHint), findsNothing);
      expect(find.text(_retryCta), findsNothing);
    });

    testWidgets('the failed state swaps the CTA label and adds the hint', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, biometricLockScreenFailed);

      expect(find.text(_failureHint), findsOneWidget);
      expect(find.text(_retryCta), findsOneWidget);
      expect(find.text(_cta), findsNothing);
    });

    testWidgets('the prompting state renders identically to idle', (
      WidgetTester tester,
    ) async {
      // Worth pinning because it is the whole design of the state: while the OS
      await pumpPreview(tester, biometricLockScreenPrompting);

      expect(find.text(_cta), findsOneWidget);
      expect(find.text(_failureHint), findsNothing);
    });

    testWidgets('the prompting CTA is dead, not merely dimmed', (
      WidgetTester tester,
    ) async {
      final BiometricLockScreenSeededCubit cubit =
          biometricLockScreenPromptingCubit() as BiometricLockScreenSeededCubit;
      await pumpPreview(tester, _hosted(() => cubit, caption: 'prompting-tap'));

      await tester.tap(find.text(_cta), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Two guards agree here — `isEnabled: false` nulls the GestureDetector's
      expect(cubit.fakeGateway.authenticateCalls, 0);
    });

    testWidgets('success is the ROUTER GATE, not the screen', (
      WidgetTester tester,
    ) async {
      // The screen has no success branch at all: it never listens for
      final BiometricLockScreenSeededCubit cubit =
          biometricLockScreenSucceedingCubit()
              as BiometricLockScreenSeededCubit;
      await pumpPreview(tester, _hosted(() => cubit, caption: 'success'));

      await tester.tap(find.text(_cta));
      await tester.pumpAndSettle();

      expect(cubit.fakeGateway.authenticateCalls, 1);
      expect(find.text(biometricLockScreenShellStandInLabel), findsOneWidget);
      expect(find.byType(BiometricLockScreen), findsNothing);
    });

    testWidgets(
      'AC3: the fallback releases the gate BEFORE it routes',
      (WidgetTester tester) async {
        // The hazard the screen's comment describes is real and the ordering
        await pumpPreview(
          tester,
          _hosted(biometricLockScreenLockedCubit, caption: 'fallback'),
        );

        await tester.tap(find.text(_passwordLink));
        await tester.pumpAndSettle();

        expect(find.byType(BiometricLockScreen), findsNothing);
        expect(
          find.text(biometricLockScreenRegisterStandInLabel),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'KNOWN DEFECT: "Use password instead" leads to phone-OTP, not a password',
      (WidgetTester tester) async {
        // `biometricUnlockUsePasswordLink` is "Use password instead" in EN and
        await pumpPreview(
          tester,
          _hosted(biometricLockScreenLockedCubit, caption: 'password-copy'),
        );

        expect(find.text(_passwordLink), findsOneWidget);
        await tester.tap(find.text(_passwordLink));
        await tester.pumpAndSettle();

        expect(
          find.text(biometricLockScreenRegisterStandInLabel),
          findsOneWidget,
          reason: 'the password link resolved somewhere other than /register',
        );
      },
    );

    testWidgets(
      'KNOWN DEFECT: the failure copy offers a PIN the screen cannot take',
      (WidgetTester tester) async {
        // `biometricLockFailure` reads "…Try again or use your PIN." and there
        await pumpPreview(tester, biometricLockScreenFailed);

        expect(find.text(_failureHint), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        expect(find.byType(EditableText), findsNothing);
        // The two controls the user is actually given, neither of which is a
        expect(find.text(_retryCta), findsOneWidget);
        expect(find.text(_passwordLink), findsOneWidget);
      },
    );

    testWidgets(
      'KNOWN DEFECT: a PIN-only enrolment can never satisfy the CTA',
      (WidgetTester tester) async {
        // `evaluate()` locks a user whenever `enabled && (available || hasPin)`,
        final BiometricLockScreenSeededCubit cubit =
            biometricLockScreenPinOnlyCubit() as BiometricLockScreenSeededCubit;
        await pumpPreview(tester, _hosted(() => cubit, caption: 'pin-only'));

        await tester.tap(find.text(_cta));
        await tester.pumpAndSettle();

        expect(cubit.fakeGateway.authenticateCalls, 1);
        expect(find.text(_retryCta), findsOneWidget);
        expect(find.byType(BiometricLockScreen), findsOneWidget);
        expect(find.byType(EditableText), findsNothing);
      },
    );

    testWidgets(
      'KNOWN DEFECT: the OS prompt reason is English for an Arabic user',
      (WidgetTester tester) async {
        // `BiometricLockCubit._osPromptReason` is a hardcoded literal handed
        final BiometricLockScreenSeededCubit cubit =
            biometricLockScreenSucceedingCubit()
                as BiometricLockScreenSeededCubit;
        await pumpPreview(
          tester,
          _hosted(() => cubit, caption: 'ar-reason'),
          locale: const Locale('ar'),
        );

        // Everything the screen itself renders IS localized …
        expect(find.text(_ctaAr), findsOneWidget);
        await tester.tap(find.text(_ctaAr));
        await tester.pumpAndSettle();

        // … and then the system sheet asks in English.
        expect(cubit.fakeGateway.lastReason, _osPromptReason);
      },
    );

    testWidgets(
      'the Screen Catalog form renders, and swapping its state swaps the cubit',
      (WidgetTester tester) async {
        // The catalog builds the same fixtures with `window: null` — no frame,
        Widget catalogForm(BiometricLockCubit Function() create) =>
            BiometricLockScreenPreviewHost(
              create: create,
              screen: const BiometricLockScreen(),
            );

        await pumpPreview(tester, () => catalogForm(biometricLockScreenLockedCubit));
        expect(find.byType(BiometricLockScreen), findsOneWidget);
        expect(find.text(_cta), findsOneWidget);

        await pumpPreview(
          tester,
          () => catalogForm(biometricLockScreenPromptingCubit),
        );
        expect(find.byType(BiometricLockScreen), findsOneWidget);

        await pumpPreview(tester, () => catalogForm(biometricLockScreenFailedCubit));
        expect(find.text(_retryCta), findsOneWidget);
        expect(find.text(_failureHint), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'KNOWN DEFECT: at 320 × 568 · 200% both controls are off the display '
      'on arrival',
      (WidgetTester tester) async {
        // The preview this asserts is `biometricLockScreenCompactLargeText`,
        await pumpPreview(tester, biometricLockScreenCompactLargeText);

        final Object? error = tester.takeException();
        expect(
          error,
          isFlutterError,
          reason: 'expected the unscrollable Column to overflow',
        );
        expect(error.toString(), contains('overflowed'));

        final Rect frame = tester.getRect(find.byType(BiometricLockScreen));
        expect(frame.size, _compactFrame);

        // 4 pt of the 48 pt CTA is above the bottom edge; the fallback link is
        final Rect cta = tester.getRect(find.text(_cta));
        final Rect link = tester.getRect(find.text(_passwordLink));
        expect(cta.bottom, greaterThan(frame.bottom));
        expect(frame.bottom - cta.top, lessThan(_buttonHeight / 4));
        expect(link.top, greaterThan(frame.bottom));

        // The caption, so a rewired preview fails here rather than passing on
        expect(
          find.text('Awaiting authentication · Compact 320 × 568 · 200% text'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'KNOWN DEFECT: the failed state pushes the same two controls further out',
      (WidgetTester tester) async {
        // `biometricLockScreenFailedCompactLargeText`, also held out of the
        await pumpPreview(tester, biometricLockScreenFailedCompactLargeText);

        final Object? error = tester.takeException();
        expect(error, isFlutterError);
        expect(error.toString(), contains('overflowed'));

        final Rect frame = tester.getRect(find.byType(BiometricLockScreen));
        final Rect cta = tester.getRect(find.text(_retryCta));
        final Rect link = tester.getRect(find.text(_passwordLink));
        expect(cta.top - frame.bottom, greaterThan(_buttonHeight * 3));
        expect(link.top - frame.bottom, greaterThan(_buttonHeight * 5));

        expect(
          find.text('Failed attempt · Compact 320 × 568 · 200% text'),
          findsOneWidget,
        );
      },
    );
  });
}
