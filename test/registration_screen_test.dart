import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
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

  testWidgets(
      'REGRESSION (Maestro P0): typing then erasing digits keeps the phone '
      'value intact, so 8 valid digits stay parseable and Send code stays '
      'enabled (no state↔controller corruption)', (tester) async {
    // The on-device defect: the listener mirrored the cubit's *normalised*
    when(() => otp.sendCode(any()))
        .thenAnswer((_) async => OtpSendOutcome.sent);
    final cubit = makeCubit();
    await tester.pumpWidget(wrapForTest(
      RegistrationScreen(cubit: cubit),
    ));

    final field = find.byKey(const Key('registration.phoneField'));

    // 1) Type exactly 8 valid digits — controller and state must agree, and the
    await tester.enterText(field, '71123456');
    await tester.pump();
    expect(cubit.state.phoneInput, '71123456');
    expect(cubit.state.isPhoneReady, isTrue);
    expect(
      tester.widget<TextField>(field).controller!.text,
      '71123456',
      reason: 'the field must show the full 8 digits the user typed',
    );

    // 2) Erase down to 6 digits (a single contiguous edit, never a
    await tester.enterText(field, '711234');
    await tester.pump();
    expect(cubit.state.phoneInput, '711234');
    expect(cubit.state.isPhoneReady, isFalse);
    expect(
      tester
          .widget<OmdsLoadingButton>(
            find.byKey(const Key('registration.sendCode')),
          )
          .isEnabled,
      isFalse,
    );

    // 3) Re-type the 8th digit → back to a valid 8-digit number. The value is
    await tester.enterText(field, '71123456');
    await tester.pump();
    expect(cubit.state.phoneInput, '71123456');
    expect(cubit.state.isPhoneReady, isTrue);
    expect(
      tester
          .widget<OmdsLoadingButton>(
            find.byKey(const Key('registration.sendCode')),
          )
          .isEnabled,
      isTrue,
    );

    await tester.tap(find.byKey(const Key('registration.sendCode')));
    await tester.pump();
    // The OTP request actually goes out with the correct E.164 number — the
    verify(() => otp.sendCode('+96171123456')).called(1);
  });

  testWidgets(
      'REGRESSION (Maestro P0): typing a 9th digit then erasing the visible '
      'trailing digit still recovers a sendable number', (tester) async {
    // Pre-fix, typing a 9th digit front-truncated the value to the first 8 and
    when(() => otp.sendCode(any()))
        .thenAnswer((_) async => OtpSendOutcome.sent);
    final cubit = makeCubit();
    await tester.pumpWidget(wrapForTest(
      RegistrationScreen(cubit: cubit),
    ));

    final field = find.byKey(const Key('registration.phoneField'));
    await tester.enterText(field, '711234567'); // 9 digits typed
    await tester.pump();

    // Erase the actual trailing character the user sees in the field.
    final visible = tester.widget<TextField>(field).controller!.text;
    await tester.enterText(field, visible.substring(0, visible.length - 1));
    await tester.pump();

    expect(cubit.state.phoneInput, '71123456');
    expect(cubit.state.isPhoneReady, isTrue);
  });

  testWidgets(
      'REGRESSION (run-2 on-device P0): Send validates+sends the field\'s '
      'CURRENT text, not a stale cubit phoneInput (submit-path divergence fix)',
      (tester) async {
    // On-device defect: "Send code" enabled off a fresh rebuild (which reflects
    when(() => otp.sendCode(any()))
        .thenAnswer((_) async => OtpSendOutcome.sent);
    final cubit = makeCubit();
    await tester.pumpWidget(wrapForTest(
      RegistrationScreen(cubit: cubit),
    ));
    await tester.pump();

    final field = find.byKey(const Key('registration.phoneField'));
    final controller = tester.widget<TextField>(field).controller!;

    // Cubit has a valid (so the button is ENABLED) but STALE number...
    cubit.phoneChanged('71000000');
    await tester.pump();
    expect(cubit.state.isPhoneReady, isTrue,
        reason: 'precondition: button is enabled (stale value is still valid)');

    // ...while the field/display holds the DIFFERENT number the user last typed,
    controller.text = '71123456';
    await tester.pump();
    expect(controller.text, '71123456');
    expect(cubit.state.phoneInput, '71000000',
        reason: 'precondition: cubit phoneInput is stale, diverged from field');

    // Tap Send. Pre-fix it would have sent the STALE +96171000000 (or, when the
    await tester.tap(find.byKey(const Key('registration.sendCode')));
    await tester.pump();

    expect(cubit.state.phoneInput, '71123456');
    expect(cubit.state.phoneError, isNull);
    verify(() => otp.sendCode('+96171123456')).called(1);
    verifyNever(() => otp.sendCode('+96171000000'));
  });

  testWidgets(
      'BUG-1 (customer-spine P0): a phone value present in the rendered field '
      'but NOT mirrored into cubit state still sends — Send reads the live '
      'controller text, not a stale state.phoneInput', (tester) async {
    // The on-device divergence: the field owns its text while the user types
    when(() => otp.sendCode(any()))
        .thenAnswer((_) async => OtpSendOutcome.sent);
    final cubit = makeCubit();
    await tester.pumpWidget(wrapForTest(
      RegistrationScreen(cubit: cubit),
    ));

    final field = find.byKey(const Key('registration.phoneField'));

    // 1) Type a first valid number normally so state + field agree and the CTA
    await tester.enterText(field, '71123456');
    await tester.pump();
    expect(cubit.state.phoneInput, '71123456');

    final controller = tester.widget<TextField>(field).controller!;
    controller.text = '+9613000002';

    expect(
      cubit.state.phoneInput,
      '71123456',
      reason: 'reproduces the divergence: state lags the rendered field',
    );

    // The CTA was enabled at the last build; its onTap closure reads the LIVE
    await tester.tap(find.byKey(const Key('registration.sendCode')));
    await tester.pump();

    verify(() => otp.sendCode('+9613000002')).called(1);
    verifyNever(() => otp.sendCode('+96171123456'));
    expect(cubit.state.phoneError, isNull,
        reason: 'no invalid-phone error — the field is valid');
  });

  testWidgets('Send code is disabled until 8 digits are typed', (tester) async {
    await tester.pumpWidget(wrapForTest(
      RegistrationScreen(cubit: makeCubit()),
    ));
    final disabled = tester.widget<OmdsLoadingButton>(
      find.byKey(const Key('registration.sendCode')),
    );
    expect(disabled.isEnabled, isFalse);

    await tester.enterText(
      find.byKey(const Key('registration.phoneField')),
      '71123456',
    );
    await tester.pump();

    final enabled = tester.widget<OmdsLoadingButton>(
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
    expect(find.byKey(const Key('registration.otpField')), findsOneWidget);
    expect(find.byKey(const Key('registration.verify')), findsOneWidget);
    verify(() => otp.sendCode('+96171123456')).called(1);
  });

  testWidgets(
      'super-login entry points were RELOCATED to the login screen — the '
      'registration screen no longer mounts them (see login_screen_test.dart)',
      (tester) async {
    await tester.pumpWidget(wrapForTest(
      RegistrationScreen(cubit: makeCubit()),
    ));
    await tester.pump();

    // P1 MOVE: the two super-login affordances now live on the LOGIN screen.
    expect(kDebugMode, isTrue);
    expect(find.byKey(const Key('registration.superLogin')), findsNothing);
    expect(find.byKey(const Key('registration.superLoginPlus')), findsNothing);
    expect(find.bySemanticsIdentifier('_super_login_link'), findsNothing);
    expect(find.bySemanticsIdentifier('super_login_plus_button'), findsNothing);
  });

  testWidgets(
      'FR-LOGIN: renders the branded hero + welcome heading + or divider '
      '(Rahma/Salehly parity)', (tester) async {
    await tester.pumpWidget(wrapForTest(
      RegistrationScreen(cubit: makeCubit()),
    ));
    await tester.pump();

    // Branded wordmark hero band (interim register hero, FR-P1-3).
    expect(find.bySemanticsLabel(RegExp('Jeeb')), findsWidgets);
    // Welcome heading promoted above the form.
    expect(find.byKey(const Key('registration.welcome')), findsOneWidget);
    // "social — or — phone" divider between social and the phone block.
    expect(find.byKey(const Key('registration.orDivider')), findsOneWidget);
  });

  testWidgets(
      'D4: exactly ONE "or" divider renders (no duplicate between Google '
      'and the phone field)', (tester) async {
    await tester.pumpWidget(wrapForTest(
      RegistrationScreen(cubit: makeCubit()),
    ));
    await tester.pump();

    // The screen owns a single keyed divider. The social section must NOT
    expect(find.byKey(const Key('registration.orDivider')), findsOneWidget);
    // The divider label ("or", `registrationSocialDivider`) must appear exactly
    expect(find.text('or'), findsOneWidget);
  });

  testWidgets('FR-LOGIN: CTA is an OmdsLoadingButton (in-button spinner)',
      (tester) async {
    await tester.pumpWidget(wrapForTest(
      RegistrationScreen(cubit: makeCubit()),
    ));
    await tester.pump();
    expect(
      find.byKey(const Key('registration.sendCode')),
      findsOneWidget,
    );
    expect(
      tester.widget(find.byKey(const Key('registration.sendCode'))),
      isA<OmdsLoadingButton>(),
    );
  });

  testWidgets('FR-LOGIN: register screen lays out RTL under Locale(ar)',
      (tester) async {
    await tester.pumpWidget(wrapForTest(
      RegistrationScreen(cubit: makeCubit()),
      locale: const Locale('ar'),
    ));
    await tester.pump();

    final dir = Directionality.of(
      tester.element(find.byKey(const Key('registration.welcome'))),
    );
    expect(dir, TextDirection.rtl);
    // The Arabic welcome copy renders (value != key, parity-test backed).
    expect(find.text('مرحباً بك في جيب'), findsOneWidget);
  });

  // The "Super user login plus" picker→sheet placement tests moved with the
}
