// Render tests for the KycIdentityStep previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently.
// All six previews are the SAME widget over the same cubit, told apart only by
// the seeded state — so every one of them pins a DISTINCT string. A suite that
// only asked "did something render?" would pass on six copies of the cold-entry
// form, which is the exact failure this project has already shipped once.
//
// The middle groups are not preview hygiene: they pin the JEBV4-295 submit gate
// (selfie AND id number, and nothing else), the per-id-type field contract, and
// the two inline rejection surfaces this widget owns. The last group is what the
// previews exposed — the `kyc_scroll_hint` pill has no way to shorten its own
// label, so the only thing it can do when it runs out of room is clip.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/kyc/domain/kyc_submission.dart';
import 'package:jeeb_mobile/features/kyc/presentation/widgets/kyc_identity_step.dart';

import '../preview_test_harness.dart';

/// Exact ARB copy, so a reworded string breaks the test instead of silently
/// unpinning the preview.
const String _scrollHint = 'Scroll for selfie';
const String _idNumberRejected =
    'This ID number was not accepted. Check it and try again.';
const String _idTypeInvalid = 'Select a supported ID type';
const String _nationalIdLabel = 'National ID number';
const String _passportLabel = 'Passport number';
const String _residencyLabel = 'Residency permit number';
const String _nationalIdHint = 'Enter the 12 digits on your national ID';
const String _documentHint = 'Enter your document number';
const String _idNumberRequired = 'ID number is required';
const String _idNumberInvalid = 'Enter a valid 12-digit national ID number';
const String _submitCta = 'Submit for review';

/// The seeded id numbers, one per preview, which is what makes each preview
/// identifiable from its rendering alone.
const String _selfieMissingNumber = '112233445566';
const String _readyNumber = '990011223344';
const String _rejectedNumber = '123456789012';
const String _passportNumber = 'AB1234567890123456789012';

/// Pumps a preview into the real phone body box the previews declare
/// (390 x 670) at [textScale], instead of into the 800 x 600 default test
/// surface. The width is the whole point: at 800 dp this step has 440 dp of room
/// it never has on a phone.
Future<void> _pumpInPreviewBox(
  WidgetTester tester,
  Widget Function() preview, {
  required double textScale,
  Size box = const Size(390, 670),
  Locale locale = const Locale('en'),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = box;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: previewCanvas(preview, locale),
    ),
  );
  await tester.pumpAndSettle();
}

/// How many pixels a captured layout error overflowed by, or 0 when [error] is
/// not an overflow at all. Read from the message rather than pinned as an exact
/// constant: the fact under test is "this does not fit", and an exact pixel
/// count would break on a font metric change without meaning anything.
int _overflowPixels(Object? error) {
  if (error == null) return 0;
  final RegExpMatch? match = RegExp(
    r'overflowed by ([\d.]+) pixels',
  ).firstMatch('$error');
  if (match == null) return 0;
  return double.parse(match.group(1)!).round();
}

/// What the scroll-hint pill's row WANTS, against what it was given. A `Row`
/// with `mainAxisSize: min` under loose constraints sizes to the smaller of the
/// two, so the shortfall between these is exactly the overflow.
({double needed, double given}) _pillWidth(WidgetTester tester) {
  final RenderBox pill = tester.renderObject<RenderBox>(
    find.byKey(KycIdentityStep.scrollHintKey),
  );
  return (
    needed: pill.getMaxIntrinsicWidth(double.infinity),
    given: pill.size.width,
  );
}

OmdsPrimaryButton _submitButton(WidgetTester tester) =>
    tester.widget<OmdsPrimaryButton>(
      find.byKey(KycIdentityStep.submitButtonKey),
    );

