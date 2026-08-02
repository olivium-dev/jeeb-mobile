// Render tests for the BiometricLockScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// Two things about this screen make "did it render" a weak question, so the
// suite below does more than pump.
//
// 1. Several states are the SAME pixels. `locked` and `prompting` differ only in
//    a disabled tint on the CTA, and four of the previews are one composition in
//    four windows. The expected strings therefore pin the fixture's diagnostic
//    CAPTION — the only thing that distinguishes a preview wired to the wrong
//    state from a correct one — and the specifics group pins the controls each
//    state is supposed to be showing.
// 2. Both of this screen's OUTCOMES are invisible in a rendering. It never
//    navigates on success (the central router gate does) and its fallback link
//    navigates without changing anything on screen. The fixture mounts the gate
//    and two labelled stand-in pages so both can be followed and asserted.
//
// Two previews are deliberately absent from `testPreviewsRender`:
// `biometricLockScreenCompactLargeText` and
// `biometricLockScreenFailedCompactLargeText` both overflow, and the shared
// suite asserts that nothing throws. They are covered by the KNOWN DEFECT cases
// at the bottom of this file, which pin the overflow AND the resulting geometry
// — a plain "it throws" would keep passing if the composition changed shape.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/devtool/catalog/fixtures/biometric_lock_screen_fixtures.dart';
import 'package:jeeb_mobile/features/biometric_auth/application/biometric_lock_cubit.dart';
import 'package:jeeb_mobile/features/biometric_auth/presentation/biometric_lock_screen.dart';

import '../preview_test_harness.dart';

/// The shipped EN copy, verbatim from `lib/l10n/app_en.arb`. These are the
/// per-state fingerprints: the `prompt` sub-status swaps the CTA label and adds
/// the hint, and nothing else on the screen changes.
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
/// plausible in the canvas.
const Size _compactFrame = Size(320, 568);

/// `OmdsPrimaryButton`'s fixed height — the CTA and the link are both one of
/// these, and the overflow assertions are stated in terms of it.
const double _buttonHeight = 48;

/// Hosts one seeded cubit the way the preview section does, for the states that
/// exist to be INTERACTED with rather than looked at (the succeeding gateway,
/// the PIN-only enrolment). Keyed, so pumping two in one test remounts.
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
    // the same icon, the same title and the same two buttons in all six, and
    // `Awaiting authentication` / `Prompting` are separated on screen by nothing
    // but a tint — so without this a preview wired to the wrong state, or six
    // previews accidentally sharing one, would pass unnoticed.
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
      // is broken before they have tried it.
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
      // sheet is being asked for, the screen says nothing at all. There is no
      // spinner, no copy, and the label does not change — only the fill dims. On
      // a device where the platform sheet fails to appear, this frame is the
      // entire feedback the user gets.
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
      // handler, and `authenticate()` returns early while `isPrompting`. If this
      // ever reads 1, a second platform sheet is being requested on top of the
      // first.
      expect(cubit.fakeGateway.authenticateCalls, 0);
    });

    testWidgets('success is the ROUTER GATE, not the screen', (
      WidgetTester tester,
    ) async {
      // The screen has no success branch at all: it never listens for
      // `phase == unlocked` and never navigates. The fixture carries the app's
      // own gate redirects, so this is the first place the AC2 path can actually
      // be watched end to end.
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
        // handles it: the fixture gate pulls any off-`/lock` location back to
        // `/lock` while the phase is `locked`, so a `goNamed` issued before the
        // release would bounce straight back. Landing on the stand-in is the
        // proof that it does not.
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
        // "استخدم كلمة المرور بدلاً من ذلك" in AR, and its ARB metadata still
        // documents the destination as `/login`. That funnel was deleted in
        // JEBV4-199, so the tap lands on `/register` — phone number, SMS code,
        // no password anywhere. The user is being offered a credential the app
        // no longer has.
        //
        // Pins the CURRENT behaviour. If it starts failing because the link now
        // reaches something password-shaped, or because the copy was changed to
        // match the destination, delete this test and the matching note in
        // `biometric_lock_screen.dart`.
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
        // is no PIN entry on this screen, in this feature, or on this route —
        // `SharedPrefsPinRepository` is write-only from the UI's point of view.
        await pumpPreview(tester, biometricLockScreenFailed);

        expect(find.text(_failureHint), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        expect(find.byType(EditableText), findsNothing);
        // The two controls the user is actually given, neither of which is a
        // PIN: retry the biometric, or leave for registration.
        expect(find.text(_retryCta), findsOneWidget);
        expect(find.text(_passwordLink), findsOneWidget);
      },
    );

    testWidgets(
      'KNOWN DEFECT: a PIN-only enrolment can never satisfy the CTA',
      (WidgetTester tester) async {
        // `evaluate()` locks a user whenever `enabled && (available || hasPin)`,
        // so a PIN alone is enough to hold them here. The CTA then drives the
        // gateway — `UnavailableBiometricGateway` in production, which hard
        // returns false — and the screen offers no way to present the PIN that
        // locked them. Every tap fails, forever; the only exit is the fallback
        // link out to registration.
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
        // straight to the gateway, and it is the only user-visible string on
        // this flow that never passes through a `Text` — no preview, golden or
        // screenshot can show it. The fake gateway records it instead.
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
        // no caption, the device IS the display — and moves between states with
        // a picker that replaces this host with another of the same type and no
        // key. That is an UPDATE, not a remount, so without the `create` check
        // in `didUpdateWidget` the catalog would go on showing the first state
        // under the second state's name. Both halves are asserted here because
        // nothing else in CI opens the catalog.
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
        // held out of the shared suite because it throws. Nothing has gone wrong
        // in this state — it is the cold-start gate, first frame, before any
        // interaction.
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
        // entirely below it. There is no scroll view in the body's chain, so
        // neither can be brought into view.
        final Rect cta = tester.getRect(find.text(_cta));
        final Rect link = tester.getRect(find.text(_passwordLink));
        expect(cta.bottom, greaterThan(frame.bottom));
        expect(frame.bottom - cta.top, lessThan(_buttonHeight / 4));
        expect(link.top, greaterThan(frame.bottom));

        // The caption, so a rewired preview fails here rather than passing on
        // another window's overflow.
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
        // shared suite. The failure hint is what adds the extra height, so the
        // state that says "try again or use your PIN" is the state in which
        // neither tappable thing is on screen.
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
