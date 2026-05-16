import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/registration/application/registration_cubit.dart';
import 'package:jeeb_mobile/features/registration/domain/lebanon_phone.dart';
import 'package:jeeb_mobile/features/registration/domain/otp_service.dart';
import 'package:jeeb_mobile/features/registration/presentation/registration_screen.dart';

import 'support/sync_app_localizations.dart';

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

  RegistrationCubit makeCubit() => RegistrationCubit(
        otpService: otp,
        tickerFactory: () => ticker.stream,
      );

  testWidgets('phone screen renders the fixed +961 prefix', (tester) async {
    await tester.pumpWidget(wrapForTest(
      RegistrationScreen(cubit: makeCubit()),
    ));
    expect(find.byKey(const Key('registration.phonePrefix')), findsOneWidget);
    expect(find.text(LebanonPhone.dialCode), findsOneWidget);
  });

  testWidgets(
      'phone field strips +961 / 0 / separators when user pastes a number',
      (tester) async {
    final cubit = makeCubit();
    await tester.pumpWidget(wrapForTest(
      RegistrationScreen(cubit: cubit),
    ));
    await tester.enterText(
      find.byKey(const Key('registration.phoneField')),
      '+961 71-123 456',
    );
    await tester.pump();
    expect(cubit.state.phoneInput, '71123456');
    expect(cubit.state.isPhoneReady, isTrue);
  });

  testWidgets('Send code is disabled until 8 digits are typed', (tester) async {
    await tester.pumpWidget(wrapForTest(
      RegistrationScreen(cubit: makeCubit()),
    ));
    final disabled = tester.widget<OmdsPrimaryButton>(
      find.byKey(const Key('registration.sendCode')),
    );
    expect(disabled.isEnabled, isFalse);

    await tester.enterText(
      find.byKey(const Key('registration.phoneField')),
      '71123456',
    );
    await tester.pump();

    final enabled = tester.widget<OmdsPrimaryButton>(
      find.byKey(const Key('registration.sendCode')),
    );
    expect(enabled.isEnabled, isTrue);
  });

  testWidgets('tapping Send code navigates to the OTP screen', (tester) async {
    when(() => otp.sendCode(any()))
        .thenAnswer((_) async => OtpSendOutcome.sent);
    await tester.pumpWidget(wrapForTest(
      RegistrationScreen(cubit: makeCubit()),
    ));

    await tester.enterText(
      find.byKey(const Key('registration.phoneField')),
      '71123456',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('registration.sendCode')));
    await tester.pumpAndSettle();

    // OTP screen is now on top — its OTP-field key is the unambiguous
    // anchor.
    expect(find.byKey(const Key('registration.otpField')), findsOneWidget);
    expect(find.byKey(const Key('registration.verify')), findsOneWidget);
    verify(() => otp.sendCode('+96171123456')).called(1);
  });
}
