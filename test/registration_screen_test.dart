import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/theme/jeeb_radii.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/theme/jeeb_shadows.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/features/registration/application/registration_cubit.dart';
import 'package:jeeb_mobile/features/registration/application/registration_state.dart';
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
          .widget<JeebCtaButton>(
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
          .widget<JeebCtaButton>(
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
    final disabled = tester.widget<JeebCtaButton>(
      find.byKey(const Key('registration.sendCode')),
    );
    expect(disabled.isEnabled, isFalse);

    await tester.enterText(
      find.byKey(const Key('registration.phoneField')),
      '71123456',
    );
    await tester.pump();

    final enabled = tester.widget<JeebCtaButton>(
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

    // Branded wordmark hero band — now the full-bleed navy welcome band
    // (redesign 02). `_register_hero` is Maestro-frozen (jm-009, jm-018).
    expect(find.bySemanticsIdentifier('_register_hero'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Jeeb')), findsWidgets);
    // Welcome heading lives inside the band and keeps its key.
    expect(find.byKey(const Key('registration.welcome')), findsOneWidget);
    // "phone — or — social" divider below the phone block.
    expect(find.byKey(const Key('registration.orDivider')), findsOneWidget);
  });

  testWidgets(
      'the live-valid tick appears at a parseable number and goes again below '
      'the 7-digit minimum', (tester) async {
    await tester.pumpWidget(wrapForTest(
      RegistrationScreen(cubit: makeCubit()),
    ));
    await tester.pump();

    // The tick always occupies its slot (an opacity swap, not a conditional
    // insert) so the field row never reflows per keystroke.
    expect(
      find.bySemanticsIdentifier('register_phone_valid_check'),
      findsOneWidget,
    );
    final tick = find.ancestor(
      of: find.byIcon(Icons.check),
      matching: find.byType(Opacity),
    );
    expect(tester.widget<Opacity>(tick.first).opacity, 0);

    await tester.enterText(
      find.byKey(const Key('registration.phoneField')),
      '71123456',
    );
    // ONE frame: M5 R6 moves nothing, so the tick is fully lit immediately.
    await tester.pump();
    expect(tester.widget<Opacity>(tick.first).opacity, 1);

    // Six digits is below `LebanonPhone.minNationalDigitCount` — the tick
    // hides again, agreeing with the now-disabled CTA.
    await tester.enterText(
      find.byKey(const Key('registration.phoneField')),
      '711234',
    );
    await tester.pump();
    expect(tester.widget<Opacity>(tick.first).opacity, 0);
  });

  // M5 B8: the notes give R6 zero animated elements — "does not move:
  // anything ... including the phone field".
  testWidgets('R6 is still: the valid tick does not fade', (tester) async {
    await tester.pumpWidget(wrapForTest(
      RegistrationScreen(cubit: makeCubit()),
    ));
    await tester.pump();

    expect(
      find.ancestor(
        of: find.byIcon(Icons.check),
        matching: find.byType(AnimatedOpacity),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.bySemanticsIdentifier('register_phone_valid_check'),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
  });

  testWidgets('the docked trust note renders below the form', (tester) async {
    await tester.pumpWidget(wrapForTest(
      RegistrationScreen(cubit: makeCubit()),
    ));
    await tester.pump();

    expect(find.bySemanticsIdentifier('register_trust_note'), findsOneWidget);
    // Cash-on-delivery honesty: no card, and the number is only shared with
    // the Jeeber the client actually accepts.
    expect(
      find.text(
        'No card needed. Your number is only shared with the Jeeber you '
        'accept.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'the helper line carries the resting copy and swaps to the invalid-phone '
      'error (the field no longer owns an InputDecoration errorText)',
      (tester) async {
    final cubit = makeCubit();
    await tester.pumpWidget(wrapForTest(
      RegistrationScreen(cubit: cubit),
    ));
    await tester.pump();

    expect(find.bySemanticsIdentifier('register_phone_helper'), findsOneWidget);
    expect(
      find.text('8-digit Lebanese number — we text you a code.'),
      findsOneWidget,
    );

    // Submitting with nothing typed is the cubit's invalid path.
    await cubit.sendCode();
    await tester.pump();

    expect(cubit.state.phoneError, RegistrationPhoneError.invalid);
    expect(find.text('Enter a valid Lebanese phone number.'), findsOneWidget);
    expect(
      find.text('8-digit Lebanese number — we text you a code.'),
      findsNothing,
    );
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

  // MIDNIGHT R6 realignment: the board draws an ORANGE pill, which is
  // `JeebCtaButton.accent`. The in-button spinner (the behaviour this test was
  // really guarding) moved with it — `isLoading`, not a separate widget.
  testWidgets('R6: send-code CTA is the kit ACCENT pill and spins in place',
      (tester) async {
    final cubit = makeCubit();
    await tester.pumpWidget(wrapForTest(RegistrationScreen(cubit: cubit)));
    await tester.pump();

    final finder = find.byKey(const Key('registration.sendCode'));
    expect(finder, findsOneWidget);
    final cta = tester.widget<JeebCtaButton>(finder);
    expect(cta.variant, JeebCtaVariant.accent);
    expect(cta.isLoading, isFalse);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    when(() => otp.sendCode(any())).thenAnswer(
      (_) => Completer<OtpSendOutcome>().future,
    );
    await tester.enterText(
      find.byKey(const Key('registration.phoneField')),
      '71123456',
    );
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();

    expect(tester.widget<JeebCtaButton>(finder).isLoading, isTrue);
    expect(
      find.descendant(of: finder, matching: find.byType(CircularProgressIndicator)),
      findsOneWidget,
    );
  });

  // The tile paints the pill `#D73B00` with the ctaOrange lift; a token
  // re-point that silently reverted to navy would move <5% of the frame and
  // sail past the golden comparator, so the fill is read off the widget.
  testWidgets('R6: the send-code pill actually paints accent orange',
      (tester) async {
    await tester.pumpWidget(wrapForTest(RegistrationScreen(cubit: makeCubit())));
    await tester.enterText(
      find.byKey(const Key('registration.phoneField')),
      '71123456',
    );
    await tester.pump();

    final decoration = tester
        .widget<DecoratedBox>(
          find
              .descendant(
                of: find.byKey(const Key('registration.sendCode')),
                matching: find.byType(DecoratedBox),
              )
              .first,
        )
        .decoration as BoxDecoration;
    expect(decoration.color, JeebColorRoles.midnight().accent);
    expect(decoration.boxShadow, JeebShadows.ctaOrange);
  });

  // R6's field rim is the one orange the phone block spends, at the measured
  // 2px on r14 glass — all three are invisible to a 5%-tolerant golden.
  testWidgets('R6: the phone field is 2px accent-rimmed r14 glass',
      (tester) async {
    await tester.pumpWidget(wrapForTest(RegistrationScreen(cubit: makeCubit())));
    await tester.pump();

    final box = tester.widget<Container>(
      find.byKey(const Key('registration.phoneFieldBox')),
    );
    final decoration = box.decoration! as BoxDecoration;
    final border = decoration.border! as Border;
    expect(border.top.color, JeebColorRoles.midnight().accent);
    expect(border.top.width, 2);
    expect(
      decoration.borderRadius,
      BorderRadius.circular(JeebRadii.md),
    );
    expect(decoration.color, JeebSemanticColors.midnight().glassFill);
  });

  // doc-13 P1: the OMDS input theme injects a fill and per-state borders, so
  // the inner field drew a SECOND rounded box inside the glass one. Nulling
  // `border` alone did not do it — the pass-1 screen shipped believing it had.
  testWidgets('R6: the inner TextField draws no box of its own', (tester) async {
    await tester.pumpWidget(wrapForTest(RegistrationScreen(cubit: makeCubit())));
    await tester.pump();

    final decoration = tester
        .widget<TextField>(find.byKey(const Key('registration.phoneField')))
        .decoration!;
    expect(decoration.filled, isFalse);
    expect(decoration.fillColor, Colors.transparent);
    for (final border in <InputBorder?>[
      decoration.border,
      decoration.enabledBorder,
      decoration.focusedBorder,
      decoration.disabledBorder,
      decoration.errorBorder,
      decoration.focusedErrorBorder,
    ]) {
      expect(border, InputBorder.none);
    }
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
    // Redesign 02 replaces "مرحباً بك في جيب" with the board's neighbourly
    // greeting.
    expect(find.text('أهلاً بك يا جار'), findsOneWidget);
    // The bilingual tagline under it leads with Arabic in the `ar` locale.
    expect(find.text('جيب، مشوارك أسهل · Your errand, made easier'),
        findsOneWidget);
  });

  // The "Super user login plus" picker→sheet placement tests moved with the
}
