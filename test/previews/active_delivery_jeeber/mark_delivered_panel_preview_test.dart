// Render tests for the MarkDeliveredPanel previews.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/active_delivery_jeeber/presentation/widgets/mark_delivered_panel.dart';

import '../preview_test_harness.dart';

/// Exact ARB copy, so a reworded string breaks this file instead of silently
/// unpinning a preview.
const String _photoSlotLabel = 'Photos (optional, up to 5)'; // escalatePhotoLabel
const String _photoSlotSemanticLabel = 'Proof of delivery photo';
const String _ctaLabel = 'Complete Delivery'; // activeDeliveryMarkDone
const String _otpTitle = 'Enter delivery code'; // activeDeliveryOtpTitle
const String _otpTitleArabic = 'أدخل رمز التسليم';

/// The verbatim string `ActiveDeliveryCubit._mapOtpError` returns for
/// `ActiveDeliveryFailure.invalidOtp` — a hardcoded English literal, not an ARB
const String _otpInvalidCodeError =
    'Incorrect code — ask the recipient and try again';

/// The cash line each preview renders. This is the panel's only per-fixture
/// string, so it is what tells the six states apart.
const String _cashLayla = 'Pay 10.00 USD cash to Layla Haddad';
const String _cashKarim = 'Pay 24.50 USD cash to Karim Mansour';
const String _cashRita = 'Pay 7.00 USD cash to Rita Aoun';
const String _cashGeorges = 'Pay 18.00 USD cash to Georges Khoury';
const String _cashNour = 'Pay 32.00 USD cash to Nour Abou Zeid';

/// What a delivery with no `amount` and no `clientName` produces. The double
/// space is the empty substitution into `receiptCashToJeeber`, and is copied
const String _cashMissing = 'Pay  cash to Drop-off address';

final Finder _proofPhoto = find.bySemanticsIdentifier(
  'mark_delivered_proof_photo',
);
final Finder _markDeliveredCta = find.bySemanticsIdentifier(
  'mark_delivered_cta',
);
final Finder _otpSubmit = find.bySemanticsIdentifier(
  'mark_delivered_otp_submit',
);

/// The door-OTP preview's declared canvas box (`_markDeliveredPanelOtpBox`).
/// Kept in sync by hand — see [_pumpInOtpBox] for why the height matters.
const Size _otpBox = Size(390, 800);

/// Pumps a preview into the real canvas box instead of the 800x600 default test
/// surface.
Future<void> _pumpInOtpBox(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = _otpBox;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(previewCanvas(preview, locale));
  await tester.pumpAndSettle();
}

/// Pumps a preview at [scale] times the base text size — the third rendering
/// every [JeebPreview] produces, which `pumpPreview` alone does not reproduce.
Future<void> _pumpScaled(
  WidgetTester tester,
  Widget Function() preview,
  double scale, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: previewCanvas(preview, locale),
    ),
  );
  await tester.pumpAndSettle();
}

/// Every string the panel currently paints, in tree order — the cheapest way to
/// assert that two states are the SAME picture rather than merely both
List<String> _renderedText(WidgetTester tester) {
  return tester
      .widgetList<Text>(
        find.descendant(
          of: find.byType(MarkDeliveredPanel),
          matching: find.byType(Text),
        ),
      )
      .map((Text text) => text.data ?? '')
      .toList();
}

