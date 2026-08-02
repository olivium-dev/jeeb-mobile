// Render tests for the GoodsCostScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// `GoodsCostScreen` is a one-field form, and that shapes this suite twice over.
//
// **1. Almost nothing distinguishes its states at mount.** The only production
// copy that varies is the entry-field label, and two genuinely different
// states — the currency read still in flight, and the currency read having
// failed — render the identical neutral `Goods cost`. Every preview therefore
// carries a [GoodsCostScreenCaptions] line, and the shared render suite pins
// that; the groups below then pin the production contract each state exists
// for, which is what separates a real state from a card that merely rendered.
//
// **2. Half the states are only reachable through the keyboard.**
// `GoodsCostSubmitStatus.inFlight` and `.failed` require a parseable amount AND
// a press of the CTA — the screen exposes no cubit seam, so no fixture can seed
// them. The submit-axis group performs the typing and the press, which also
// makes it the only place the screen's most surprising behaviour is asserted:
// an amount `double.tryParse` rejects is a completely silent no-op.
//
// ## Fonts
//
// `preview_test_harness.dart` does not load real fonts, so text lays out in
// Flutter's 1-em test face — Latin ~2x too wide, Arabic ~2.4x. Every
// measurement in the geometry group below is a HEIGHT claim about wrapped text,
// which the inflated face makes worse rather than better, so `loadInterTestFont`
// is loaded and every measured assertion is made in **English**, where that font
// really is the shipping Inter. Arabic is still laid out in the fake face here
// (`previewCanvas` builds `AppTheme.light()` without `withGoldenTestFonts`, and
// the theme carries no `fontFamilyFallback`), so no overflow or slack figure is
// asserted in Arabic at all — under that face this screen measures 0 pt of
// slack at 200% on the compact frame, which is an artifact and not a device
// fact. Arabic is asserted only for "builds, and renders its own state", which
// the shared suite does in both locales.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/goods_cost/presentation/goods_cost_screen.dart';

import '../../support/load_test_fonts.dart';
import '../preview_test_harness.dart';

/// Roughly what a software keyboard takes from the viewport on the phones this
/// app targets. Used as a comparison BAND, never as a measurement: the claim
/// the geometry group makes is "the body's slack is smaller than this", which
/// is a fact about the measured slack.
const double _kSoftwareKeyboardInset = 290;

/// The delivery's currency reached the label. Only the USD fixture produces it.
const String _kUsdLabel = 'Goods cost (USD)';

/// The other half of the same contract — and the card that carries a hardcoded
/// `$` prefix icon beside it.
const String _kLbpLabel = 'Goods cost (LBP)';

/// The degraded label, rendered by BOTH neutral states.
const String _kNeutralLabel = 'Goods cost';

const String _kValidationCopy = 'Enter a valid amount and try again.';
const String _kNetworkCopy =
    "Couldn't reach the server. Check your connection and try again.";

Finder get _cta => find.byType(OmdsLoadingButton);
Finder get _field => find.byType(TextField);
Finder get _error => find.byKey(const Key('goods-cost-error'));
Finder get _caller => find.byKey(const Key('goods-cost-preview-caller'));

bool _ctaEnabled(WidgetTester tester) =>
    tester.widget<OmdsLoadingButton>(_cta).isEnabled;

