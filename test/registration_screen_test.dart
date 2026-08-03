import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omds/omds.dart';

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
    // phoneInput back into the field on every keystroke. Typing a 9th digit
    // made `normalise` front-truncate to the first 8 and overwrite the field,
    // so erasing the (now-wrong) trailing digit dropped a valid one — the field
    // stuck below 8 digits, `LebanonPhone.tryParse` returned null, and
    // `sendCode()` bailed at its guard. No OTP was ever requested → login
    // impossible on-device.
    when(() => otp.sendCode(any()))
        .thenAnswer((_) async => OtpSendOutcome.sent);
    final cubit = makeCubit();
    await tester.pumpWidget(wrapForTest(
      RegistrationScreen(cubit: cubit),
    ));

    final field = find.byKey(const Key('registration.phoneField'));

    // 1) Type exactly 8 valid digits — controller and state must agree, and the
    // field must hold all 8 (no per-keystroke overwrite dropping characters).
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
    // corrupted/reordered value). Send code disables because 6 < the 7-digit
    // minimum (a Lebanese national number is 7 or 8 digits).
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
    // NOT corrupted, Send code re-enables, and tapping it actually fires the
    // OTP request (the path that was dead on-device).
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
    // exact step that never happened with the corrupted value.
    verify(() => otp.sendCode('+96171123456')).called(1);
  });

  testWidgets(
      'REGRESSION (Maestro P0): typing a 9th digit then erasing the visible '
      'trailing digit still recovers a sendable number', (tester) async {
    // Pre-fix, typing a 9th digit front-truncated the value to the first 8 and
    // overwrote the field; erasing the visibly-trailing digit then dropped a
    // VALID digit, leaving 7 — unrecoverable without clearing the field. This
    // asserts the field now holds what the user typed so a normal erase
    // recovers a parseable 8-digit number.
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
    // the field/controller), but `state.phoneInput` could lag the final
    // committed keystroke (Android IME composing/autocorrect finalisation does
    // not always re-fire `onChanged` with the last value). So the button looked
    // valid yet `sendCode()`'s `tryParse(state.phoneInput)` guard saw a stale
    // value, flipped the field red, and sent NOTHING — login impossible
    // on-device. The fix re-commits the controller text into the cubit at tap
    // time, so the value Send validates == the value the user sees/typed.
    //
    // Faithful model of the divergence while keeping the button enabled (the
    // on-device symptom): the cubit holds a VALID-but-STALE 8-digit number
    // (button enabled) while the controller/display holds a DIFFERENT, current
    // 8-digit number (what the user actually typed last). Send must use the
    // CONTROLLER's number — proving the field is the source of truth at submit.
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
    // set WITHOUT routing through `onChanged` (the on-device lag).
    controller.text = '71123456';
    await tester.pump();
    expect(controller.text, '71123456');
    expect(cubit.state.phoneInput, '71000000',
        reason: 'precondition: cubit phoneInput is stale, diverged from field');

    // Tap Send. Pre-fix it would have sent the STALE +96171000000 (or, when the
    // stale value was short, bailed entirely). Post-fix it commits the field
    // first and sends the CURRENT +96171123456 — the field is the one truth.
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
    // (PR #45 stopped mirroring the normalised value back). Any path that sets
    // the controller text WITHOUT routing through `onChanged`/`phoneChanged`
    // (programmatic seed, platform autofill, certain paste paths) leaves
    // `state.phoneInput` empty while the field shows a valid number. The old
    // `sendCode()` validated the empty `state.phoneInput`, flipped the field red
    // and emitted ZERO OTP requests. With the fix, Send reads the rendered
    // controller text, so a valid rendered number sends.
    when(() => otp.sendCode(any()))
        .thenAnswer((_) async => OtpSendOutcome.sent);
    final cubit = makeCubit();
    await tester.pumpWidget(wrapForTest(
      RegistrationScreen(cubit: cubit),
    ));

    final field = find.byKey(const Key('registration.phoneField'));

    // 1) Type a first valid number normally so state + field agree and the CTA
    // is live.
    await tester.enterText(field, '71123456');
    await tester.pump();
    expect(cubit.state.phoneInput, '71123456');

    // 2) Now a DIFFERENT valid value lands in the field WITHOUT firing onChanged
    // (platform autofill / programmatic seed): mutate ONLY the controller. No
    // rebuild, no `phoneChanged` — so the cubit's `phoneInput` is now STALE
    // relative to the rendered field. This is the exact divergence that, with
    // the old `sendCode()` (which read `state.phoneInput`), would either send
    // the WRONG number or — when state was empty — flip the field red and emit
    // zero OTP rows.
    final controller = tester.widget<TextField>(field).controller!;
    controller.text = '+9613000002';

    expect(
      cubit.state.phoneInput,
      '71123456',
      reason: 'reproduces the divergence: state lags the rendered field',
    );

    // The CTA was enabled at the last build; its onTap closure reads the LIVE
    // controller text. Tapping must fire the OTP request for the number the user
    // ACTUALLY sees (`3000002`), not the stale state value.
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
    // anchor.
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
    // `flutter test` runs under kDebugMode=true, yet neither link is present
    // here — proving the MOVE removed them from registration (no duplicate).
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
      'the live-valid tick fades in at a parseable number and back out below '
      'the 7-digit minimum', (tester) async {
    await tester.pumpWidget(wrapForTest(
      RegistrationScreen(cubit: makeCubit()),
    ));
    await tester.pump();

    // The tick always occupies its slot (AnimatedOpacity, not a conditional
    // insert) so the field row never reflows per keystroke.
    expect(
      find.bySemanticsIdentifier('register_phone_valid_check'),
      findsOneWidget,
    );
    final tick = find.ancestor(
      of: find.byIcon(Icons.check),
      matching: find.byType(AnimatedOpacity),
    );
    expect(tester.widget<AnimatedOpacity>(tick).opacity, 0);

    await tester.enterText(
      find.byKey(const Key('registration.phoneField')),
      '71123456',
    );
    await tester.pump();
    expect(tester.widget<AnimatedOpacity>(tick).opacity, 1);

    // Six digits is below `LebanonPhone.minNationalDigitCount` — the tick
    // hides again, agreeing with the now-disabled CTA.
    await tester.enterText(
      find.byKey(const Key('registration.phoneField')),
      '711234',
    );
    await tester.pump();
    expect(tester.widget<AnimatedOpacity>(tick).opacity, 0);
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
    // render its own — that produced the two `content-desc="or"` nodes QA saw.
    expect(find.byKey(const Key('registration.orDivider')), findsOneWidget);
    // The divider label ("or", `registrationSocialDivider`) must appear exactly
    // once — this is the literal QA matched (`content-desc="or"`).
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
    // Redesign 02 replaces "مرحباً بك في جيب" with the board's neighbourly
    // greeting.
    expect(find.text('أهلاً بك يا جار'), findsOneWidget);
    // The bilingual tagline under it leads with Arabic in the `ar` locale.
    expect(find.text('جيب، مشوارك أسهل · Your errand, made easier'),
        findsOneWidget);
  });

  // The "Super user login plus" picker→sheet placement tests moved with the
  // feature to test/login_screen_test.dart (P1 MOVE).
}
