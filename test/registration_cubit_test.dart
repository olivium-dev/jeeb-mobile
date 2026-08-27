import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/features/registration/application/registration_cubit.dart';
import 'package:jeeb_mobile/features/registration/application/registration_state.dart';
import 'package:jeeb_mobile/features/registration/domain/otp_service.dart';
import 'package:jeeb_mobile/features/registration/domain/registration_attempt_policy.dart';

class _MockOtpService extends Mock implements OtpService {}

void main() {
  late _MockOtpService otp;
  late StreamController<DateTime> ticker;

  setUp(() {
    otp = _MockOtpService();
    ticker = StreamController<DateTime>.broadcast();
  });

  tearDown(() async {
    await ticker.close();
  });

  RegistrationCubit build({
    RegistrationAttemptPolicy policy = const RegistrationAttemptPolicy(),
  }) {
    return RegistrationCubit(
      otpService: otp,
      policy: policy,
      tickerFactory: () => ticker.stream,
    );
  }

  group('phoneChanged', () {
    blocTest<RegistrationCubit, RegistrationState>(
      'normalises the input (strips +961, separators)',
      build: build,
      act: (c) => c.phoneChanged('+961 71-123 456'),
      expect: () => [
        predicate<RegistrationState>(
          (s) => s.phoneInput == '71123456' && s.isPhoneReady,
        ),
      ],
    );

    blocTest<RegistrationCubit, RegistrationState>(
      'keeps partial input as-not-yet-ready',
      build: build,
      act: (c) => c.phoneChanged('711'),
      expect: () => [
        predicate<RegistrationState>(
          (s) => s.phoneInput == '711' && !s.isPhoneReady,
        ),
      ],
    );

    blocTest<RegistrationCubit, RegistrationState>(
      'retains the national input when the country changes',
      build: build,
      seed: () => const RegistrationState(phoneInput: '612345678'),
      act: (cubit) => cubit.countryChanged('NL'),
      expect: () => [
        predicate<RegistrationState>(
          (state) =>
              state.selectedCountryCode == 'NL' &&
              state.phoneInput == '612345678' &&
              state.isPhoneReady,
        ),
      ],
    );
  });

  group('sendCode', () {
    blocTest<RegistrationCubit, RegistrationState>(
      'surfaces an invalid-phone error when the number is too short',
      build: build,
      seed: () => const RegistrationState(phoneInput: '711'),
      act: (c) => c.sendCode(),
      expect: () => [
        predicate<RegistrationState>(
          (s) => s.phoneError == RegistrationPhoneError.invalid,
        ),
      ],
    );

    blocTest<RegistrationCubit, RegistrationState>(
      'transitions to OTP step on success and starts the resend countdown',
      build: build,
      seed: () => const RegistrationState(phoneInput: '71123456'),
      setUp: () => when(
        () => otp.sendCode(any()),
      ).thenAnswer((_) async => OtpSendOutcome.sent),
      act: (c) async {
        await c.sendCode();
      },
      expect: () => [
        predicate<RegistrationState>(
          (s) => s.isSendingCode && s.step == RegistrationStep.phone,
        ),
        predicate<RegistrationState>(
          (s) =>
              !s.isSendingCode &&
              s.step == RegistrationStep.otp &&
              s.resendSecondsRemaining == 60,
        ),
      ],
      verify: (_) {
        verify(() => otp.sendCode('+96171123456')).called(1);
      },
    );

    blocTest<RegistrationCubit, RegistrationState>(
      'surfaces a gateway-rejected phone as invalid',
      build: build,
      seed: () => const RegistrationState(phoneInput: '71123456'),
      setUp: () => when(
        () => otp.sendCode(any()),
      ).thenAnswer((_) async => OtpSendOutcome.invalidPhone),
      act: (c) => c.sendCode(),
      skip: 1, // skip the optimistic "sending…" frame
      expect: () => [
        predicate<RegistrationState>(
          (s) =>
              !s.isSendingCode &&
              s.phoneError == RegistrationPhoneError.invalid &&
              s.step == RegistrationStep.phone,
        ),
      ],
    );

    blocTest<RegistrationCubit, RegistrationState>(
      'surfaces rate-limit as a phone error',
      build: build,
      seed: () => const RegistrationState(phoneInput: '71123456'),
      setUp: () => when(
        () => otp.sendCode(any()),
      ).thenAnswer((_) async => OtpSendOutcome.rateLimited),
      act: (c) => c.sendCode(),
      skip: 1, // skip the optimistic "sending…" frame
      expect: () => [
        predicate<RegistrationState>(
          (s) =>
              !s.isSendingCode &&
              s.phoneError == RegistrationPhoneError.rateLimited &&
              s.step == RegistrationStep.phone,
        ),
      ],
    );

    blocTest<RegistrationCubit, RegistrationState>(
      'surfaces a gateway fault as a network phone error',
      build: build,
      seed: () => const RegistrationState(phoneInput: '71123456'),
      setUp: () => when(
        () => otp.sendCode(any()),
      ).thenAnswer((_) async => OtpSendOutcome.serverError),
      act: (c) => c.sendCode(),
      skip: 1, // skip the optimistic "sending…" frame
      expect: () => [
        predicate<RegistrationState>(
          (s) =>
              !s.isSendingCode &&
              s.phoneError == RegistrationPhoneError.networkError &&
              s.step == RegistrationStep.phone,
        ),
      ],
    );

    blocTest<RegistrationCubit, RegistrationState>(
      'surfaces a transport failure as a network phone error',
      build: build,
      seed: () => const RegistrationState(phoneInput: '71123456'),
      setUp: () => when(
        () => otp.sendCode(any()),
      ).thenAnswer((_) async => OtpSendOutcome.networkError),
      act: (c) => c.sendCode(),
      skip: 1, // skip the optimistic "sending…" frame
      expect: () => [
        predicate<RegistrationState>(
          (s) =>
              !s.isSendingCode &&
              s.phoneError == RegistrationPhoneError.networkError &&
              s.step == RegistrationStep.phone,
        ),
      ],
    );

    blocTest<RegistrationCubit, RegistrationState>(
      'sends the selected international number unchanged as E.164',
      build: build,
      seed: () => const RegistrationState(
        selectedCountryCode: 'NL',
        phoneInput: '612345678',
      ),
      setUp: () => when(
        () => otp.sendCode(any()),
      ).thenAnswer((_) async => OtpSendOutcome.sent),
      act: (cubit) => cubit.sendCode(),
      verify: (_) {
        verify(() => otp.sendCode('+31612345678')).called(1);
      },
    );
  });

  group('verifyCode', () {
    blocTest<RegistrationCubit, RegistrationState>(
      'transitions to verified on a correct code',
      build: build,
      seed: () => const RegistrationState(
        phoneInput: '71123456',
        step: RegistrationStep.otp,
      ),
      setUp: () => when(
        () => otp.verifyCode(
          e164Phone: any(named: 'e164Phone'),
          code: any(named: 'code'),
        ),
      ).thenAnswer((_) async => OtpVerifyOutcome.verified),
      act: (c) => c.verifyCode('123456'),
      skip: 1, // skip the "verifying…" frame
      expect: () => [
        predicate<RegistrationState>(
          (s) => s.step == RegistrationStep.verified && !s.isVerifying,
        ),
      ],
    );

    blocTest<RegistrationCubit, RegistrationState>(
      'increments failedAttempts on wrong code (1st attempt)',
      build: build,
      seed: () => const RegistrationState(
        phoneInput: '71123456',
        step: RegistrationStep.otp,
      ),
      setUp: () => when(
        () => otp.verifyCode(
          e164Phone: any(named: 'e164Phone'),
          code: any(named: 'code'),
        ),
      ).thenAnswer((_) async => OtpVerifyOutcome.invalidCode),
      act: (c) => c.verifyCode('000000'),
      skip: 1,
      expect: () => [
        predicate<RegistrationState>(
          (s) =>
              s.failedAttempts == 1 &&
              s.otpError == RegistrationOtpError.invalid &&
              s.step == RegistrationStep.otp,
        ),
      ],
    );

    blocTest<RegistrationCubit, RegistrationState>(
      'locks out on the 3rd consecutive wrong code',
      build: build,
      seed: () => const RegistrationState(
        phoneInput: '71123456',
        step: RegistrationStep.otp,
        failedAttempts: 2,
      ),
      setUp: () => when(
        () => otp.verifyCode(
          e164Phone: any(named: 'e164Phone'),
          code: any(named: 'code'),
        ),
      ).thenAnswer((_) async => OtpVerifyOutcome.invalidCode),
      act: (c) => c.verifyCode('000000'),
      skip: 1,
      expect: () => [
        predicate<RegistrationState>(
          (s) =>
              s.step == RegistrationStep.lockedOut &&
              s.failedAttempts == 3 &&
              s.lockoutSecondsRemaining == 60,
        ),
      ],
    );

    blocTest<RegistrationCubit, RegistrationState>(
      'verifies the same selected international E.164 identity',
      build: build,
      seed: () => const RegistrationState(
        selectedCountryCode: 'NL',
        phoneInput: '612345678',
        step: RegistrationStep.otp,
      ),
      setUp: () => when(
        () => otp.verifyCode(
          e164Phone: any(named: 'e164Phone'),
          code: any(named: 'code'),
        ),
      ).thenAnswer((_) async => OtpVerifyOutcome.verified),
      act: (cubit) => cubit.verifyCode('1234'),
      verify: (_) {
        verify(
          () => otp.verifyCode(e164Phone: '+31612345678', code: '1234'),
        ).called(1);
      },
    );
  });

  group('resendCode', () {
    blocTest<RegistrationCubit, RegistrationState>(
      'resends the same selected international E.164 identity',
      build: build,
      seed: () => const RegistrationState(
        selectedCountryCode: 'NL',
        phoneInput: '612345678',
        step: RegistrationStep.otp,
      ),
      setUp: () => when(
        () => otp.sendCode(any()),
      ).thenAnswer((_) async => OtpSendOutcome.sent),
      act: (cubit) => cubit.resendCode(),
      verify: (_) {
        verify(() => otp.sendCode('+31612345678')).called(1);
      },
    );
  });

  group('countdowns', () {
    test('resend countdown ticks down to 0 after each emit', () async {
      when(
        () => otp.sendCode(any()),
      ).thenAnswer((_) async => OtpSendOutcome.sent);
      final cubit = build(
        policy: const RegistrationAttemptPolicy(
          resendCooldown: Duration(seconds: 3),
        ),
      );
      cubit.phoneChanged('71123456');
      await cubit.sendCode();
      expect(cubit.state.resendSecondsRemaining, 3);

      ticker.add(DateTime.now());
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.resendSecondsRemaining, 2);

      ticker.add(DateTime.now());
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.resendSecondsRemaining, 1);

      ticker.add(DateTime.now());
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.resendSecondsRemaining, 0);

      await cubit.close();
    });

    test(
      'lockout expiry returns the user to phone entry with attempts reset',
      () async {
        when(
          () => otp.sendCode(any()),
        ).thenAnswer((_) async => OtpSendOutcome.sent);
        when(
          () => otp.verifyCode(
            e164Phone: any(named: 'e164Phone'),
            code: any(named: 'code'),
          ),
        ).thenAnswer((_) async => OtpVerifyOutcome.invalidCode);
        final cubit = build(
          policy: const RegistrationAttemptPolicy(
            lockoutDuration: Duration(seconds: 2),
          ),
        );
        cubit.phoneChanged('71123456');
        await cubit.sendCode();
        await cubit.verifyCode('000000');
        await cubit.verifyCode('000000');
        await cubit.verifyCode('000000'); // triggers lockout
        expect(cubit.state.step, RegistrationStep.lockedOut);
        expect(cubit.state.lockoutSecondsRemaining, 2);

        ticker.add(DateTime.now());
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.lockoutSecondsRemaining, 1);

        ticker.add(DateTime.now());
        await Future<void>.delayed(Duration.zero);
        // Lockout reached 0 → step bounces back to phone and attempts reset.
        expect(cubit.state.step, RegistrationStep.phone);
        expect(cubit.state.failedAttempts, 0);
        expect(cubit.state.lockoutSecondsRemaining, 0);

        await cubit.close();
      },
    );
  });
}
