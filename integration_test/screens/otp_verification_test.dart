// Isolated native UI test — OtpVerificationScreen (phone-otp-verification,
// JM-009). Unlike RegistrationScreen this screen has no `cubit` constructor
// seam — it reads the RegistrationCubit from context — so we host it under a
// BlocProvider.value seeded onto the OTP step. The cubit is driven from
// phone-entry through `sendCode` over an in-line fake OtpService (exactly as
// test/otp_verification_screen_test.dart's `primedOnOtpStep`), with an empty
// ticker so the resend countdown never spawns a timer (a pending timer fails
// the harness). onVerified is a no-op so nothing navigates under the plain
// MaterialApp. Captures the 4-digit code-entry idle state.
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/registration/application/registration_cubit.dart';
import 'package:jeeb_mobile/features/registration/domain/otp_service.dart';
import 'package:jeeb_mobile/features/registration/presentation/otp_verification_screen.dart';

import '../support/screen_harness.dart';

/// No-op OTP service so the cubit reaches the OTP step without a real
/// auth-service client or network.
class _FakeOtpService implements OtpService {
  @override
  Future<OtpSendOutcome> sendCode(String e164Phone) async =>
      OtpSendOutcome.sent;

  @override
  Future<OtpVerifyOutcome> verifyCode({
    required String e164Phone,
    required String code,
  }) async =>
      OtpVerifyOutcome.verified;
}

/// Drives the cubit from phone-entry through `sendCode` so its state machine
/// lands on [RegistrationStep.otp] naturally (no protected emit).
Future<RegistrationCubit> _cubitOnOtpStep() async {
  final cubit = RegistrationCubit(
    otpService: _FakeOtpService(),
    // Empty ticker — the resend/lockout countdown never spawns a timer.
    tickerFactory: () => const Stream<DateTime>.empty(),
  );
  cubit.phoneChanged('71123456');
  await cubit.sendCode();
  return cubit;
}

Widget _screen(RegistrationCubit cubit) => BlocProvider<RegistrationCubit>.value(
      value: cubit,
      child: OtpVerificationScreen(onVerified: () {}),
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('otp-verification: code entry (en)', (tester) async {
    final cubit = await _cubitOnOtpStep();
    addTearDown(cubit.close);
    await pumpAndShoot(
      tester,
      binding,
      _screen(cubit),
      'otp-verification__idle',
    );
  });

  testWidgets('otp-verification: code entry (ar)', (tester) async {
    final cubit = await _cubitOnOtpStep();
    addTearDown(cubit.close);
    await pumpAndShoot(
      tester,
      binding,
      _screen(cubit),
      'otp-verification__idle-ar',
      locale: const Locale('ar'),
    );
  });
}
