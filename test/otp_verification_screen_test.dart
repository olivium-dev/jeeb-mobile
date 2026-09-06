import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/core/dev_seam/dev_seam.dart';
import 'package:jeeb_mobile/core/dev_seam/dev_seam_config.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_code_cells.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_numeric_keypad.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_top_bar.dart';
import 'package:jeeb_mobile/features/registration/application/registration_cubit.dart';
import 'package:jeeb_mobile/features/registration/application/registration_state.dart';
import 'package:jeeb_mobile/features/registration/domain/otp_service.dart';
import 'package:jeeb_mobile/features/registration/domain/registration_attempt_policy.dart';
import 'package:jeeb_mobile/features/registration/presentation/otp_verification_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'support/sync_app_localizations.dart';

class _MockOtpService extends Mock implements OtpService {}

class _SnapshotRegistrationCubit extends RegistrationCubit {
  _SnapshotRegistrationCubit(OtpService service, RegistrationState snapshot)
      : super(otpService: service) {
    emit(snapshot);
  }
}

void main() {
  late _MockOtpService otp;
  late StreamController<DateTime> ticker;

  setUp(() {
    otp = _MockOtpService();
    ticker = StreamController<DateTime>.broadcast();
    when(() => otp.sendCode(any()))
        .thenAnswer((_) async => OtpSendOutcome.sent);
  });

  tearDown(() async {
    await ticker.close();
    DevSeam.debugReset();
  });

  /// Drives the cubit from the initial phone-entry state through `sendCode`
  /// so its state machine ends up on the OTP step naturally. Avoids
  /// touching the protected [Cubit.emit].
  Future<RegistrationCubit> primedOnOtpStep({
    RegistrationAttemptPolicy policy = const RegistrationAttemptPolicy(),
  }) async {
    final cubit = RegistrationCubit(
      otpService: otp,
      policy: policy,
      tickerFactory: () => ticker.stream,
    );
    cubit.phoneChanged('71123456');
    await cubit.sendCode();
    return cubit;
  }

  Widget hostScreen(
    RegistrationCubit cubit, {
    VoidCallback? onVerified,
    Locale locale = const Locale('en'),
  }) {
    return wrapForTest(
      BlocProvider<RegistrationCubit>.value(
        value: cubit,
        child: OtpVerificationScreen(onVerified: onVerified),
      ),
      locale: locale,
    );
  }

  /// The in-screen keypad key carrying [digit] (redesign 03 — the code cells
  /// are display-only, so digits are deposited by tapping the pad).
  Finder keypadKey(String digit) => find.descendant(
        of: find.byType(JeebNumericKeypad),
        matching: find.text(digit),
      );

  Future<void> tapDigits(WidgetTester tester, String digits) async {
    for (final digit in digits.split('')) {
      await tester.tap(keypadKey(digit));
      await tester.pump();
    }
  }

  testWidgets('renders the 4-digit OTP input and the initial 60s countdown',
      (tester) async {
    final cubit = await primedOnOtpStep();
    await tester.pumpWidget(hostScreen(cubit));
    await tester.pump();
    expect(find.byKey(const Key('registration.otpField')), findsOneWidget);
    // The input length must match the live 4-digit gateway contract
    // (`/v1/auth/otp/verify` issues a 4-digit code, e.g. seed `1234`),
    // sourced from kCustomerOtpLength.
    final otpInput = tester.widget<JeebCodeCells>(
      find.byKey(const Key('registration.otpField')),
    );
    expect(otpInput.length, 4);
    expect(
      find.byKey(const Key('registration.resendCountdown')),
      findsOneWidget,
    );
    // Initial resend countdown is the policy's full cooldown, rendered m:ss.
    expect(find.textContaining('1:00'), findsWidgets);
    await cubit.close();
  });

  testWidgets(
      'countdown ticks down on each tick and exposes the Resend button at 0',
      (tester) async {
    final cubit = await primedOnOtpStep(
      policy: const RegistrationAttemptPolicy(
        resendCooldown: Duration(seconds: 2),
      ),
    );
    await tester.pumpWidget(hostScreen(cubit));
    await tester.pump();
    expect(find.byKey(const Key('registration.resendCountdown')),
        findsOneWidget);

    ticker.add(DateTime.now());
    await tester.pump();
    ticker.add(DateTime.now());
    await tester.pump();
    // Cooldown is now 0 → Resend button is mounted in place of the countdown.
    expect(find.byKey(const Key('registration.resend')), findsOneWidget);
    expect(
      find.byKey(const Key('registration.resendCountdown')),
      findsNothing,
    );
    await cubit.close();
  });

  testWidgets('renders the lockout banner after 3 failed attempts',
      (tester) async {
    when(() => otp.verifyCode(
          e164Phone: any(named: 'e164Phone'),
          code: any(named: 'code'),
        )).thenAnswer((_) async => OtpVerifyOutcome.invalidCode);
    final cubit = await primedOnOtpStep();
    await tester.pumpWidget(hostScreen(cubit));
    await tester.pump();

    await cubit.verifyCode('000000');
    await cubit.verifyCode('000000');
    await cubit.verifyCode('000000');
    await tester.pump();

    expect(find.byKey(const Key('registration.lockoutBanner')), findsOneWidget);
    // CTA, attempts counter, and resend row are all hidden in lockout mode.
    expect(find.byKey(const Key('registration.verify')), findsNothing);
    expect(find.byKey(const Key('registration.resend')), findsNothing);
    // Nothing to type into, so the keypad goes with them.
    expect(find.byType(JeebNumericKeypad), findsNothing);
    await cubit.close();
  });

  testWidgets('invokes onVerified when the cubit verifies the code',
      (tester) async {
    when(() => otp.verifyCode(
          e164Phone: any(named: 'e164Phone'),
          code: any(named: 'code'),
        )).thenAnswer((_) async => OtpVerifyOutcome.verified);
    final cubit = await primedOnOtpStep();
    var verified = false;
    await tester.pumpWidget(
      hostScreen(cubit, onVerified: () => verified = true),
    );
    await tester.pump();

    await cubit.verifyCode('123456');
    await tester.pump();

    expect(verified, isTrue);
    await cubit.close();
  });

  testWidgets(
      'OTP test-seam auto-submits jeeb.seam.otp_code through verifyCode',
      (tester) async {
    // The debug-only `jeeb.seam.otp_code` seam lets an automated / on-device
    // driver inject the known code (here the run-branch `1234`) so the verify
    // step advances deterministically without typing into the per-cell input.
    when(() => otp.verifyCode(
          e164Phone: any(named: 'e164Phone'),
          code: any(named: 'code'),
        )).thenAnswer((_) async => OtpVerifyOutcome.verified);
    DevSeam.debugOverride(const DevSeamConfig(otpCode: '1234'));
    final cubit = await primedOnOtpStep();
    var verified = false;
    await tester.pumpWidget(
      hostScreen(cubit, onVerified: () => verified = true),
    );
    // Post-frame callback fires the seam submit; let it settle.
    await tester.pump();
    await tester.pump();

    verify(() => otp.verifyCode(
          e164Phone: any(named: 'e164Phone'),
          code: '1234',
        )).called(1);
    expect(verified, isTrue);
    await cubit.close();
  });

  testWidgets('no OTP seam set → does NOT auto-submit any code',
      (tester) async {
    final cubit = await primedOnOtpStep();
    await tester.pumpWidget(hostScreen(cubit));
    await tester.pump();
    await tester.pump();

    verifyNever(() => otp.verifyCode(
          e164Phone: any(named: 'e164Phone'),
          code: any(named: 'code'),
        ));
    await cubit.close();
  });

  // ── redesign 03: keypad-driven entry ──────────────────────────────────────

  testWidgets('keypad taps fill the cells and auto-verify on the 4th digit',
      (tester) async {
    when(() => otp.verifyCode(
          e164Phone: any(named: 'e164Phone'),
          code: any(named: 'code'),
        )).thenAnswer((_) async => OtpVerifyOutcome.verified);
    final cubit = await primedOnOtpStep();
    var verified = false;
    await tester.pumpWidget(
      hostScreen(cubit, onVerified: () => verified = true),
    );
    await tester.pump();

    await tapDigits(tester, '123');
    // Three digits: nothing submitted yet, and the cells show what was typed.
    verifyNever(() => otp.verifyCode(
          e164Phone: any(named: 'e164Phone'),
          code: any(named: 'code'),
        ));
    expect(
      tester
          .widget<JeebCodeCells>(
            find.byKey(const Key('registration.otpField')),
          )
          .value,
      '123',
    );

    await tapDigits(tester, '4');
    verify(() => otp.verifyCode(
          e164Phone: any(named: 'e164Phone'),
          code: '1234',
        )).called(1);
    expect(verified, isTrue);
    await cubit.close();
  });

  testWidgets('keypad backspace removes the last digit before submitting',
      (tester) async {
    when(() => otp.verifyCode(
          e164Phone: any(named: 'e164Phone'),
          code: any(named: 'code'),
        )).thenAnswer((_) async => OtpVerifyOutcome.verified);
    final cubit = await primedOnOtpStep();
    await tester.pumpWidget(hostScreen(cubit, onVerified: () {}));
    await tester.pump();

    await tapDigits(tester, '129');
    await tester.tap(
      find.descendant(
        of: find.byType(JeebNumericKeypad),
        matching: find.byIcon(Icons.backspace),
      ),
    );
    await tester.pump();
    expect(
      tester
          .widget<JeebCodeCells>(
            find.byKey(const Key('registration.otpField')),
          )
          .value,
      '12',
    );

    await tapDigits(tester, '34');
    verify(() => otp.verifyCode(
          e164Phone: any(named: 'e164Phone'),
          code: '1234',
        )).called(1);
    await cubit.close();
  });

  testWidgets('a rejected code clears the cells so the next four are alone',
      (tester) async {
    when(() => otp.verifyCode(
          e164Phone: any(named: 'e164Phone'),
          code: any(named: 'code'),
        )).thenAnswer((_) async => OtpVerifyOutcome.invalidCode);
    // maxAttempts 3 by default; two wrong codes stay short of the lockout.
    final cubit = await primedOnOtpStep();
    await tester.pumpWidget(hostScreen(cubit));
    await tester.pump();

    await tapDigits(tester, '1234');
    await tester.pump();
    // The listener wiped the buffer — otherwise the 5th tap would be ignored.
    expect(
      tester
          .widget<JeebCodeCells>(
            find.byKey(const Key('registration.otpField')),
          )
          .value,
      isEmpty,
    );

    await tapDigits(tester, '5678');
    verify(() => otp.verifyCode(
          e164Phone: any(named: 'e164Phone'),
          code: '5678',
        )).called(1);
    await cubit.close();
  });

  testWidgets('ar/RTL: cells and keypad stay LTR while the back arrow mirrors',
      (tester) async {
    final cubit = await primedOnOtpStep();
    await tester.pumpWidget(hostScreen(cubit, locale: const Locale('ar')));
    await tester.pump();

    // Sanity: the surrounding layout really is mirrored.
    expect(
      Directionality.of(tester.element(find.byType(JeebTopBar))),
      TextDirection.rtl,
    );
    // D3: the glyph is direction-stable; `matchTextDirection` on
    // `Icons.arrow_back` is what mirrors it under ar.
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward), findsNothing);

    // A code never reorders: cell 0 sits before cell 1 on screen.
    await tapDigits(tester, '12');
    final cells = find.byKey(const Key('registration.otpField'));
    final firstCell =
        tester.getCenter(find.descendant(of: cells, matching: find.text('1')));
    final secondCell =
        tester.getCenter(find.descendant(of: cells, matching: find.text('2')));
    expect(firstCell.dx, lessThan(secondCell.dx));

    // Neither does a dialer: 1 stays left of 3.
    expect(
      tester.getCenter(keypadKey('1')).dx,
      lessThan(tester.getCenter(keypadKey('3')).dx),
    );
    await cubit.close();
  });

  // ── MIDNIGHT R7 ─────────────────────────────────────────────────────────
  //
  // Every assertion below reads a value off the widget rather than trusting a
  // capture: the golden comparator tolerates 5% and each of these moves far
  // less than that.

  testWidgets(
      'R7: the Pattern D Verify pill is GONE — the frozen id survives on a '
      'zero-size node that still carries the verify action', (tester) async {
    final cubit = await primedOnOtpStep();
    await tester.pumpWidget(hostScreen(cubit));
    await tester.pump();

    // The board draws a bare spacer here; no pill, no label.
    expect(find.text('Verify'), findsNothing);
    expect(find.text('Verifying…'), findsNothing);

    final node = find.byKey(const Key('registration.verify'));
    expect(node, findsOneWidget);
    // The pill's whole cost was a 56dp band above the keypad; the re-homed
    // node takes none of it (the stretch parent still hands it a width).
    expect(tester.getSize(node).height, 0);
    expect(
      find.bySemanticsIdentifier('phone_otp_verify_cta'),
      findsOneWidget,
    );
    await cubit.close();
  });

  testWidgets('R7: the in-flight verify speaks from the board-drawn meta slot',
      (tester) async {
    final cubit = await primedOnOtpStep();
    await tester.pumpWidget(hostScreen(cubit));
    await tester.pump();

    final status = find.byKey(const Key('registration.otpStatusLine'));
    expect(tester.widget<Text>(status).data, 'Verifies automatically');

    when(() => otp.verifyCode(
          e164Phone: any(named: 'e164Phone'),
          code: any(named: 'code'),
        )).thenAnswer((_) => Completer<OtpVerifyOutcome>().future);
    await tapDigits(tester, '1234');
    await tester.pump();

    expect(tester.widget<Text>(status).data, 'Verifying…');
    await cubit.close();
  });

  testWidgets(
      'R7: the field draws the periwinkle wash top-START and spends NO orange '
      'glow — the tile mirrors R6, it does not copy it', (tester) async {
    final cubit = await primedOnOtpStep();
    await tester.pumpWidget(hostScreen(cubit));
    await tester.pump();

    final field = tester.widget<JeebMidnightField>(
      find.byType(JeebMidnightField),
    );
    expect(field.variant, JeebFieldVariant.content);
    expect(field.washPlacement, JeebFieldWashPlacement.topStart);
    expect(field.glowColor, Colors.transparent);
    expect(field.animateDecor, isFalse);
    await cubit.close();
  });

  testWidgets(
      'R7: the headline and the resend countdown are INK, not orange — only '
      'Edit spends the accent', (tester) async {
    final cubit = await primedOnOtpStep();
    await tester.pumpWidget(hostScreen(cubit));
    await tester.pump();

    final scheme =
        Theme.of(tester.element(find.byType(JeebCodeCells))).colorScheme;
    final accent = JeebColorRoles.midnight().accent;

    final headline = tester.widget<Text>(find.text('Check your messages'));
    expect(headline.style!.color, scheme.onSurface);
    expect(headline.style!.color, isNot(accent));

    final countdown = tester.widget<Text>(
      find.byKey(const Key('registration.resendCountdown')),
    );
    final spans = (countdown.textSpan! as TextSpan).children!;
    // [0] = "Resend in " (muted), [1] = the m:ss value.
    expect((spans[0] as TextSpan).style!.color, scheme.onSurfaceVariant);
    expect((spans[1] as TextSpan).style!.color, scheme.onSurface);
    expect((spans[1] as TextSpan).style!.color, isNot(accent));

    final edit = tester.widget<Text>(find.text('Edit'));
    expect(edit.style!.color, accent);
    await cubit.close();
  });

  // F16: the resend CTA had NO in-flight affordance at all, so a double tap
  // looked like nothing happening.
  testWidgets('the resend CTA carries the in-flight state', (tester) async {
    final cubit = await primedOnOtpStep(
      policy: const RegistrationAttemptPolicy(resendCooldown: Duration.zero),
    );
    addTearDown(cubit.close);
    await tester.pumpWidget(hostScreen(cubit));
    await tester.pump();

    final resend = tester.widget<JeebCtaButton>(
      find.byKey(const Key('registration.resend')),
    );
    expect(resend.isLoading, isFalse);
    expect(resend.isEnabled, isTrue);
  });

  // AE-16 / F29 / F30: three kinds that used to print one "check your
  // connection" line now print their own.
  testWidgets('serverError, serviceUnavailable and rateLimited each print '
      'their own line', (tester) async {
    final cubit = await primedOnOtpStep();
    addTearDown(cubit.close);
    await tester.pumpWidget(hostScreen(cubit));
    await tester.pump();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(OtpVerificationScreen)),
    );

    expect(
      <String>{
        l10n.registrationOtpServerError,
        l10n.registrationOtpServiceUnavailable,
        l10n.registrationOtpNetworkError,
      }.length,
      3,
      reason: 'the three kinds must not share a string',
    );
  });

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    for (final seconds in <int?>[null, 0, 5]) {
      testWidgets('rate-limited OTP copy respects nullable window $seconds · ${locale.languageCode}', (tester) async {
        final cubit = _SnapshotRegistrationCubit(otp, RegistrationState(
          step: RegistrationStep.otp,
          phoneInput: '71123456',
          otpError: RegistrationOtpError.rateLimited,
          otpRetryAfterSeconds: seconds,
          resendSecondsRemaining: seconds ?? 0,
        ));
        addTearDown(cubit.close);
        await tester.pumpWidget(hostScreen(cubit, locale: locale));
        await tester.pump();
        final l10n = AppLocalizations.of(tester.element(find.byType(OtpVerificationScreen)));
        final expected = seconds == null
            ? l10n.errorRateLimitedBody
            : l10n.registrationOtpRateLimitedSeconds(seconds);
        expect(find.text(expected), findsOneWidget);
        if (seconds == null) {
          expect(find.text(l10n.registrationOtpRateLimitedSeconds(0)), findsNothing);
        }
      });
    }
  }
}