/// Centre-to-centre distance between neighbouring door-OTP cells, in laid-out
/// order (left to right on screen, whatever the text direction).
List<double> _otpCellGaps(WidgetTester tester) {
  final Finder cells = find.descendant(
    of: find.byType(OmdsOtpInput),
    matching: find.byType(TextField),
  );
  final List<double> centres = <double>[
    for (int i = 0; i < cells.evaluate().length; i++)
      tester.getCenter(cells.at(i)).dx,
  ]..sort();
  return <double>[
    for (int i = 1; i < centres.length; i++) centres[i] - centres[i - 1],
  ];
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'MarkDeliveredPanel',
    const <String, Widget Function()>{
      'Awaiting proof · CTA armed': markDeliveredPanelAwaitingProof,
      'Proof uploading · slot inert': markDeliveredPanelUploadingProof,
      'Proof captured · thumbnail': markDeliveredPanelProofCaptured,
      'Upload failed · looks empty': markDeliveredPanelUploadFailed,
      'Cash details missing': markDeliveredPanelCashDetailsMissing,
      'Door OTP · wrong code': markDeliveredPanelDoorOtpWrongCode,
    },
    expectedText: const <String, String>{
      // One distinct delivery per state — see the header note.
      'Awaiting proof · CTA armed': _cashLayla,
      'Proof uploading · slot inert': _cashKarim,
      'Proof captured · thumbnail': _cashRita,
      'Upload failed · looks empty': _cashGeorges,
      'Cash details missing': _cashMissing,
      'Door OTP · wrong code': _cashNour,
    },
  );

  group('MarkDeliveredPanel previews · the proof-photo slot', () {
    testWidgets('empty: a tappable placeholder over the borrowed label', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, markDeliveredPanelAwaitingProof);

      expect(find.byIcon(Icons.add_a_photo_outlined), findsOneWidget);
      expect(find.text(_photoSlotLabel), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(find.byType(OmdsLoadingState), findsNothing);
      // The visible copy is the escalation flow's, but the accessible name is
      expect(
        tester.getSemantics(_proofPhoto),
        isSemantics(
          label: _photoSlotSemanticLabel,
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('uploading: a spinner, and the slot goes inert', (
      WidgetTester tester,
    ) async {
      // A live tap target here is how a jeeber fires a second camera capture
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, markDeliveredPanelUploadingProof);

      expect(find.byType(OmdsLoadingState), findsOneWidget);
      expect(find.text(_photoSlotLabel), findsNothing);
      expect(find.byIcon(Icons.add_a_photo_outlined), findsNothing);
      // The captured bytes are already in state, and are deliberately not shown.
      expect(find.byType(Image), findsNothing);
      expect(
        tester.getSemantics(_proofPhoto),
        isSemantics(
          label: _photoSlotSemanticLabel,
          isButton: true,
          isEnabled: false,
          hasEnabledState: true,
          hasTapAction: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('captured: the in-memory thumbnail, never the CDN url', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, markDeliveredPanelProofCaptured);

      // JEBV4-200: `bytes` wins over `proofPhotoUrl`, which keeps a network
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(OmdsCachedImage), findsNothing);
      expect(find.text(_photoSlotLabel), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('failed renders the SAME picture as never-captured', (
      WidgetTester tester,
    ) async {
      // `ProofPhotoStatus.failed` is what the cubit emits when the CDN upload
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(tester, markDeliveredPanelAwaitingProof);
      final List<String> empty = _renderedText(tester);

      await pumpPreview(tester, markDeliveredPanelUploadFailed);
      final List<String> failed = _renderedText(tester);

      expect(
        failed.where((String s) => s != _cashGeorges),
        equals(empty.where((String s) => s != _cashLayla)),
        reason: 'a failed upload must be distinguishable from an empty slot',
      );
      expect(find.byIcon(Icons.add_a_photo_outlined), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(
        tester.getSemantics(_proofPhoto),
        isSemantics(isEnabled: true, hasEnabledState: true, hasTapAction: true),
        reason: 'retry is possible — nothing tells the jeeber it is needed',
      );
      handle.dispose();
    });
  });

  group('MarkDeliveredPanel previews · the cash line', () {
    testWidgets('a missing amount renders an empty substitution', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, markDeliveredPanelCashDetailsMissing);

      // "Pay  cash to Drop-off address" — no amount, and a UI heading standing
      expect(find.text(_cashMissing), findsOneWidget);
      expect(find.textContaining('Pay  cash'), findsOneWidget);
    });

    testWidgets('mirrors in Arabic — the icon leads on the right', (
      WidgetTester tester,
    ) async {
      // `Row(children: [Icon, SizedBox, Expanded(Text)])` inside a `Container`
      await pumpPreview(tester, markDeliveredPanelAwaitingProof);
      final double ltrIcon = tester
          .getCenter(find.byIcon(Icons.payments_outlined))
          .dx;
      final double ltrCentre = tester
          .getCenter(find.byType(MarkDeliveredPanel))
          .dx;
      expect(ltrIcon, lessThan(ltrCentre));

      await pumpPreview(
        tester,
        markDeliveredPanelAwaitingProof,
        locale: const Locale('ar'),
      );
      final double rtlIcon = tester
          .getCenter(find.byIcon(Icons.payments_outlined))
          .dx;
      expect(rtlIcon, greaterThan(ltrCentre));
    });
  });

  group('MarkDeliveredPanel previews · the door-OTP swap', () {
    testWidgets('otpRequired replaces the CTA outright', (
      WidgetTester tester,
    ) async {
      await _pumpInOtpBox(tester, markDeliveredPanelAwaitingProof);
      expect(_markDeliveredCta, findsOneWidget);
      expect(find.byType(OmdsOtpInput), findsNothing);

      await _pumpInOtpBox(tester, markDeliveredPanelDoorOtpWrongCode);
      // Both ways to finish a delivery must never be on screen at once: only
      expect(_markDeliveredCta, findsNothing);
      expect(find.byType(OmdsOtpInput), findsOneWidget);
      expect(find.text(_otpTitle), findsOneWidget);
      // …and everything above the swap survives it.
      expect(find.text(_cashNour), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('the entry takes focus the moment it appears', (
      WidgetTester tester,
    ) async {
      // `OmdsOtpInput`'s `autoFocus` defaults to true and `_DoorOtpEntry` does
      await _pumpInOtpBox(tester, markDeliveredPanelDoorOtpWrongCode);

      final EditableText firstCell = tester.widget<EditableText>(
        find
            .descendant(
              of: find.byType(OmdsOtpInput),
              matching: find.byType(EditableText),
            )
            .first,
      );
      expect(firstCell.focusNode.hasFocus, isTrue);

      // The CTA state has a text field too — the optional note — and it is
      await _pumpInOtpBox(tester, markDeliveredPanelAwaitingProof);
      expect(
        tester.widget<EditableText>(find.byType(EditableText).first)
            .focusNode
            .hasFocus,
        isFalse,
      );
    });

    testWidgets('submit is dead until four digits are in', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pumpInOtpBox(tester, markDeliveredPanelDoorOtpWrongCode);

      // `isEnabled: _code.length == 4`, and `OmdsLoadingButton` drops its
      expect(
        tester.getSemantics(_otpSubmit),
        isSemantics(label: _ctaLabel, isButton: false, hasTapAction: false),
      );
      // Control: the CTA this entry replaced does declare itself a button and
      await _pumpInOtpBox(tester, markDeliveredPanelAwaitingProof);
      expect(
        tester.getSemantics(_markDeliveredCta),
        isSemantics(label: _ctaLabel, isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('the inline error is English even in Arabic', (
      WidgetTester tester,
    ) async {
      // `otpError` is not an ARB key: `ActiveDeliveryCubit._mapOtpError`
      await _pumpInOtpBox(
        tester,
        markDeliveredPanelDoorOtpWrongCode,
        locale: const Locale('ar'),
      );

      expect(find.text(_otpTitleArabic), findsOneWidget);
      expect(find.text(_otpInvalidCodeError), findsOneWidget);
    });

    testWidgets('the four cells are unevenly spaced in Arabic', (
      WidgetTester tester,
    ) async {
      // `OmdsOtpInput` pads each cell with a physical
      await _pumpInOtpBox(tester, markDeliveredPanelDoorOtpWrongCode);
      final List<double> ltr = _otpCellGaps(tester);

      await _pumpInOtpBox(
        tester,
        markDeliveredPanelDoorOtpWrongCode,
        locale: const Locale('ar'),
      );
      final List<double> rtl = _otpCellGaps(tester);

      expect(ltr, <double>[56, 56, 56]);
      expect(
        rtl,
        <double>[52, 56, 52],
        reason: 'RTL crowds the outer cells by half the spacing each',
      );
    });
  });

  group('MarkDeliveredPanel previews · 200% text', () {
    testWidgets('the CTA label outgrows its fixed 48 dp button', (
      WidgetTester tester,
    ) async {
      await _pumpScaled(tester, markDeliveredPanelAwaitingProof, 2.0);

      final Size button = tester.getSize(find.byType(OmdsLoadingButton));
      final RenderParagraph label = tester.renderObject<RenderParagraph>(
        find.text(_ctaLabel),
      );
      // `OmdsLoadingButton` hard-codes `height: Sizes.fourXLarge` (48) and
      expect(button.height, 48);
      expect(label.getMaxIntrinsicHeight(label.size.width), greaterThan(48));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the panel scrolls instead of overflowing', (
      WidgetTester tester,
    ) async {
      // The production frame is a ListView, which is what keeps the doubled
      await _pumpScaled(tester, markDeliveredPanelDoorOtpWrongCode, 2.0);

      expect(tester.takeException(), isNull);
      expect(find.byType(Scrollable), findsWidgets);
    });
  });
}
