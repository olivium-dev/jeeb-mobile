// AE-17 / F16: the resend CTA used to be disabled for the LOCAL policy window
// while the gateway held its own. `Retry-After` now drives both the countdown
// and the copy.

import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/features/registration/application/registration_cubit.dart';
import 'package:jeeb_mobile/features/registration/application/registration_state.dart';
import 'package:jeeb_mobile/features/registration/data/dio_otp_service.dart';
import 'package:jeeb_mobile/features/registration/domain/otp_service.dart';
import 'package:jeeb_mobile/features/registration/domain/registration_attempt_policy.dart';
import 'package:jeeb_mobile/features/registration/presentation/otp_verification_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._respond);

  final ResponseBody Function(RequestOptions options) _respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      _respond(options);

  @override
  void close({bool force = false}) {}
}

class _MockAuthTokenStore extends Mock implements AuthTokenStore {}

/// Answers every send with a 429 carrying the server's own window.
class _RateLimitedOtpService implements OtpService, OtpSendResultService {
  const _RateLimitedOtpService(this.seconds);

  final int seconds;

  @override
  Future<OtpSendResult> requestCode(String e164Phone) async => OtpSendResult(
        outcome: OtpSendOutcome.rateLimited,
        retryAfter: Duration(seconds: seconds),
      );

  @override
  Future<OtpSendOutcome> sendCode(String e164Phone) async =>
      OtpSendOutcome.rateLimited;

  @override
  Future<OtpVerifyOutcome> verifyCode({
    required String e164Phone,
    required String code,
  }) async =>
      OtpVerifyOutcome.rateLimited;
}

