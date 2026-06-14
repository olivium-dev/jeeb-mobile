import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omds/omds.dart';

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

  Widget hostScreen(RegistrationCubit cubit, {VoidCallback? onVerified}) {
    return wrapForTest(
      BlocProvider<RegistrationCubit>.value(
        value: cubit,
        child: OtpVerificationScreen(onVerified: onVerified),
      ),
    );
  }

  testWidgets('renders the 6-digit OTP input and the initial 60s countdown',
      (tester) async {
    final cubit = await primedOnOtpStep();
    await tester.pumpWidget(hostScreen(cubit));
    await tester.pump();
    expect(find.byKey(const Key('registration.otpField')), findsOneWidget);
    // P0-3 / defect D1: the input length must match the live 6-digit
    // gateway contract (DioOtpService + FakeOtpService '123456' + ARB copy).
    final otpInput = tester.widget<OmdsOtpInput>(
      find.byKey(const Key('registration.otpField')),
    );
    expect(otpInput.length, 6);
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
}
