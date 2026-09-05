// F16: `resendCode` had NO in-flight guard and no spinner, and folded
// invalidPhone / rateLimited / serverError / networkError into one
// `networkError`.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/registration/application/registration_cubit.dart';
import 'package:jeeb_mobile/features/registration/application/registration_state.dart';
import 'package:jeeb_mobile/features/registration/domain/otp_service.dart';
import 'package:jeeb_mobile/features/registration/domain/registration_attempt_policy.dart';

/// Counts requests and answers the Nth from a script.
class _ScriptedOtpService implements OtpService, OtpSendResultService {
  _ScriptedOtpService(this._script);

  final List<OtpSendResult> _script;
  int calls = 0;
  Completer<OtpSendResult>? gate;

  @override
  Future<OtpSendResult> requestCode(String e164Phone) {
    calls += 1;
    final Completer<OtpSendResult>? held = gate;
    if (calls > 1 && held != null) return held.future;
    final OtpSendResult next =
        _script[calls - 1 < _script.length ? calls - 1 : _script.length - 1];
    return Future<OtpSendResult>.value(next);
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

/// A service that has NOT opted into [OtpSendResultService] — the X1 fallback.
class _LegacyOtpService implements OtpService {
  _LegacyOtpService(this.outcome);

  final OtpSendOutcome outcome;
  int calls = 0;

  @override
  Future<OtpSendOutcome> sendCode(String e164Phone) async {
    calls += 1;
    return outcome;
  }

  @override
  Future<OtpVerifyOutcome> verifyCode({
    required String e164Phone,
    required String code,
  }) async =>
      OtpVerifyOutcome.invalidCode;
}

const RegistrationAttemptPolicy _noCooldown =
    RegistrationAttemptPolicy(resendCooldown: Duration.zero);

Future<RegistrationCubit> _onOtpStep(OtpService service) async {
  final RegistrationCubit cubit = RegistrationCubit(
    otpService: service,
    policy: _noCooldown,
    tickerFactory: () => const Stream<DateTime>.empty(),
  )..phoneChanged('71123456');
  await cubit.sendCode();
  return cubit;
}

void main() {
  test('a double tap on resend issues exactly ONE request', () async {
    final _ScriptedOtpService service = _ScriptedOtpService(
      <OtpSendResult>[const OtpSendResult(outcome: OtpSendOutcome.sent)],
    );
    final RegistrationCubit cubit = await _onOtpStep(service);
    expect(service.calls, 1);

    service.gate = Completer<OtpSendResult>();
    final Future<void> first = cubit.resendCode();
    final Future<void> second = cubit.resendCode();
    expect(service.calls, 2, reason: 'the second tap must be swallowed');

    service.gate!.complete(const OtpSendResult(outcome: OtpSendOutcome.sent));
    await Future.wait(<Future<void>>[first, second]);
    expect(service.calls, 2);
    expect(cubit.state.isSendingCode, isFalse);
    await cubit.close();
  });

  test('isSendingCode is raised for the whole resend and cleared after',
      () async {
    final _ScriptedOtpService service = _ScriptedOtpService(
      <OtpSendResult>[const OtpSendResult(outcome: OtpSendOutcome.sent)],
    );
    final RegistrationCubit cubit = await _onOtpStep(service);
    service.gate = Completer<OtpSendResult>();

    final Future<void> pending = cubit.resendCode();
    expect(cubit.state.isSendingCode, isTrue);

    service.gate!.complete(const OtpSendResult(outcome: OtpSendOutcome.sent));
    await pending;
    expect(cubit.state.isSendingCode, isFalse);
    await cubit.close();
  });

  test('a 5xx resend is a serverError, never a networkError', () async {
    final _ScriptedOtpService service = _ScriptedOtpService(<OtpSendResult>[
      const OtpSendResult(outcome: OtpSendOutcome.sent),
      const OtpSendResult(outcome: OtpSendOutcome.serverError),
    ]);
    final RegistrationCubit cubit = await _onOtpStep(service);

    await cubit.resendCode();

    expect(cubit.state.otpError, RegistrationOtpError.serverError);
    expect(cubit.state.otpError, isNot(RegistrationOtpError.networkError));
    await cubit.close();
  });

  test('a transport failure on resend stays a networkError', () async {
    final _ScriptedOtpService service = _ScriptedOtpService(<OtpSendResult>[
      const OtpSendResult(outcome: OtpSendOutcome.sent),
      const OtpSendResult(outcome: OtpSendOutcome.networkError),
    ]);
    final RegistrationCubit cubit = await _onOtpStep(service);

    await cubit.resendCode();

    expect(cubit.state.otpError, RegistrationOtpError.networkError);
    await cubit.close();
  });

  test('a gateway-rejected number bounces back to the phone step', () async {
    final _ScriptedOtpService service = _ScriptedOtpService(<OtpSendResult>[
      const OtpSendResult(outcome: OtpSendOutcome.sent),
      const OtpSendResult(outcome: OtpSendOutcome.invalidPhone),
    ]);
    final RegistrationCubit cubit = await _onOtpStep(service);

    await cubit.resendCode();

    expect(cubit.state.step, RegistrationStep.phone);
    expect(cubit.state.phoneError, RegistrationPhoneError.invalid);
    expect(cubit.state.otpError, isNull);
    await cubit.close();
  });

  // X1: an OtpService that never heard of OtpSendResultService still works —
  // this is why the interface was NOT widened (R3).
  test('a plain OtpService falls back to sendCode', () async {
    final _LegacyOtpService legacy = _LegacyOtpService(OtpSendOutcome.sent);
    final RegistrationCubit cubit = await _onOtpStep(legacy);

    await cubit.resendCode();

    expect(legacy.calls, 2);
    expect(cubit.state.otpError, isNull);
    // No server window is available, so the local policy is what applies.
    expect(cubit.state.otpRetryAfterSeconds, isNull);
    await cubit.close();
  });
}