/// Types [amount] and presses Confirm, settling afterwards.
///
/// Two pumps, not one: `onChanged` re-enables the CTA through `setState`, and a
/// press dispatched before that frame lands on a disabled button.
Future<void> _typeAndConfirm(WidgetTester tester, String amount) async {
  await tester.enterText(_field, amount);
  await tester.pump();
  await tester.tap(_cta);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await loadInterTestFont();
    loadPreviewArbs();
  });

  // Every preview settles at mount: the two stalled fixtures hold an
  // uncompleted Future rather than an animation, and the CTA spinner is only
  // reachable after a press. So the whole set goes through the shared suite,
  // pinned by its caption — see note 1 in the header.
  testPreviewsRender(
    'GoodsCostScreen',
    const <String, Widget Function()>{
      'Currency USD · records and pops': goodsCostScreenCurrencyUsd,
      'Currency LBP · hardcoded \$ icon': goodsCostScreenCurrencyLbp,
      'Currency read in flight': goodsCostScreenCurrencyPending,
      'Currency read failed · neutral label': goodsCostScreenCurrencyUnavailable,
      'Record rejected · 422 validation': goodsCostScreenRecordRejected,
      'Record failed · network': goodsCostScreenRecordNetworkDown,
      'Record in flight · CTA spinner': goodsCostScreenRecordStalled,
      'Compact 320x568 · no scroll anywhere': goodsCostScreenCompactCeiling,
    },
    expectedText: const <String, String>{
      'Currency USD · records and pops': GoodsCostScreenCaptions.usd,
      'Currency LBP · hardcoded \$ icon': GoodsCostScreenCaptions.lbp,
      'Currency read in flight': GoodsCostScreenCaptions.currencyPending,
      'Currency read failed · neutral label':
          GoodsCostScreenCaptions.currencyUnavailable,
      'Record rejected · 422 validation': GoodsCostScreenCaptions.recordRejected,
      'Record failed · network': GoodsCostScreenCaptions.recordNetworkDown,
      'Record in flight · CTA spinner': GoodsCostScreenCaptions.recordStalled,
      'Compact 320x568 · no scroll anywhere':
          GoodsCostScreenCaptions.compactCeiling,
    },
  );

  // The currency axis — everything reachable as a first frame.
  group('GoodsCostScreen previews · the currency axis', () {
    // NB: one preview per test. Pumping a second preview into the same tester
    // does NOT rebuild these — `previewCanvas` produces the same widget types,
    // so the `BlocProvider` element is UPDATED rather than replaced and keeps
    // the cubit the first preview created.
    testWidgets('the phone previews pin a 390 pt frame, not the canvas width', (
      WidgetTester tester,
    ) async {
      // The harness pumps an 800 pt surface: a preview that left its width to
      // the host would measure 800 here, and none of this layout applies there.
      await pumpPreview(tester, goodsCostScreenCurrencyUsd);

      expect(tester.getSize(find.byType(GoodsCostScreen)).width, 390);
    });

    testWidgets('the compact ceiling pins the 320 pt frame', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, goodsCostScreenCompactCeiling);

      expect(tester.getSize(find.byType(GoodsCostScreen)).width, 320);
    });

    testWidgets('a resolved currency labels the field with it, and nothing '
        'else on screen names a delivery', (WidgetTester tester) async {
      await pumpPreview(tester, goodsCostScreenCurrencyUsd);

      expect(find.text(_kUsdLabel), findsOneWidget);
      expect(find.text(_kNeutralLabel), findsNothing);
      // The Jeeber is asked for a number with no order reference anywhere on
      // the screen — the delivery id is a route parameter and is never shown.
      expect(find.textContaining('DEL-'), findsNothing);
    });

    testWidgets('the gateway owns the currency STRING while the field prefixes '
        'a hardcoded dollar', (WidgetTester tester) async {
      await pumpPreview(tester, goodsCostScreenCurrencyLbp);

      // 40_GUARDRAILS_ARCH §5, quoted above `_label`: no hardcoded currency.
      // The label obeys it…
      expect(find.text(_kLbpLabel), findsOneWidget);
      // …and `prefixIcon: Icon(Icons.attach_money)` sits in the same slot.
      // Pinned as CURRENT behaviour, not endorsed: an LBP delivery asks for a
      // goods cost beside a `$`.
      expect(find.byIcon(Icons.attach_money), findsOneWidget);
    });

    testWidgets('the dollar prefix follows the reading direction, so in AR it '
        'sits at the right of the field', (WidgetTester tester) async {
      await pumpPreview(tester, goodsCostScreenCurrencyLbp);
      final double ltrIcon = tester.getCenter(
        find.byIcon(Icons.attach_money),
      ).dx;
      final double ltrFieldCentre = tester.getCenter(_field).dx;

      await tester.pumpWidget(const SizedBox.shrink());
      await pumpPreview(
        tester,
        goodsCostScreenCurrencyLbp,
        locale: const Locale('ar'),
      );
      final double rtlIcon = tester.getCenter(
        find.byIcon(Icons.attach_money),
      ).dx;
      final double rtlFieldCentre = tester.getCenter(_field).dx;

      expect(ltrIcon, lessThan(ltrFieldCentre));
      expect(rtlIcon, greaterThan(rtlFieldCentre));
    });

    // The read-in-flight / read-failed pair. They are one `Completer` apart and
    // render the same pixels, which is the whole reason the captions exist.
    testWidgets('a read still in flight is INDISTINGUISHABLE from a read that '
        'failed', (WidgetTester tester) async {
      await pumpPreview(tester, goodsCostScreenCurrencyPending);

      expect(find.text(_kNeutralLabel), findsOneWidget);
      expect(find.text(_kUsdLabel), findsNothing);
      // No spinner, no skeleton, no disabled field: nothing anywhere says a
      // read is happening, so the label is free to change under the Jeeber's
      // finger whenever it lands.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.widget<OmdsTextField>(find.byType(OmdsTextField)).enabled,
          isTrue);
    });

    testWidgets('a failed read degrades the label and blocks nothing', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, goodsCostScreenCurrencyUnavailable);

      // Deliberate: `loadCurrency` swallows the failure so cost entry is never
      // blocked. The cost is that the Jeeber cannot tell which currency the
      // number will be recorded in.
      expect(find.text(_kNeutralLabel), findsOneWidget);
      expect(_error, findsNothing);
      expect(_cta, findsOneWidget);
    });

    testWidgets('the only way off this screen is a leading arrow the ROUTER '
        'supplies', (WidgetTester tester) async {
      await pumpPreview(tester, goodsCostScreenCurrencyUsd);

      // `OMDSAppBar` leaves `showBackButton` at its `false` default, so the
      // screen contributes no leading widget of its own: the arrow exists only
      // because `automaticallyImplyLeading` found a route underneath — which
      // the preview host supplies deliberately. Reached by a stack-REPLACING
      // navigation there would be no arrow, and the success listener's
      // unguarded `Navigator.of(context).pop(recorded)` would empty the
      // Navigator rather than return anywhere.
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('the CTA is inert until something is typed', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, goodsCostScreenCurrencyUsd);

      expect(_ctaEnabled(tester), isFalse);

      await tester.enterText(_field, '4');
      await tester.pump();

      expect(_ctaEnabled(tester), isTrue);
    });
  });

  // The submit axis — nothing here is reachable without the keyboard.
  group('GoodsCostScreen previews · the submit axis', () {
    testWidgets('a successful record pops with the gateway-confirmed '
        'GoodsCost', (WidgetTester tester) async {
      await pumpPreview(tester, goodsCostScreenCurrencyUsd);

      await _typeAndConfirm(tester, '12.5');

      // The screen is GONE — `Navigator.of(context).pop(recorded)` — and the
      // page that pushed it has the record. This is the only thing this screen
      // exists to do, and on a host with one route it would instead blank the
      // card; see the third bullet in the preview section.
      expect(find.byType(GoodsCostScreen), findsNothing);
      expect(
        tester.widget<Text>(_caller).data,
        'popped with 12.5 USD',
      );
    });

    testWidgets('a rejected record shows the 422 copy inline, under the field', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, goodsCostScreenRecordRejected);

      await _typeAndConfirm(tester, '12.5');

      expect(_error, findsOneWidget);
      expect(find.text(_kValidationCopy), findsOneWidget);
      // Non-destructive: the form is still there and still holds the amount.
      expect(find.byType(GoodsCostScreen), findsOneWidget);
      expect(tester.widget<TextField>(_field).controller?.text, '12.5');
      expect(tester.getTopLeft(_error).dy, greaterThan(tester.getTopLeft(_field).dy));
    });

    testWidgets('…and the next keystroke destroys the message', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, goodsCostScreenRecordRejected);
      await _typeAndConfirm(tester, '12.5');
      expect(find.text(_kValidationCopy), findsOneWidget);

      await tester.enterText(_field, '12.55');
      await tester.pump();

      // `onChanged` calls `acknowledgeError()`, so correcting the amount —
      // the one action the message asks for — is what erases the message.
      // Nothing marks the field itself as invalid either. Pinned as CURRENT
      // behaviour.
      expect(_error, findsNothing);
      expect(
        tester.widget<TextField>(_field).decoration?.errorText,
        isNull,
      );
    });

    testWidgets('a network failure shows the retryable copy, not the 422 one', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, goodsCostScreenRecordNetworkDown);

      await _typeAndConfirm(tester, '90000');

      // The two failures are told apart only by this sentence, and only one of
      // them can be fixed by pressing Confirm again.
      expect(find.text(_kNetworkCopy), findsOneWidget);
      expect(find.text(_kValidationCopy), findsNothing);
    });

    testWidgets('the client never validates the amount — a negative cost is '
        'sent to the gateway to be rejected there', (WidgetTester tester) async {
      await pumpPreview(tester, goodsCostScreenRecordRejected);

      await _typeAndConfirm(tester, '-5');

      // `-5` parses, so it is submitted; the 422 comes back from the fixture,
      // not from anything on the device. There is no `inputFormatters` and no
      // validator on the field. Pinned as CURRENT behaviour.
      expect(find.text(_kValidationCopy), findsOneWidget);
    });

    // A record in flight cannot be settled: the CTA renders
    // `OmdsButtonLoading`, an indefinite `CircularProgressIndicator`.
    testWidgets('a record in flight spins the CTA and takes the field away', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, goodsCostScreenRecordStalled);
      await tester.enterText(_field, '40');
      await tester.pump();
      await tester.tap(_cta);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(tester.widget<OmdsLoadingButton>(_cta).isLoading, isTrue);
      // The Jeeber can no longer see or correct what they typed while the
      // record is outstanding, and there is no cancel.
      expect(
        tester.widget<OmdsTextField>(find.byType(OmdsTextField)).enabled,
        isFalse,
      );
      expect(_error, findsNothing);
    });

    // The screen's most surprising behaviour, one input per test so no state
    // leaks between them.
    for (final String typed in const <String>['12,5', '١٢', 'abc', '12.5.6']) {
      testWidgets('"$typed" arms the CTA and the press does NOTHING', (
        WidgetTester tester,
      ) async {
        // Bound to REJECT the record, so anything that actually reached the
        // repository would paint `goods-cost-error`. Nothing does.
        await pumpPreview(tester, goodsCostScreenRecordRejected);

        await tester.enterText(_field, typed);
        await tester.pump();
        expect(
          _ctaEnabled(tester),
          isTrue,
          reason: 'isEnabled only asks whether the field is non-empty',
        );

        await tester.tap(_cta);
        await tester.pumpAndSettle();

        // `_submit` drops a `double.tryParse` miss on the floor: no spinner, no
        // error, no state change, no message of any kind. `12,5` is what a
        // comma-decimal keyboard produces and `١٢` is what `TextInputType
        // .number` gives an Arabic keyboard, so this is not an exotic path.
        expect(_error, findsNothing);
        expect(tester.widget<OmdsLoadingButton>(_cta).isLoading, isFalse);
        expect(find.byType(GoodsCostScreen), findsOneWidget);
        // Nothing popped either — the caller stand-in is still covered by the
        // screen, so it is off stage and unfindable.
        expect(_caller, findsNothing);
        // …and the rejected text is still sitting in the field, unmarked.
        expect(tester.widget<TextField>(_field).controller?.text, typed);
      });
    }
  });

  // `previewCanvas` pumps onto the 800 x 600 test surface, not the `size:` a
  // preview declares, so the shared suite cannot see what the canvas shows on a
  // phone. These re-pump at the declared devices so the layout claims the
  // matrixed previews make are CI facts rather than something a reviewer has to
  // notice. English only — see the fonts note in the header.
  group('GoodsCostScreen previews · measured at the declared devices', () {
    Future<List<FlutterErrorDetails>> pumpDevice(
      WidgetTester tester,
      Widget Function() preview, {
      required Size logical,
      required double textScale,
    }) async {
      tester.view.physicalSize = logical * 3;
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      // A RenderFlex reports an overflow ONCE per render object, so a fresh
      // tree per measurement is what keeps these independent.
      await tester.pumpWidget(const SizedBox.shrink());
      final List<FlutterErrorDetails> caught = <FlutterErrorDetails>[];
      final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
      FlutterError.onError = caught.add;
      try {
        await tester.pumpWidget(previewCanvas(preview, const Locale('en')));
        await tester.pumpAndSettle();
      } finally {
        FlutterError.onError = previous;
      }
      return caught;
    }

    /// The `Spacer` between the field and the CTA — every pt of give the body
    /// has. Once the viewport takes more than this away, the column overflows.
    double slack(WidgetTester tester) =>
        tester.getSize(find.byType(Spacer)).height;

    testWidgets('390 x 844 is comfortable at 100% and at 200% text', (
      WidgetTester tester,
    ) async {
      expect(
        await pumpDevice(
          tester,
          goodsCostScreenCurrencyUsd,
          logical: const Size(390, 844),
          textScale: 1,
        ),
        isEmpty,
      );
      expect(slack(tester), greaterThan(_kSoftwareKeyboardInset));

      expect(
        await pumpDevice(
          tester,
          goodsCostScreenCurrencyUsd,
          logical: const Size(390, 844),
          textScale: 2,
        ),
        isEmpty,
      );
      expect(slack(tester), greaterThan(_kSoftwareKeyboardInset));
    });

    testWidgets('320 x 568 fits at 100% text — but with less give than a '
        'keyboard needs', (WidgetTester tester) async {
      expect(
        await pumpDevice(
          tester,
          goodsCostScreenCompactCeiling,
          logical: const Size(320, 568),
          textScale: 1,
        ),
        isEmpty,
      );

      // Nothing on this screen scrolls: `_GoodsCostView` is a fixed Column
      // ending in `Expanded`, and the body inside it is field + optional error
      // + `Spacer` + CTA. The `Spacer` is the only give there is, and on the
      // narrowest supported phone it is already smaller than the software
      // keyboard this text-entry screen raises the moment the field is focused.
      // The screen's own Scaffold resizes for that inset, so the shortfall
      // lands on this column. Pinned as CURRENT behaviour.
      expect(slack(tester), lessThan(_kSoftwareKeyboardInset));
    });

    testWidgets('320 x 568 at 200% text has 40-odd pt of give left', (
      WidgetTester tester,
    ) async {
      expect(
        await pumpDevice(
          tester,
          goodsCostScreenCompactCeiling,
          logical: const Size(320, 568),
          textScale: 2,
        ),
        isEmpty,
      );

      // It does NOT overflow standing still — the claim the compact preview's
      // 200% card is there to let a reviewer check. What it has is under 50 pt
      // of slack on a screen with no scroll view at all.
      expect(slack(tester), lessThan(50));
    });

    testWidgets('take a keyboard off the compact frame and the form '
        'overflows', (WidgetTester tester) async {
      // 568 minus a software keyboard: exactly what `resizeToAvoidBottomInset`
      // leaves the body on a focused field, expressed as a shorter viewport
      // because the preview host's own Scaffold consumes the inset first.
      final List<FlutterErrorDetails> caught = await pumpDevice(
        tester,
        goodsCostScreenCompactCeiling,
        logical: const Size(320, 568 - _kSoftwareKeyboardInset),
        textScale: 1,
      );

      expect(caught, isNotEmpty);
      expect(
        caught.single.exception.toString(),
        contains('overflowed'),
        reason: 'a one-field form with no scroll view, at 100% text, on the '
            'narrowest supported phone, with its own keyboard open',
      );
    });
  });
}
