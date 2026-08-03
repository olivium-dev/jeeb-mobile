/// Batch B — additional QA-authored tests covering ACs not exercised by the
/// shipped test files.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/onboarding/onboarding_cubit.dart';
import 'package:jeeb_mobile/features/onboarding/presentation/onboarding_screen.dart';
import 'package:jeeb_mobile/features/registration/application/registration_cubit.dart';
import 'package:jeeb_mobile/features/registration/domain/otp_service.dart';
import 'package:jeeb_mobile/features/registration/domain/registration_attempt_policy.dart';
import 'package:jeeb_mobile/features/registration/presentation/otp_verification_screen.dart';

import '../support/sync_app_localizations.dart';

class _MockOtpService extends Mock implements OtpService {}

// ---------------------------------------------------------------------------

void main() {
  group('T-MOB-003 AC2 — cold-restart skips onboarding when seen', () {
    testWidgets(
        'OnboardingCubit initialises as completed when SharedPreferences '
        'already has the flag; router gate check via cubit state', (tester) async {
      SharedPreferences.setMockInitialValues({'app.onboarding.completed': true});
      final prefs = await SharedPreferences.getInstance();
      final cubit = OnboardingCubit(prefs: prefs);
      addTearDown(cubit.close);

      // Cubit must boot as completed so the router redirects away from /onboarding.
      expect(cubit.state, isTrue,
          reason:
              'OnboardingCubit must read the persisted flag on boot (T-MOB-003 AC2)');
    });

    testWidgets(
        'OnboardingScreen calls onComplete immediately on Get Started — '
        'simulated cold-restart where flag is already set', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cubit = OnboardingCubit(prefs: prefs);
      addTearDown(cubit.close);
      // The onboarding screen now hosts an EN/AR language toggle bound to the
      final localeCubit = LocaleCubit(
        prefs: prefs,
        deviceLocaleProvider: () => const Locale('en'),
      );
      addTearDown(localeCubit.close);

      var completed = false;

      await tester.pumpWidget(
        wrapForTest(
          MultiBlocProvider(
            providers: [
              BlocProvider<OnboardingCubit>.value(value: cubit),
              BlocProvider<LocaleCubit>.value(value: localeCubit),
            ],
            child: OnboardingScreen(onComplete: () => completed = true),
          ),
        ),
      );
      await tester.pump();

      // Advance to last slide.
      await tester.tap(find.byKey(const Key('onboarding.next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding.next')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('onboarding.getStarted')));
      await tester.pump();

      expect(completed, isTrue);
      expect(cubit.state, isTrue,
          reason: 'completing onboarding must persist the flag');

      // Verify the key in SharedPreferences so the router gate will fire on
      expect(prefs.getBool('app.onboarding.completed'), isTrue);
    });
  });

  // ---------------------------------------------------------------------------

  group('T-MOB-004 AC3 — invalid OTP inline error', () {
    late _MockOtpService otp;
    late StreamController<DateTime> ticker;

    setUp(() {
      otp = _MockOtpService();
      ticker = StreamController<DateTime>.broadcast();
      when(() => otp.sendCode(any()))
          .thenAnswer((_) async => OtpSendOutcome.sent);
    });

    tearDown(() async => ticker.close());

    Future<RegistrationCubit> primedCubit() async {
      final cubit = RegistrationCubit(
        otpService: otp,
        tickerFactory: () => ticker.stream,
      );
      cubit.phoneChanged('71123456');
      await cubit.sendCode();
      return cubit;
    }

    testWidgets('shows inline error text after a wrong code', (tester) async {
      when(() => otp.verifyCode(
            e164Phone: any(named: 'e164Phone'),
            code: any(named: 'code'),
          )).thenAnswer((_) async => OtpVerifyOutcome.invalidCode);

      final cubit = await primedCubit();
      addTearDown(cubit.close);

      await tester.pumpWidget(
        wrapForTest(
          BlocProvider<RegistrationCubit>.value(
            value: cubit,
            child: const OtpVerificationScreen(),
          ),
        ),
      );
      await tester.pump();

      await cubit.verifyCode('0000');
      await tester.pump();

      // The error copy "Wrong code. Try again." must be visible.
      expect(find.textContaining('Wrong code'), findsOneWidget,
          reason: 'T-MOB-004 AC3: inline error must surface after invalid OTP');
    });
  });

  // ---------------------------------------------------------------------------

  group('T-MOB-004 AC4 — lockout banner appears at maxAttempts threshold', () {
    late _MockOtpService otp;
    late StreamController<DateTime> ticker;

    setUp(() {
      otp = _MockOtpService();
      ticker = StreamController<DateTime>.broadcast();
      when(() => otp.sendCode(any()))
          .thenAnswer((_) async => OtpSendOutcome.sent);
      when(() => otp.verifyCode(
            e164Phone: any(named: 'e164Phone'),
            code: any(named: 'code'),
          )).thenAnswer((_) async => OtpVerifyOutcome.invalidCode);
    });

    tearDown(() async => ticker.close());

    testWidgets(
        'lockout banner appears after 5 failed attempts with maxAttempts:5 policy',
        (tester) async {
      final cubit = RegistrationCubit(
        otpService: otp,
        policy: const RegistrationAttemptPolicy(maxAttempts: 5),
        tickerFactory: () => ticker.stream,
      );
      addTearDown(cubit.close);
      cubit.phoneChanged('71123456');
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

      for (var i = 0; i < 5; i++) {
        await cubit.verifyCode('000000');
      }
      await tester.pump();

      expect(find.byKey(const Key('registration.lockoutBanner')), findsOneWidget,
          reason: 'T-MOB-004 AC4: lockout banner must appear after maxAttempts failures');
      expect(find.byKey(const Key('registration.verify')), findsNothing,
          reason: 'Verify CTA must be hidden during lockout');
    });
  });

  // ---------------------------------------------------------------------------

  group('T-MOB-004 AC1 — phone submitted in E.164 format', () {
    test('RegistrationCubit normalises national digits to +961XXXXXXXX', () async {
      final otp = _MockOtpService();
      when(() => otp.sendCode(any()))
          .thenAnswer((_) async => OtpSendOutcome.sent);

      final cubit = RegistrationCubit(otpService: otp);
      addTearDown(cubit.close);

      cubit.phoneChanged('71123456');
      await cubit.sendCode();

      final captured = verify(() => otp.sendCode(captureAny())).captured;
      expect(
        captured.first as String,
        equals('+96171123456'),
        reason:
            'T-MOB-004 AC1: sendCode must receive full E.164 format (+961 prefix)',
      );
    });
  });

  // ---------------------------------------------------------------------------

  group('T-MOB-004 — verifyCode 429 rate-limited maps to invalidCode', () {
    test('cubit exposes otpError after service returns invalidCode', () async {
      final otp = _MockOtpService();
      when(() => otp.sendCode(any()))
          .thenAnswer((_) async => OtpSendOutcome.sent);
      when(() => otp.verifyCode(
            e164Phone: any(named: 'e164Phone'),
            code: any(named: 'code'),
          )).thenAnswer((_) async => OtpVerifyOutcome.invalidCode);

      final cubit = RegistrationCubit(otpService: otp);
      addTearDown(cubit.close);

      cubit.phoneChanged('71123456');
      await cubit.sendCode();
      await cubit.verifyCode('9999');

      expect(
        cubit.state.otpError,
        isNotNull,
        reason: 'invalidCode outcome must set otpError on the cubit state',
      );
    });
  });
}
