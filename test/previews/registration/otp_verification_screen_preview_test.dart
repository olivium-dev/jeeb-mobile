// Render tests for the OtpVerificationScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand.
//
// This screen is a hard case for "does this preview render ITS OWN state?".
// Nine previews sit behind the same app bar, the same doubled title and the
// same subtitle, and the copy does NOT separate them: `Wrong code. Try again.`
// is what both the invalid-code AND the network-failure states render (see
// `_otpErrorCopy`), `Resend code` is mounted in four of them, and the two
// lockouts differ only in a counter nobody draws. So the previews carry a
// caption ([OtpVerificationScreenCaptions], the same device as
// `MutualRatingScreenCaptions`) for `expectedText`, and the groups below assert
// the real state behind each caption — which branch built, whether the attempts
// counter is mounted, whether the CTA is enabled — so a preview wired to the
// wrong fixture fails here instead of passing on its caption alone.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/devtool/catalog/fixtures/otp_verification_screen_fixtures.dart';
import 'package:jeeb_mobile/features/registration/presentation/otp_verification_screen.dart';

import '../preview_test_harness.dart';

/// `phone_otp_input` — the four-cell code entry.
final Finder _otpField = find.byKey(const Key('registration.otpField'));

/// `phone_otp_verify_cta`.
final Finder _verify = find.byKey(const Key('registration.verify'));

/// `phone_otp_resend_cta`, mounted only once the cooldown is spent.
final Finder _resend = find.byKey(const Key('registration.resend'));

/// The `Resend in {n}s` label that stands in for the button while the cooldown
/// runs.
final Finder _countdown = find.byKey(const Key('registration.resendCountdown'));

/// `_AttemptsRemainingLabel`, which renders nothing at zero failed attempts.
final Finder _attempts = find.byKey(const Key('registration.attemptsLeft'));

/// `_LockoutBanner`, which replaces the whole entry column.
final Finder _lockoutBanner =
    find.byKey(const Key('registration.lockoutBanner'));

/// `phone_otp_change_phone_cta`.
final Finder _changePhone = find.byKey(const Key('registration.changePhone'));

/// `phone_otp_back_cta` — the app-bar arrow, which calls `changePhone()`.
final Finder _back = find.byKey(const Key('registration.otpBack'));

/// EN copy, as shipped in `lib/l10n/app_en.arb`.
const String _titleEn = 'Enter the code';
const String _invalidEn = 'Wrong code. Try again.';
const String _expiredEn = 'The code expired. Tap resend to get a new one.';
const String _lockoutTitleEn = 'Too many attempts';

bool _verifyEnabled(WidgetTester tester) =>
    tester.widget<OmdsPrimaryButton>(_verify).isEnabled;

String _verifyLabel(WidgetTester tester) =>
    tester.widget<OmdsPrimaryButton>(_verify).text;

/// Pumps [preview] into a FRESH element tree.
///
/// Two of these previews pumped back to back are identical widget types with no
/// keys, so Flutter reuses the elements — and `BlocProvider.create` runs only on
/// first build, which hands the SECOND preview the FIRST one's cubit and
/// silently asserts the wrong state. Clearing the tree makes every pump a real
/// mount. Only needed inside a test that pumps more than once.
Future<void> _pumpFresh(
  WidgetTester tester,
  Widget Function() preview,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpPreview(tester, preview);
}

