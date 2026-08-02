// Render tests for the GoodsCostScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/goods_cost/presentation/goods_cost_screen.dart';

import '../../support/load_test_fonts.dart';
import '../preview_test_harness.dart';

/// Roughly what a software keyboard takes from the viewport on the phones this
/// app targets. Used as a comparison BAND, never as a measurement: the claim
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
/// Two pumps, not one: `onChanged` re-enables the CTA through `setState`, and a
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
  testPreviewsRender(
    'GoodsCostScreen',
    const <String, Widget Function()>{
      'Currency USD · records and pops': goodsCostScreenCurrencyUsd,
      'Currency LBP · hardcoded USD icon': goodsCostScreenCurrencyLbp,
      'Currency read in flight': goodsCostScreenCurrencyPending,
      'Currency read failed · neutral label': goodsCostScreenCurrencyUnavailable,
      'Record rejected · 422 validation': goodsCostScreenRecordRejected,
      'Record failed · network': goodsCostScreenRecordNetworkDown,
      'Record in flight · CTA spinner': goodsCostScreenRecordStalled,
      'Compact 320x568 · no scroll anywhere': goodsCostScreenCompactCeiling,
    },
    expectedText: const <String, String>{
      'Currency USD · records and pops': GoodsCostScreenCaptions.usd,
      'Currency LBP · hardcoded USD icon': GoodsCostScreenCaptions.lbp,
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
    testWidgets('the phone previews pin a 390 pt frame, not the canvas width', (
      WidgetTester tester,
    ) async {
      // The harness pumps an 800 pt surface: a preview that left its width to
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
      expect(find.textContaining('DEL-'), findsNothing);
    });

    testWidgets('the gateway owns the currency STRING while the field prefixes '
        'a hardcoded dollar', (WidgetTester tester) async {
      await pumpPreview(tester, goodsCostScreenCurrencyLbp);

      // 40_GUARDRAILS_ARCH §5, quoted above `_label`: no hardcoded currency.
      expect(find.text(_kLbpLabel), findsOneWidget);
      // …and `prefixIcon: Icon(Icons.attach_money)` sits in the same slot.
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
    testWidgets('a read still in flight is INDISTINGUISHABLE from a read that '
        'failed', (WidgetTester tester) async {
      await pumpPreview(tester, goodsCostScreenCurrencyPending);

      expect(find.text(_kNeutralLabel), findsOneWidget);
      expect(find.text(_kUsdLabel), findsNothing);
      // No spinner, no skeleton, no disabled field: nothing anywhere says a
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.widget<OmdsTextField>(find.byType(OmdsTextField)).enabled,
          isTrue);
    });

    testWidgets('a failed read degrades the label and blocks nothing', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, goodsCostScreenCurrencyUnavailable);

      // Deliberate: `loadCurrency` swallows the failure so cost entry is never
      expect(find.text(_kNeutralLabel), findsOneWidget);
      expect(_error, findsNothing);
      expect(_cta, findsOneWidget);
    });

    testWidgets('the only way off this screen is a leading arrow the ROUTER '
        'supplies', (WidgetTester tester) async {
      await pumpPreview(tester, goodsCostScreenCurrencyUsd);

      // `OMDSAppBar` leaves `showBackButton` at its `false` default, so the
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
      expect(find.text(_kNetworkCopy), findsOneWidget);
      expect(find.text(_kValidationCopy), findsNothing);
    });

    testWidgets('the client never validates the amount — a negative cost is '
        'sent to the gateway to be rejected there', (WidgetTester tester) async {
      await pumpPreview(tester, goodsCostScreenRecordRejected);

      await _typeAndConfirm(tester, '-5');

      // `-5` parses, so it is submitted; the 422 comes back from the fixture,
      expect(find.text(_kValidationCopy), findsOneWidget);
    });

    // A record in flight cannot be settled: the CTA renders
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
      expect(
        tester.widget<OmdsTextField>(find.byType(OmdsTextField)).enabled,
        isFalse,
      );
      expect(_error, findsNothing);
    });

    // The screen's most surprising behaviour, one input per test so no state
    for (final String typed in const <String>['12,5', '١٢', 'abc', '12.5.6']) {
      testWidgets('"$typed" arms the CTA and the press does NOTHING', (
        WidgetTester tester,
      ) async {
        // Bound to REJECT the record, so anything that actually reached the
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
        expect(_error, findsNothing);
        expect(tester.widget<OmdsLoadingButton>(_cta).isLoading, isFalse);
        expect(find.byType(GoodsCostScreen), findsOneWidget);
        // Nothing popped either — the caller stand-in is still covered by the
        expect(_caller, findsNothing);
        // …and the rejected text is still sitting in the field, unmarked.
        expect(tester.widget<TextField>(_field).controller?.text, typed);
      });
    }
  });

  // `previewCanvas` pumps onto the 800 x 600 test surface, not the `size:` a
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
      expect(slack(tester), lessThan(50));
    });

    testWidgets('take a keyboard off the compact frame and the form '
        'overflows', (WidgetTester tester) async {
      // 568 minus a software keyboard: exactly what `resizeToAvoidBottomInset`
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
