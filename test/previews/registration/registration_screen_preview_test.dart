// Render tests for the RegistrationScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand.
//
// Seven of the eight states are pinned on REAL rendered content — the digits in
// the phone field — which is why the shared fixtures give every state a
// distinct number. `Idle · empty field` is the exception and gets its own
// group: its only distinguishing copy is the "Phone number" hint, and Flutter
// keeps the hint mounted at zero opacity in every other state
// (`InputDecorator` builds it under `maintainHintSize`, which defaults to
// true), so pinning it would not discriminate. That state is proved by its
// empty controller and its dead CTA instead.
//
// `Send in flight` is also handled separately: `OmdsLoadingButton(isLoading:
// true)` renders an indeterminate `CircularProgressIndicator`, and
// `pumpAndSettle` — which `pumpPreview` calls — never returns while one is on
// screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/devtool/catalog/fixtures/registration_screen_fixtures.dart';
import 'package:jeeb_mobile/features/registration/domain/lebanon_phone.dart';
import 'package:jeeb_mobile/features/registration/presentation/registration_screen.dart';

import '../preview_test_harness.dart';

/// The one line of error copy the screen has — reused for all three
/// `RegistrationPhoneError` values, which is the defect the previews exist to
/// show. Verbatim from `lib/l10n/app_en.arb`.
const String _invalidCopy = 'Enter a valid Lebanese phone number.';

/// `registrationPhoneHint`, verbatim from `lib/l10n/app_en.arb`.
const String _hint = 'Phone number';

const Key _fieldKey = Key('registration.phoneField');
const Key _ctaKey = Key('registration.sendCode');
const Key _prefixKey = Key('registration.phonePrefix');

/// [pumpPreview] twice in ONE test is a trap: every preview builds the same
/// element shape, so Flutter would update in place. The previews carry distinct
/// `ValueKey`s to defeat that, but tearing the tree down in between is the
/// belt-and-braces version and costs nothing.
Future<void> pumpPreviewFresh(
  WidgetTester tester,
  Widget Function() preview,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpPreview(tester, preview);
}

TextField _field(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(_fieldKey));

OmdsLoadingButton _cta(WidgetTester tester) =>
    tester.widget<OmdsLoadingButton>(find.byKey(_ctaKey));