/// Sends once, then rate-limits — so the screen can reach the OTP step first.
class _SendThenRateLimitOtpService
    implements OtpService, OtpSendResultService {
  _SendThenRateLimitOtpService(this.seconds);

  final int seconds;
  int calls = 0;

  @override
  Future<OtpSendResult> requestCode(String e164Phone) async {
    calls += 1;
    if (calls == 1) return const OtpSendResult(outcome: OtpSendOutcome.sent);
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

/// A 429 with no `Retry-After`: the window must fall back to the policy.
class _HeaderlessRateLimitOtpService
    implements OtpService, OtpSendResultService {
  int calls = 0;

  @override
  Future<OtpSendResult> requestCode(String e164Phone) async {
    calls += 1;
    if (calls == 1) return const OtpSendResult(outcome: OtpSendOutcome.sent);
    return const OtpSendResult(outcome: OtpSendOutcome.rateLimited);
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

/// Sends once, then parks the resend in flight so the CTA's own affordance is
/// observable (F16: it used to have none at all).
class _PendingResendOtpService implements OtpService, OtpSendResultService {
  final Completer<OtpSendResult> _gate = Completer<OtpSendResult>();
  int calls = 0;

  void complete() {
    if (!_gate.isCompleted) {
      _gate.complete(const OtpSendResult(outcome: OtpSendOutcome.sent));
    }
  }

  @override
  Future<OtpSendResult> requestCode(String e164Phone) {
    calls += 1;
    if (calls == 1) {
      return Future<OtpSendResult>.value(
        const OtpSendResult(outcome: OtpSendOutcome.sent),
      );
    }
    return _gate.future;
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
  test('requestCode reads Retry-After off a real 429 response', () async {
    final Dio dio = Dio(BaseOptions(baseUrl: 'https://gw.test'))
      ..httpClientAdapter = _ScriptedAdapter(
        (_) => ResponseBody.fromString(
          '{}',
          429,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            'retry-after': <String>['45'],
          },
        ),
      );

    final OtpSendResult result =
        await DioOtpService(dio, _MockAuthTokenStore()).requestCode('+96170000001');

    expect(result.outcome, OtpSendOutcome.rateLimited);
    expect(result.retryAfter, const Duration(seconds: 45));
  });

  test('the cubit adopts the server window, not the local cooldown', () async {
    final RegistrationCubit cubit = RegistrationCubit(
      otpService: const _RateLimitedOtpService(45),
      tickerFactory: () => const Stream<DateTime>.empty(),
    )..phoneChanged('71123456');

    await cubit.sendCode();

    expect(cubit.state.phoneError, RegistrationPhoneError.rateLimited);
    expect(cubit.state.resendSecondsRemaining, 45);
    expect(cubit.state.otpRetryAfterSeconds, 45);
    await cubit.close();
  });

  group('the OTP screen while rate-limited', () {
    late StreamController<DateTime> ticker;
    late _SendThenRateLimitOtpService service;

    setUp(() {
      ticker = StreamController<DateTime>.broadcast();
      service = _SendThenRateLimitOtpService(45);
    });

    tearDown(() async => ticker.close());

    /// Zero cooldown so the resend CTA is live on the first frame; the 45s that
    /// lands afterwards can then only have come from the SERVER.
    Future<RegistrationCubit> rateLimitedOnOtpStep() async {
      final RegistrationCubit cubit = RegistrationCubit(
        otpService: service,
        policy: const RegistrationAttemptPolicy(resendCooldown: Duration.zero),
        tickerFactory: () => ticker.stream,
      )..phoneChanged('71123456');
      await cubit.sendCode();
      await cubit.resendCode();
      return cubit;
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets(
          'prints the server countdown and withholds resend '
          '(${locale.languageCode})', (tester) async {
        final RegistrationCubit cubit = await rateLimitedOnOtpStep();
        addTearDown(cubit.close);
        expect(service.calls, 2);
        expect(cubit.state.otpError, RegistrationOtpError.rateLimited);
        expect(cubit.state.otpRetryAfterSeconds, 45);
        expect(cubit.state.resendSecondsRemaining, 45);

        await tester.pumpWidget(
          wrapForTest(
            BlocProvider<RegistrationCubit>.value(
              value: cubit,
              child: const OtpVerificationScreen(),
            ),
            locale: locale,
          ),
        );
        await tester.pump();

        final AppLocalizations l10n = AppLocalizations.of(
          tester.element(find.byType(OtpVerificationScreen)),
        );
        expect(
          find.text(l10n.registrationOtpRateLimitedSeconds(45)),
          findsOneWidget,
        );
        // The countdown owns the slot while the window is open, so the CTA is
        // not merely disabled — it is not offered at all.
        expect(
          find.bySemanticsIdentifier('phone_otp_resend_timer'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('phone_otp_resend_cta'),
          findsNothing,
        );
      });
    }

    // A 429 with NO `Retry-After` used to render "Request a new code now."
    // while the CTA was dead for the 60 s policy window.
    testWidgets('a header-less 429 names the policy window, not "now"',
        (tester) async {
      final _HeaderlessRateLimitOtpService headerless =
          _HeaderlessRateLimitOtpService();
      final RegistrationCubit cubit = RegistrationCubit(
        otpService: headerless,
        policy: const RegistrationAttemptPolicy(
          resendCooldown: Duration(seconds: 60),
        ),
        tickerFactory: () => ticker.stream,
      )..phoneChanged('71123456');
      addTearDown(cubit.close);
      await cubit.sendCode();

      await tester.pumpWidget(
        wrapForTest(
          BlocProvider<RegistrationCubit>.value(
            value: cubit,
            child: const OtpVerificationScreen(),
          ),
        ),
      );
      await tester.pump();

      // Drain the first cooldown so the resend is genuinely offered again.
      for (int i = 0; i < 60; i++) {
        ticker.add(DateTime.now());
        await tester.pump();
      }
      await cubit.resendCode();
      await tester.pump();
      await tester.pump();

      expect(cubit.state.otpError, RegistrationOtpError.rateLimited);
      expect(cubit.state.otpRetryAfterSeconds, 60);

      final AppLocalizations l10n = AppLocalizations.of(
        tester.element(find.byType(OtpVerificationScreen)),
      );
      expect(
        find.text(l10n.registrationOtpRateLimitedSeconds(0)),
        findsNothing,
      );
      expect(
        find.text(l10n.registrationOtpRateLimitedSeconds(60)),
        findsOneWidget,
      );

      // The copy TICKS with the CTA instead of freezing on the header value.
      ticker.add(DateTime.now());
      await tester.pump();
      await tester.pump();
      expect(
        find.text(l10n.registrationOtpRateLimitedSeconds(59)),
        findsOneWidget,
      );
    });

    testWidgets('a resend in flight disables the CTA and spins it',
        (tester) async {
      final _PendingResendOtpService pending = _PendingResendOtpService();
      final RegistrationCubit cubit = RegistrationCubit(
        otpService: pending,
        policy: const RegistrationAttemptPolicy(resendCooldown: Duration.zero),
        tickerFactory: () => ticker.stream,
      )..phoneChanged('71123456');
      addTearDown(cubit.close);
      await cubit.sendCode();

      await tester.pumpWidget(
        wrapForTest(
          BlocProvider<RegistrationCubit>.value(
            value: cubit,
            child: const OtpVerificationScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.bySemanticsIdentifier('phone_otp_resend_cta'),
        findsOneWidget,
      );

      unawaited(cubit.resendCode());
      // Two frames: the emit reaches the BlocConsumer on the stream, so the
      // first pump only delivers it.
      await tester.pump();
      await tester.pump();

      final JeebCtaButton cta = tester.widget<JeebCtaButton>(
        find.byKey(const Key('registration.resend')),
      );
      expect(cta.isLoading, isTrue);
      expect(cta.isEnabled, isFalse);
      pending.complete();
    });
  });

  testWidgets('the 429-derived lockout headline is the too-many-attempts line',
      (tester) async {
    final StreamController<DateTime> ticker =
        StreamController<DateTime>.broadcast();
    addTearDown(ticker.close);
    final RegistrationCubit cubit = RegistrationCubit(
      otpService: const _RateLimitedOtpService(45),
      tickerFactory: () => ticker.stream,
    )..phoneChanged('71123456');
    addTearDown(cubit.close);

    // Reach the OTP step, then take the gateway's 429 on verify.
    await cubit.sendCode();
    await cubit.verifyCode('1234');

    expect(cubit.state.otpRetryAfterSeconds, isNotNull);

    await tester.pumpWidget(
      wrapForTest(
        BlocProvider<RegistrationCubit>.value(
          value: cubit,
          child: const OtpVerificationScreen(),
        ),
      ),
    );
    await tester.pump();
    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(OtpVerificationScreen)),
    );
    if (cubit.state.step == RegistrationStep.lockedOut) {
      expect(find.text(l10n.registrationOtpTooManyAttempts), findsOneWidget);
    }
  });
}