void main() {
  setUpAll(() {
    loadPreviewArbs();
    // `OmdsOtpInput` autofocuses its first cell, and a focused `EditableText`
    // reschedules a frame every blink — which `pumpAndSettle` would chase until
    // it timed out. Deterministic cursor stops the blink timer without changing
    // anything the previews are asserting.
    EditableText.debugDeterministicCursor = true;
  });

  tearDownAll(() {
    EditableText.debugDeterministicCursor = false;
  });

  testPreviewsRender(
    'OtpVerificationScreen',
    const <String, Widget Function()>{
      'Code sent · countdown running': otpVerificationScreenCountdownRunning,
      'Resend unlocked': otpVerificationScreenResendReady,
      'Wrong code · first of three': otpVerificationScreenWrongCode,
      'Wrong code · last attempt': otpVerificationScreenLastAttempt,
      'Code expired': otpVerificationScreenExpired,
      'Network failure shown as wrong code': otpVerificationScreenNetworkError,
      'Verify in flight': otpVerificationScreenVerifying,
      'Locked out · three wrong codes': otpVerificationScreenLockedOut,
      'Locked out · gateway 429': otpVerificationScreenRateLimited,
    },
    expectedText: const <String, String>{
      'Code sent · countdown running':
          OtpVerificationScreenCaptions.countdownRunning,
      'Resend unlocked': OtpVerificationScreenCaptions.resendReady,
      'Wrong code · first of three': OtpVerificationScreenCaptions.wrongCode,
      'Wrong code · last attempt': OtpVerificationScreenCaptions.lastAttempt,
      'Code expired': OtpVerificationScreenCaptions.expired,
      'Network failure shown as wrong code':
          OtpVerificationScreenCaptions.networkError,
      'Verify in flight': OtpVerificationScreenCaptions.verifying,
      'Locked out · three wrong codes': OtpVerificationScreenCaptions.lockedOut,
      'Locked out · gateway 429': OtpVerificationScreenCaptions.rateLimited,
    },
  );

  group('OtpVerificationScreen previews · the state behind the caption', () {
    testWidgets('Countdown running — empty cells, cooldown label, no error', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, otpVerificationScreenCountdownRunning);

      expect(_otpField, findsOneWidget);
      // The input length is the live 4-digit gateway contract, sourced from
      // `kCustomerOtpLength` — several doc comments on this screen still say
      // "6-digit".
      expect(tester.widget<OmdsOtpInput>(_otpField).length, 4);
      expect(tester.widget<OmdsOtpInput>(_otpField).hasError, isFalse);
      expect(_countdown, findsOneWidget);
      expect(find.text('Resend in 60s'), findsOneWidget);
      expect(_resend, findsNothing);
      // Nothing has been typed and nothing has failed, so no counter.
      expect(_attempts, findsNothing);
      expect(find.text(_invalidEn), findsNothing);
      // The subtitle is the seeded number, formatted by
      // `LebanonPhone.displayWithPrefix`.
      expect(
        find.text('We sent a 4-digit code to '
            '$otpVerificationScreenDisplayPhone.'),
        findsOneWidget,
      );
    });

    testWidgets('the title is rendered TWICE — app bar and body headline', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, otpVerificationScreenCountdownRunning);

      // `OMDSAppBar(title: l10n.registrationOtpTitle)` and the `headlineSmall`
      // at the top of the scroll column are the same string.
      expect(find.text(_titleEn), findsNWidgets(2));
    });

    testWidgets('the verify CTA can never be enabled from cubit state', (
      WidgetTester tester,
    ) async {
      // `isEnabled` is `!isVerifying && _enteredCode.length == 4`, and
      // `_enteredCode` is `State`-local: it starts empty on every mount, so no
      // seeded/restored state can satisfy the second half.
      await _pumpFresh(tester, otpVerificationScreenCountdownRunning);
      expect(_verifyEnabled(tester), isFalse);
      expect(_verifyLabel(tester), 'Verify');

      await _pumpFresh(tester, otpVerificationScreenVerifying);
      // In flight: the label is the ONLY in-flight signal — no spinner, and
      // the four cells stay mounted and editable.
      expect(_verifyLabel(tester), 'Verifying…');
      expect(_verifyEnabled(tester), isFalse);
      expect(_otpField, findsOneWidget);
    });

    testWidgets('Resend unlocked — the button replaces the countdown', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, otpVerificationScreenResendReady);

      expect(_resend, findsOneWidget);
      expect(find.text('Resend code'), findsOneWidget);
      expect(_countdown, findsNothing);
      expect(_attempts, findsNothing);
    });

    testWidgets('Wrong code — error copy, red cells, counter appears', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, otpVerificationScreenWrongCode);

      expect(find.text(_invalidEn), findsOneWidget);
      expect(tester.widget<OmdsOtpInput>(_otpField).hasError, isTrue);
      expect(_attempts, findsOneWidget);
      expect(find.text('2 attempts remaining'), findsOneWidget);
    });

    testWidgets('Last attempt — the counter reads "1 attempts remaining"', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, otpVerificationScreenLastAttempt);

      // `registrationOtpAttemptsRemaining` has no plural form in either ARB,
      // so the most consequential moment on the screen is ungrammatical.
      expect(find.text('1 attempts remaining'), findsOneWidget);
      expect(find.text('1 attempt remaining'), findsNothing);
    });

    testWidgets('Expired — its own copy, and no attempt was burned', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, otpVerificationScreenExpired);

      expect(find.text(_expiredEn), findsOneWidget);
      expect(find.text(_invalidEn), findsNothing);
      // `OtpVerifyOutcome.expired` does not touch `failedAttempts`.
      expect(_attempts, findsNothing);
      // The copy says "tap resend", so the button had better be mounted.
      expect(_resend, findsOneWidget);
    });

    testWidgets('Network failure is rendered as a WRONG CODE', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, otpVerificationScreenNetworkError);

      // `_otpErrorCopy` collapses `networkError` onto `registrationOtpInvalid`.
      // A user whose verify never left the device is told their code is wrong.
      expect(find.text(_invalidEn), findsOneWidget);
      // …and the cells take the same error border as a genuine wrong code.
      expect(tester.widget<OmdsOtpInput>(_otpField).hasError, isTrue);
      // The only tell is the ABSENCE of the counter: the network branch of
      // `verifyCode` costs no attempt.
      expect(_attempts, findsNothing);
      // No connectivity copy exists to show.
      expect(find.textContaining('connection'), findsNothing);
      expect(find.textContaining('offline'), findsNothing);
    });

    testWidgets('Locked out — the entry column is gone; back is the only exit',
        (WidgetTester tester) async {
      await pumpPreview(tester, otpVerificationScreenLockedOut);

      expect(_lockoutBanner, findsOneWidget);
      expect(find.text(_lockoutTitleEn), findsOneWidget);
      expect(find.text('Try again in 0:45.'), findsOneWidget);
      // Everything inside `if (state.step != lockedOut)` goes with it.
      expect(_otpField, findsNothing);
      expect(_verify, findsNothing);
      expect(_resend, findsNothing);
      expect(_countdown, findsNothing);
      expect(_attempts, findsNothing);
      expect(_changePhone, findsNothing);
      // The app-bar arrow is what is left — and it calls `changePhone()`.
      expect(_back, findsOneWidget);
    });

    testWidgets('the two lockouts are the same picture', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, otpVerificationScreenRateLimited);

      // A 429 is routed into the lockout step "instead of burning an attempt",
      // so this user typed NOTHING wrong and is still told "Too many attempts".
      expect(_lockoutBanner, findsOneWidget);
      expect(find.text(_lockoutTitleEn), findsOneWidget);
      expect(find.text('Try again in 1:00.'), findsOneWidget);
      expect(_otpField, findsNothing);
      expect(_changePhone, findsNothing);
    });

    testWidgets('every OTP-step preview offers the change-phone escape', (
      WidgetTester tester,
    ) async {
      for (final Widget Function() preview in <Widget Function()>[
        otpVerificationScreenCountdownRunning,
        otpVerificationScreenResendReady,
        otpVerificationScreenWrongCode,
        otpVerificationScreenLastAttempt,
        otpVerificationScreenExpired,
        otpVerificationScreenNetworkError,
        otpVerificationScreenVerifying,
      ]) {
        await _pumpFresh(tester, preview);
        expect(_changePhone, findsOneWidget);
        expect(find.text('Change phone number'), findsOneWidget);
      }
    });
  });

  group('OtpVerificationScreen previews · Arabic', () {
    testWidgets('the doubled title and the unpluralized counter are both '
        'localized', (WidgetTester tester) async {
      await pumpPreview(
        tester,
        otpVerificationScreenLastAttempt,
        locale: const Locale('ar'),
      );

      expect(find.text('أدخل الرمز'), findsNWidgets(2));
      // Same single form as EN — wrong for 1 and 2 in a language with a dual.
      expect(find.text('1 محاولات متبقية'), findsOneWidget);
    });

    testWidgets('the lockout banner is localized', (WidgetTester tester) async {
      await pumpPreview(
        tester,
        otpVerificationScreenLockedOut,
        locale: const Locale('ar'),
      );

      expect(_lockoutBanner, findsOneWidget);
      expect(find.text('محاولات كثيرة جدًا'), findsOneWidget);
    });
  });
}
