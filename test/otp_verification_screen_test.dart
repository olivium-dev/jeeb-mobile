import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/dev_seam/dev_seam.dart';
import 'package:jeeb_mobile/core/dev_seam/dev_seam_config.dart';
import 'package:jeeb_mobile/features/registration/application/registration_cubit.dart';
import 'package:jeeb_mobile/features/registration/domain/otp_service.dart';
import 'package:jeeb_mobile/features/registration/domain/registration_attempt_policy.dart';
import 'package:jeeb_mobile/features/registration/presentation/otp_verification_screen.dart';

import 'support/sync_app_localizations.dart';

class _MockOtpService extends Mock implements OtpService {}

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

  Widget hostScreen(RegistrationCubit cubit, {VoidCallback? onVerified}) {
    return wrapForTest(
      BlocProvider<RegistrationCubit>.value(
        value: cubit,
        child: OtpVerificationScreen(onVerified: onVerified),
      ),
    );
  }

  testWidgets('renders the 4-digit OTP input and the initial 60s countdown',
      (tester) async {
    final cubit = await primedOnOtpStep();
    await tester.pumpWidget(hostScreen(cubit));
    await tester.pump();
    expect(find.byKey(const Key('registration.otpField')), findsOneWidget);
    // The input length must match the live 4-digit gateway contract
    final otpInput = tester.widget<OmdsOtpInput>(
      find.byKey(const Key('registration.otpField')),
    );
    expect(otpInput.length, 4);
    expect(
      find.byKey(const Key('registration.resendCountdown')),
      findsOneWidget,
    );
    // Initial resend countdown is the policy's full cooldown.
    expect(find.textContaining('60'), findsWidgets);
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
}
