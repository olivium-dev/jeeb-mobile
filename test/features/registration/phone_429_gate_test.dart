// AE-17: the phone step started the server's 429 countdown but nothing
// consumed it — Send stayed live and the user could hammer the gateway.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/features/registration/application/registration_cubit.dart';
import 'package:jeeb_mobile/features/registration/application/registration_state.dart';
import 'package:jeeb_mobile/features/registration/domain/otp_service.dart';
import 'package:jeeb_mobile/features/registration/presentation/registration_screen.dart';

import '../../support/sync_app_localizations.dart';

/// Every send is refused with the server's own window; the calls are counted.
class _CountingRateLimitedOtpService
    implements OtpService, OtpSendResultService {
  _CountingRateLimitedOtpService(this.seconds);

  final int seconds;
  int calls = 0;

  @override
  Future<OtpSendResult> requestCode(String e164Phone) async {
    calls += 1;
    return OtpSendResult(
      outcome: OtpSendOutcome.rateLimited,
      retryAfter: Duration(seconds: seconds),
    );
  }

  @override
  Future<OtpSendOutcome> sendCode(String e164Phone) async =>
      (await requestCode(e164Phone)).outcome;

  @override
  Future<OtpVerifyOutcome> verifyCode({
    required String e164Phone,
    required String code,
  }) async =>
      OtpVerifyOutcome.invalidCode;
}

void main() {
  late StreamController<DateTime> ticker;
  late _CountingRateLimitedOtpService service;

  setUp(() {
    ticker = StreamController<DateTime>.broadcast();
    service = _CountingRateLimitedOtpService(45);
  });

  tearDown(() async => ticker.close());

  RegistrationCubit makeCubit() => RegistrationCubit(
        otpService: service,
        tickerFactory: () => ticker.stream,
      )..phoneChanged('71123456');

  test('a second send inside the 429 window never reaches the gateway',
      () async {
    final RegistrationCubit cubit = makeCubit();
    addTearDown(cubit.close);

    await cubit.sendCode();
    expect(service.calls, 1);
    expect(cubit.state.phoneError, RegistrationPhoneError.rateLimited);
    expect(cubit.state.resendSecondsRemaining, 45);

    await cubit.sendCode();
    await cubit.sendCode();

    expect(service.calls, 1);
  });

  test('the window expiring clears the 429 copy and reopens the CTA', () async {
    final RegistrationCubit cubit = RegistrationCubit(
      otpService: service,
      tickerFactory: () => ticker.stream,
    )..phoneChanged('71123456');
    addTearDown(cubit.close);

    await cubit.sendCode();
    expect(cubit.state.resendSecondsRemaining, 45);

    for (int i = 0; i < 45; i++) {
      ticker.add(DateTime.now());
      await Future<void>.delayed(Duration.zero);
    }

    expect(cubit.state.resendSecondsRemaining, 0);
    expect(cubit.state.phoneError, isNull);
    expect(cubit.state.otpRetryAfterSeconds, isNull);
    expect(cubit.state.isRateLimitedNow, isFalse);

    await cubit.sendCode();
    expect(service.calls, 2);
  });

  testWidgets('the Send CTA is genuinely disabled for the server window',
      (tester) async {
    final RegistrationCubit cubit = makeCubit();
    addTearDown(cubit.close);

    await tester.pumpWidget(
      wrapForTest(RegistrationScreen(cubit: cubit)),
    );
    await tester.enterText(
      find.byKey(const Key('registration.phoneField')),
      '71123456',
    );
    await tester.pump();

    JeebCtaButton cta() => tester.widget<JeebCtaButton>(
          find.byKey(const Key('registration.sendCode')),
        );
    expect(cta().isEnabled, isTrue);

    await tester.tap(find.byKey(const Key('registration.sendCode')));
    await tester.pump();
    await tester.pump();

    expect(service.calls, 1);
    expect(cta().isEnabled, isFalse);

    // A second tap on the dead pill must not queue a request either.
    await tester.tap(
      find.byKey(const Key('registration.sendCode')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(service.calls, 1);
  });
}