void main() {
  setUpAll(loadPreviewArbs);

  // Every preview except the two with their own groups below.
  testPreviewsRender(
    'RegistrationScreen',
    const <String, Widget Function()>{
      'Typing · below the 7-digit minimum': registrationScreenTyping,
      'Valid number · CTA live': registrationScreenReady,
      'Rejected locally · too short': registrationScreenInvalidNumber,
      'Send failed · gateway unreachable': registrationScreenNetworkError,
      'Send refused · gateway 429': registrationScreenRateLimited,
      'Pasted +961 block · doubled dial code': registrationScreenPasted,
    },
    // The digits each state carries, straight from the shared fixtures — the
    // catalog and the canvas cannot pin different numbers from the ones they
    // render.
    expectedText: const <String, String>{
      'Typing · below the 7-digit minimum': registrationScreenTypingPhone,
      'Valid number · CTA live': registrationScreenReadyPhone,
      'Rejected locally · too short': registrationScreenInvalidPhone,
      'Send failed · gateway unreachable': registrationScreenNetworkErrorPhone,
      'Send refused · gateway 429': registrationScreenRateLimitedPhone,
      'Pasted +961 block · doubled dial code': registrationScreenPastedPhone,
    },
  );

  // `Idle` renders an EMPTY field, so it has no digits to pin. Same three
  // assertions the shared suite makes — builds in EN, builds in AR, renders its
  // OWN state — with the third done by state rather than by copy.
  group('RegistrationScreen previews · Idle', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Idle · ${locale.languageCode}', (WidgetTester tester) async {
        await pumpPreview(tester, registrationScreenIdle, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Idle renders its own state', (WidgetTester tester) async {
      await pumpPreview(tester, registrationScreenIdle);

      // The empty field is the state. No other preview in this file has one.
      expect(_field(tester).controller!.text, isEmpty);
      // The hint is therefore the visible copy…
      expect(find.text(_hint), findsOneWidget);
      // …and the CTA is dead, with nothing red anywhere.
      expect(_cta(tester).isEnabled, isFalse);
      expect(_cta(tester).isLoading, isFalse);
      expect(find.text(_invalidCopy), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  // `isSendingCode` swaps the CTA label for `OmdsButtonLoading`, i.e. an
  // indeterminate `CircularProgressIndicator`. `pumpAndSettle` never returns
  // while one is mounted, so this preview gets the shared suite's three
  // assertions driven by fixed pumps instead.
  group('RegistrationScreen previews · Send in flight', () {
    Future<void> pumpSending(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(previewCanvas(registrationScreenSending, locale));
      await tester.pump(); // localizations resolve → the screen is built
      await tester.pump(const Duration(milliseconds: 300)); // switcher settles
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Send in flight · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpSending(tester, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Send in flight renders its own state', (
      WidgetTester tester,
    ) async {
      await pumpSending(tester);

      // Its own distinct number is on screen…
      expect(find.text(registrationScreenSendingPhone), findsOneWidget);
      // …the CTA label has been replaced by a spinner…
      expect(find.text('Send code'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(_cta(tester).isLoading, isTrue);
      // …and the field is locked, so the number cannot be edited out from under
      // a request that is already carrying it. That pair is true of no other
      // preview here.
      expect(_field(tester).enabled, isFalse);
      expect(find.text(_invalidCopy), findsNothing);
    });
  });

  group('RegistrationScreen preview specifics', () {
    testWidgets(
        'JEEB-56: two VALID numbers are told they are invalid — the send-failure '
        'states reuse the local-validation copy', (WidgetTester tester) async {
      // `_phoneErrorCopy` maps networkError and rateLimited onto
      // `registrationPhoneInvalid`. The consequence is not cosmetic: the only
      // remedy the copy suggests is "fix your number", and for these two states
      // the number is already correct, so following the instruction cannot
      // clear the error.
      for (final MapEntry<Widget Function(), String> entry
          in <Widget Function(), String>{
        registrationScreenNetworkError: registrationScreenNetworkErrorPhone,
        registrationScreenRateLimited: registrationScreenRateLimitedPhone,
      }.entries) {
        await pumpPreviewFresh(tester, entry.key);

        expect(
          LebanonPhone.tryParse(entry.value),
          isNotNull,
          reason: '${entry.value} must be a VALID number for this to bite',
        );
        expect(find.text(entry.value), findsOneWidget);
        expect(
          find.text(_invalidCopy),
          findsOneWidget,
          reason: '${entry.value} is valid, yet the screen calls it invalid',
        );
      }

      // NEGATIVE control: the one state the copy is actually written for.
      await pumpPreviewFresh(tester, registrationScreenInvalidNumber);
      expect(LebanonPhone.tryParse(registrationScreenInvalidPhone), isNull);
      expect(find.text(_invalidCopy), findsOneWidget);
    });

    testWidgets('a 429 leaves the field and the CTA live — nothing throttles '
        'an immediate retry', (WidgetTester tester) async {
      await pumpPreview(tester, registrationScreenRateLimited);

      // The screen offers exactly one action after a rate-limit, and it is
      // "send again". `sendCode` has no client-side cooldown; compare the
      // sibling OTP screen, which routes its own 429 into a lockout step.
      expect(_field(tester).enabled, isTrue);
      expect(_cta(tester).isEnabled, isTrue);
      expect(_cta(tester).isLoading, isFalse);
    });

    testWidgets(
        'a pasted +961 block is drawn NEXT TO the permanent +961 prefix — the '
        'dial code renders twice', (WidgetTester tester) async {
      await pumpPreview(tester, registrationScreenPasted);

      // `_PhoneField` documents "The TextField only ever receives the 8
      // national digits; the prefix is decorative". Both of these finding one
      // widget is that contract failing: the decorative prefix AND a pasted
      // dial code are on screen together.
      expect(find.byKey(_prefixKey), findsOneWidget);
      expect(find.text(LebanonPhone.dialCode), findsOneWidget);
      expect(find.text(registrationScreenPastedPhone), findsOneWidget);
      expect(registrationScreenPastedPhone.startsWith(LebanonPhone.dialCode),
          isTrue);

      // The request itself is still correct — normalisation happens on Send —
      // so this is a display defect, not a delivery one.
      expect(
        LebanonPhone.tryParse(registrationScreenPastedPhone)?.digits,
        registrationScreenReadyPhone,
      );
      // …and the CTA is live, so the user can send despite the odd-looking row.
      expect(_cta(tester).isEnabled, isTrue);
    });

    testWidgets('typing below the minimum disables the CTA WITHOUT calling the '
        'number wrong', (WidgetTester tester) async {
      await pumpPreview(tester, registrationScreenTyping);

      // The distinction from `Rejected locally · too short`: both fields are
      // unparseable, but only the submitted one is red. `phoneChanged` clears
      // `phoneError` on every keystroke, which is what keeps the screen from
      // yelling at a half-typed number.
      expect(LebanonPhone.tryParse(registrationScreenTypingPhone), isNull);
      expect(_cta(tester).isEnabled, isFalse);
      expect(find.text(_invalidCopy), findsNothing);

      // The same six digits after a Send tap DO go red — same field contents,
      // opposite treatment.
      await pumpPreviewFresh(tester, registrationScreenInvalidNumber);
      expect(_cta(tester).isEnabled, isFalse);
      expect(find.text(_invalidCopy), findsOneWidget);
    });

    testWidgets('the happy path is the only card with a live, idle CTA', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, registrationScreenReady);

      expect(_cta(tester).isEnabled, isTrue);
      expect(_cta(tester).isLoading, isFalse);
      expect(_field(tester).enabled, isTrue);
      expect(find.text(_invalidCopy), findsNothing);
      expect(find.text('Send code'), findsOneWidget);
    });

    testWidgets('every preview mounts the whole composition, not a fragment', (
      WidgetTester tester,
    ) async {
      // A screen preview that quietly lost its hero or its social column would
      // still satisfy every per-state pin above, because those all live on the
      // phone field.
      for (final Widget Function() preview in <Widget Function()>[
        registrationScreenIdle,
        registrationScreenTyping,
        registrationScreenReady,
        registrationScreenInvalidNumber,
        registrationScreenNetworkError,
        registrationScreenRateLimited,
        registrationScreenPasted,
      ]) {
        await pumpPreviewFresh(tester, preview);

        expect(find.bySemanticsIdentifier('registration_root'), findsOneWidget);
        expect(find.byKey(const Key('registration.welcome')), findsOneWidget);
        // D4: exactly ONE "or" divider — the social section must not render a
        // second one.
        expect(find.byKey(const Key('registration.orDivider')), findsOneWidget);
        expect(find.text('or'), findsOneWidget);
        expect(
          find.byKey(const Key('registration.googleSignIn')),
          findsOneWidget,
        );
        expect(find.byKey(_fieldKey), findsOneWidget);
        expect(find.byKey(_ctaKey), findsOneWidget);
      }
    });
  });
}