OmdsTextField _idNumberField(WidgetTester tester) =>
    tester.widget<OmdsTextField>(find.byKey(KycIdentityStep.idNumberFieldKey));

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'KycIdentityStep',
    const <String, Widget Function()>{
      'Cold entry · nothing captured': kycIdentityStepFresh,
      'Selfie still missing · CTA dead': kycIdentityStepSelfieMissing,
      'Ready to submit': kycIdentityStepReadyToSubmit,
      'Server rejected the ID number': kycIdentityStepIdNumberRejected,
      'Residency rejected on id_type': kycIdentityStepResidencyRejected,
      'Passport · 24-char number': kycIdentityStepPassportLongNumber,
    },
    expectedText: const <String, String>{
      // Cold entry is the only state with NO user content of its own, so it is
      // pinned on the affordance that exists only before a selfie is captured.
      'Cold entry · nothing captured': _scrollHint,
      // The other five each carry a value or an error string no other preview
      // in this file can produce.
      'Selfie still missing · CTA dead': _selfieMissingNumber,
      'Ready to submit': _readyNumber,
      'Server rejected the ID number': _idNumberRejected,
      'Residency rejected on id_type': _idTypeInvalid,
      'Passport · 24-char number': _passportNumber,
    },
  );

  group('KycIdentityStep submit gate (JEBV4-295)', () {
    testWidgets('cold entry: CTA dead, scroll hint offered', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycIdentityStepFresh);

      expect(_submitButton(tester).isEnabled, isFalse);
      expect(find.byKey(KycIdentityStep.scrollHintKey), findsOneWidget);
      // Nothing on screen says WHY the CTA is dead. Both inline id-number
      // errors are submit-scoped, and the CTA gate means a submit can no
      // longer be attempted to produce one.
      expect(_idNumberField(tester).errorText, isNull);
      expect(find.text(_idNumberRequired), findsNothing);
      expect(find.text(_idNumberInvalid), findsNothing);
      // …and the field carries no required marker either: `isRequired: true`
      // is passed, but OmdsTextField only consults it in its built-in
      // validator branch, which the supplied `validator` bypasses entirely.
      expect(_idNumberField(tester).isRequired, isTrue);
      expect(_idNumberField(tester).labelText, _nationalIdLabel);
    });

    testWidgets('a valid number is NOT enough while the selfie is missing', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycIdentityStepSelfieMissing);

      // Everything else is done — both ID sides captured, ToS ticked, and a
      // contract-valid 12-digit number on the field.
      expect(find.text(_selfieMissingNumber), findsOneWidget);
      expect(
        _submitButton(tester).isEnabled,
        isFalse,
        reason: 'submitting without a selfie always 400d server-side on '
            'selfie_with_liveness_url: null',
      );
      expect(find.byKey(KycIdentityStep.scrollHintKey), findsOneWidget);
    });

    testWidgets('selfie + valid number is what turns the CTA on', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycIdentityStepReadyToSubmit);

      expect(_submitButton(tester).isEnabled, isTrue);
      expect(find.text(_submitCta), findsOneWidget);
      // The hint keys off `!hasSelfie`, not off scroll position, so a captured
      // selfie removes it outright.
      expect(find.byKey(KycIdentityStep.scrollHintKey), findsNothing);
      expect(find.text(_scrollHint), findsNothing);
    });
  });

  group('KycIdentityStep id-type contract (E3/Q-042)', () {
    testWidgets('all three ratified types are offered, national_id default', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycIdentityStepFresh);

      expect(find.byKey(KycIdentityStep.idTypeNationalIdKey), findsOneWidget);
      expect(find.byKey(KycIdentityStep.idTypePassportKey), findsOneWidget);
      expect(find.byKey(KycIdentityStep.idTypeResidencyKey), findsOneWidget);
      expect(_idNumberField(tester).labelText, _nationalIdLabel);
      expect(_idNumberField(tester).hintText, _nationalIdHint);
    });

    testWidgets('passport swaps label, hint and the input contract', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycIdentityStepPassportLongNumber);

      final OmdsTextField field = _idNumberField(tester);
      expect(field.labelText, _passportLabel);
      expect(field.hintText, _documentHint);
      // No `^\d{12}$` shape applies to passport/residency, so no digits-only
      // filter and a 24-char cap instead of 12.
      expect(field.maxLength, 24);
      expect(field.keyboardType, TextInputType.text);
      expect(find.text(_passportNumber), findsOneWidget);
      expect(find.text(_nationalIdLabel), findsNothing);
    });

    testWidgets('residency renders its own label and the id_type rejection', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycIdentityStepResidencyRejected);

      expect(_idNumberField(tester).labelText, _residencyLabel);
      expect(
        tester
            .widget<OmdsRadioTile<KycIdType>>(
              find.byKey(KycIdentityStep.idTypeResidencyKey),
            )
            .groupValue,
        KycIdType.residency,
      );
      // The deployed BFF still spells this variant `residency_permit`
      // (JEBV4-197), so this inline line is all the jeeber is told — on a
      // picker where all three options look equally selectable.
      expect(find.text(_idTypeInvalid), findsOneWidget);
      // A type rejection must NOT also light up the number field.
      expect(_idNumberField(tester).errorText, isNull);
    });
  });

  group('KycIdentityStep inline rejection surfaces', () {
    testWidgets(
      'a server 400 on a locally-valid number falls back to "not accepted"',
      (WidgetTester tester) async {
        await pumpPreview(tester, kycIdentityStepIdNumberRejected);

        expect(_idNumberField(tester).errorText, _idNumberRejected);
        // Not the local shape errors: the client's own rules passed this value.
        expect(find.text(_idNumberRequired), findsNothing);
        expect(find.text(_idNumberInvalid), findsNothing);
        expect(find.text(_rejectedNumber), findsOneWidget);
        // The id-type picker stays clean.
        expect(find.text(_idTypeInvalid), findsNothing);
      },
    );

    testWidgets('the AR reading localizes and mirrors, with no English leak', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        kycIdentityStepResidencyRejected,
        locale: const Locale('ar'),
      );

      expect(find.text('اختر نوع هوية مدعومًا'), findsOneWidget);
      expect(find.text(_idTypeInvalid), findsNothing);
      expect(find.text(_submitCta), findsNothing);
      expect(
        Directionality.of(tester.element(find.byType(KycIdentityStep))),
        TextDirection.rtl,
      );
    });
  });

  // What these previews exposed, held as assertions so it cannot regress
  // unnoticed — and so that FIXING it fails this file loudly rather than
  // leaving a stale claim behind.
  //
  // Read the three measured tests with their ruler in mind: `flutter_test`
  // substitutes a fixed-width test font in which EVERY glyph is a square of the
  // font size, so a 31-character Arabic label measures about twice what a real
  // Arabic face draws. The numbers here are therefore a "widest plausible label"
  // stress proxy, NOT a device measurement — what they establish is the SHAPE of
  // the failure (clipped, silently, with no ellipsis) and not a claim that a
  // particular phone clips today. The first test pins that shape with no ruler
  // at all, and is the one that matters.
  group('KycIdentityStep scroll-hint pill (JEBV4-295)', () {
    testWidgets('the label can neither wrap nor ellipsize', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycIdentityStepSelfieMissing);

      final Finder pill = find.byKey(KycIdentityStep.scrollHintKey);
      // Nothing in the pill can yield width: no Flexible/Expanded around the
      // label, and a Row that sizes to its children rather than to its box.
      expect(
        find.descendant(of: pill, matching: find.byType(Flexible)),
        findsNothing,
      );
      expect(
        tester
            .widget<Row>(find.descendant(of: pill, matching: find.byType(Row)))
            .mainAxisSize,
        MainAxisSize.min,
      );
      // And the label asks for no ellipsis and no second line, so the one thing
      // it CAN do when it runs out of room is get cut off mid-word.
      final Text label = tester.widget<Text>(
        find.descendant(of: pill, matching: find.text(_scrollHint)),
      );
      expect(label.overflow, isNull);
      expect(label.maxLines, isNull);
      expect(label.softWrap, isNull);
    });

    testWidgets('EN at 200% text: the pill is clipped, not shortened', (
      WidgetTester tester,
    ) async {
      await _pumpInPreviewBox(
        tester,
        kycIdentityStepSelfieMissing,
        textScale: 2.0,
      );

      expect(_overflowPixels(tester.takeException()), greaterThan(0));
      final ({double needed, double given}) pill = _pillWidth(tester);
      expect(pill.needed, greaterThan(pill.given));
      // Not merely tight: it asks for more than the whole 390 dp phone width,
      // so no padding surgery inside the pill would save it.
      expect(pill.needed, greaterThan(390));
    });

    testWidgets('AR at 100% text: the same clip, one locale earlier', (
      WidgetTester tester,
    ) async {
      await _pumpInPreviewBox(
        tester,
        kycIdentityStepSelfieMissing,
        textScale: 1.0,
        locale: const Locale('ar'),
      );

      // 31 characters against the English 17 — Arabic is the locale with the
      // least headroom, and the first place a longer translation would land.
      expect(_overflowPixels(tester.takeException()), greaterThan(0));
      final ({double needed, double given}) pill = _pillWidth(tester);
      expect(pill.needed, greaterThan(pill.given));
    });

    testWidgets('the EN 100% baseline is the one reading with room to spare', (
      WidgetTester tester,
    ) async {
      await _pumpInPreviewBox(
        tester,
        kycIdentityStepSelfieMissing,
        textScale: 1.0,
      );

      expect(tester.takeException(), isNull);
      final ({double needed, double given}) pill = _pillWidth(tester);
      expect(pill.needed, lessThanOrEqualTo(pill.given));
    });
  });
}
