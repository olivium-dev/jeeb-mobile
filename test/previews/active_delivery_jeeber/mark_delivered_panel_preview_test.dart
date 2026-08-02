// Render tests for the MarkDeliveredPanel previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand.
//
// All six previews are the SAME panel told apart by a `ProofPhotoStatus`, an
// `otpRequired` flag and one delivery record, and four of the six paint an
// identical set of strings. So every state carries its own amount + recipient,
// and `expectedText` pins the resulting cash line — the one string in this
// panel that varies per fixture. A suite that only asked "did something
// render?" would pass on six copies of the empty state.
//
// The groups after that are not preview hygiene. They are what these previews
// exposed, held as assertions so they cannot regress unnoticed — and so that
// FIXING one fails this file loudly rather than leaving a stale claim in the
// widget's doc comments:
//
//   * a failed proof-photo upload renders the exact same picture as "no photo
//     yet" — same icon, same label, same live tap target, no error anywhere;
//   * the photo slot's visible label is `escalatePhotoLabel`, "Photos
//     (optional, up to 5)", borrowed from the escalation flow for a slot that
//     takes one photo;
//   * a delivery with no `amount` renders "Pay  cash to Drop-off address";
//   * `otpError` is hardcoded English, so the Arabic rendering mixes scripts;
//   * `OmdsOtpInput` spaces its cells with a physical `EdgeInsets.only`, so the
//     four door-OTP boxes are unevenly spaced in Arabic;
//   * `OmdsLoadingButton` pins 48 dp around a plain `Text`, so the CTA label is
//     clipped at 200%.
//
// Every dimension asserted here is measured on the test fallback font, whose
// glyphs are wider than the bundled Inter, so widths and heights are upper
// bounds rather than promises about the shipped font.

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
/// key. The door-OTP preview passes the real one.
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
/// here exactly as it renders.
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
///
/// The door-OTP entry needs this. `_DoorOtpEntry` mounts [OmdsOtpInput] with its
/// default `autoFocus: true`, so cell 1 takes focus on the first frame and asks
/// the enclosing scrollable to reveal it. On a 600 dp surface the 756 dp panel
/// cannot show the cell row, so the request becomes a driven scroll animation —
/// and `Scrollable` wraps its viewport in an `IgnorePointer` for the duration,
/// which strips the tap action off EVERY semantics node in the panel. The
/// previews mute the ticker, so that animation never finishes and the block
/// never lifts. At the box the preview actually declares, the cell row is
/// already on screen, nothing scrolls, and the semantics below mean what they
/// say.
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
/// containing some expected fragment.
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
      // the right one — a screen reader is better served here than an eye.
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
      // over an upload that is already on the wire.
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
      // fetch (`OmdsCachedImage`) out of both the preview and the canvas.
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(OmdsCachedImage), findsNothing);
      expect(find.text(_photoSlotLabel), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('failed renders the SAME picture as never-captured', (
      WidgetTester tester,
    ) async {
      // `ProofPhotoStatus.failed` is what the cubit emits when the CDN upload
      // throws. The panel has no failure affordance at all: same icon, same
      // label, same live tap target, no error text. The only difference between
      // these two renderings is the fixture's own cash line.
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
      // in for the recipient's name, on the panel that collects the money.
      expect(find.text(_cashMissing), findsOneWidget);
      expect(find.textContaining('Pay  cash'), findsOneWidget);
    });

    testWidgets('mirrors in Arabic — the icon leads on the right', (
      WidgetTester tester,
    ) async {
      // `Row(children: [Icon, SizedBox, Expanded(Text)])` inside a `Container`
      // with symmetric padding. Nothing here is directional by hand, so this is
      // a check that the whole pill flips rather than only the glyph order.
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
      // the OTP path is an edge the frozen SM opens for `AtDoor → Done`.
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
      // not override it, so on the real screen the keyboard opens unasked and
      // the delivering-phase ListView scroll-jumps to the cell row the instant
      // `otpRequired` flips — under the jeeber's thumb, at the customer's door.
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
      // correctly left alone.
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
      // `onTap` when it cannot be tapped — so an empty entry cannot POST a
      // verify.
      //
      // The second half of this is a defect, not a guard: unlike
      // `mark_delivered_cta`, the `mark_delivered_otp_submit` wrapper is a bare
      // `Semantics(container: true)` with no `button: true`, and the
      // `OmdsLoadingButton` inside it is given no `identifier` of its own — so
      // the node carries a label and NO button flag. TalkBack reads "Complete
      // Delivery" as plain text at the one place the delivery is completed.
      expect(
        tester.getSemantics(_otpSubmit),
        isSemantics(label: _ctaLabel, isButton: false, hasTapAction: false),
      );
      // Control: the CTA this entry replaced does declare itself a button and
      // does carry a live tap action — so the assertion above is a real
      // difference between the two, not a blocked-viewport artifact.
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
      // returns hardcoded English literals and this panel prints them verbatim.
      // An Arabic-speaking jeeber gets an Arabic title over an English error.
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
      // `EdgeInsets.only(left: isFirst ? 0 : spacing/2, right: isLast ? 0 : …)`.
      // Physical, not directional — so when the Row reverses for RTL the zero
      // paddings end up on the inside and the gaps redistribute.
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
      // centres a plain Text in it, so the wrapped label is clipped — not
      // ellipsized, not given more room, and with no overflow stripe to notice
      // it by.
      expect(button.height, 48);
      expect(label.getMaxIntrinsicHeight(label.size.width), greaterThan(48));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the panel scrolls instead of overflowing', (
      WidgetTester tester,
    ) async {
      // The production frame is a ListView, which is what keeps the doubled
      // text off the overflow path. Guards the fixture as much as the widget:
      // a preview that dropped the ListView would paint a red stripe here.
      await _pumpScaled(tester, markDeliveredPanelDoorOtpWrongCode, 2.0);

      expect(tester.takeException(), isNull);
      expect(find.byType(Scrollable), findsWidgets);
    });
  });
}
