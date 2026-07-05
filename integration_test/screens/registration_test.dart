// Isolated native UI test — registration (RegistrationScreen, phone entry). The
// screen takes a `cubit` seam; we inject a RegistrationCubit over an in-line
// fake OtpService and an empty ticker (no resend/lockout countdown timer). As
// in test/registration_screen_test.dart the social-auth cubit is left to the
// screen's default (constructed lazily; nothing is dialled at build). Captures
// the phone-entry step: branded hero, welcome heading, social section, "or"
// divider, +961 phone field, and the Send-code CTA.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/registration/application/registration_cubit.dart';
import 'package:jeeb_mobile/features/registration/domain/otp_service.dart';
import 'package:jeeb_mobile/features/registration/presentation/registration_screen.dart';

import '../support/screen_harness.dart';

/// No-op OTP service so the phone-entry cubit constructs without a real
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

RegistrationCubit _cubit() => RegistrationCubit(
      otpService: _FakeOtpService(),
      // Empty ticker — the resend/lockout countdown never spawns a timer.
      tickerFactory: () => const Stream<DateTime>.empty(),
    );

Widget _screen(RegistrationCubit cubit) => RegistrationScreen(cubit: cubit);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('registration: phone entry (en)', (tester) async {
    final cubit = _cubit();
    addTearDown(cubit.close);
    await pumpAndShoot(
      tester,
      binding,
      _screen(cubit),
      'registration__phone-entry',
    );
  });

  testWidgets('registration: phone entry (ar)', (tester) async {
    final cubit = _cubit();
    addTearDown(cubit.close);
    await pumpAndShoot(
      tester,
      binding,
      _screen(cubit),
      'registration__phone-entry-ar',
      locale: const Locale('ar'),
    );
  });
}
