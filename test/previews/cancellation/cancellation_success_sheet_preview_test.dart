// Render tests for the CancellationSuccessSheet previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// One deviation from that template, on purpose. `CancellationSuccessSheet.build`
// never reads its `result`, so three of the five previews below render the SAME
// two strings ("Delivery cancelled" / "Done"). Binding `expectedText` to widget
// output could therefore not tell them apart — it would be exactly the weak
// assertion the harness warns about. So `expectedText` binds to each preview's
// caption, which is preview scaffolding, and the per-state contract is asserted
// underneath by measurement:
//
//   * the three payload previews must render IDENTICAL strings (the drop, made
//     into a failing condition if anyone ever fixes it — see the note on that
//     test), and
//   * the two geometry previews must lay the sheet out at their own width and
//     their own bottom inset.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/cancellation/presentation/widgets/cancellation_success_sheet.dart';

import '../preview_test_harness.dart';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Cancelled outright': cancellationSuccessSheetCancelled,
  'Pending admin approval': cancellationSuccessSheetPendingApproval,
  'Jeeber 3rd strike · red tier': cancellationSuccessSheetJeeberRestricted,
  'Narrow phone · 320 pt': cancellationSuccessSheetNarrowPhone,
  'Gesture-bar inset · 34 pt': cancellationSuccessSheetGestureBarInset,
};

/// The three previews that differ only in the [CancellationResult] they are
/// handed.
const List<String> _payloadStates = <String>[
  'Cancelled outright',
  'Pending admin approval',
  'Jeeber 3rd strike · red tier',
];

/// Every string the SHEET renders, in tree order. Excludes the preview
/// captions, which live outside `CancellationSuccessSheet`.
List<String> _sheetStrings(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byType(CancellationSuccessSheet),
        matching: find.byType(Text),
      ),
    )
    .map((Text text) => text.data ?? '')
    .toList();

Rect _sheetRect(WidgetTester tester) =>
    tester.getRect(find.byType(CancellationSuccessSheet));

Rect _ctaRect(WidgetTester tester) =>
    tester.getRect(find.byType(OmdsPrimaryButton));

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'CancellationSuccessSheet',
    _previews,
    expectedText: const <String, String>{
      'Cancelled outright': 'Payload: weeklyCount 1, cancelled outright',
      'Pending admin approval': 'Payload: pendingApproval = true',
      'Jeeber 3rd strike · red tier': 'Payload: strikeCount 3, restriction red',
      'Narrow phone · 320 pt': 'Geometry: 320 pt narrow phone',
      'Gesture-bar inset · 34 pt': 'Geometry: 34 pt gesture-bar inset',
    },
  );

  group('CancellationSuccessSheet preview specifics', () {
    // The assertion the caption-based `expectedText` above cannot make, stated
    // the only way it can be stated honestly: three materially different
    // gateway payloads produce one rendering.
    //
    // `pendingApproval: true` means the cancellation is awaiting admin review;
    // `restriction: 'red'` means the jeeber has just been gated out of the feed.
    // Neither reaches the screen. If someone ever teaches the sheet to read
    // `result`, this test fails — and that failure is the signal to delete it,
    // not to make the payloads match again.
    testWidgets('all three payloads render identical copy — `result` is dead', (
      WidgetTester tester,
    ) async {
      final List<List<String>> rendered = <List<String>>[];
      for (final String state in _payloadStates) {
        await pumpPreview(tester, _previews[state]!);
        rendered.add(_sheetStrings(tester));
      }

      expect(rendered.first, <String>['Delivery cancelled', 'Done']);
      for (int i = 1; i < rendered.length; i++) {
        expect(
          rendered[i],
          rendered.first,
          reason: '${_payloadStates[i]} carries a consequence the user is '
              'never shown: CancellationSuccessSheet.build ignores `result`',
        );
      }
    });

    testWidgets('the payload previews are also pixel-identical in layout', (
      WidgetTester tester,
    ) async {
      final Set<Size> boxes = <Size>{};
      for (final String state in _payloadStates) {
        await pumpPreview(tester, _previews[state]!);
        boxes.add(_sheetRect(tester).size);
      }

      expect(
        boxes,
        hasLength(1),
        reason: 'nothing about the payload reaches layout either',
      );
    });

    testWidgets('each geometry preview lays the sheet out at its own width', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, cancellationSuccessSheetCancelled);
      final Rect phone = _sheetRect(tester);
      expect(phone.width, 390);

      await pumpPreview(tester, cancellationSuccessSheetNarrowPhone);
      final Rect narrow = _sheetRect(tester);
      expect(narrow.width, 320);

      // The title is a bare `Text` with no ellipsis, so a wrap would grow the
      // sheet. At 100% "Delivery cancelled" clears 320 pt on one line, which is
      // why the two heights match — and what this pins.
      expect(
        narrow.height,
        phone.height,
        reason: 'the title must still fit one line on the narrowest phone',
      );
    });

    testWidgets('the gesture-bar inset lifts the CTA clear of the bottom edge', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, cancellationSuccessSheetCancelled);
      final double flatGap = _sheetRect(tester).bottom - _ctaRect(tester).bottom;
      final double flatHeight = _sheetRect(tester).height;
      // `Padding(EdgeInsets.all(Spacing.large))` and nothing else.
      expect(flatGap, 20);

      await pumpPreview(tester, cancellationSuccessSheetGestureBarInset);
      final double insetGap =
          _sheetRect(tester).bottom - _ctaRect(tester).bottom;

      // The widget's own SafeArea absorbs the 34 pt home indicator on top of
      // the 20 pt gutter. If this ever reads 20 again, either the SafeArea was
      // dropped or something above it swallowed `MediaQuery.padding` — which is
      // how a CTA ends up under a home indicator.
      expect(insetGap, 54);
      expect(_sheetRect(tester).height, flatHeight + 34);
    });

    testWidgets('copy is localized; the preview caption deliberately is not', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        cancellationSuccessSheetCancelled,
        locale: const Locale('ar'),
      );

      expect(_sheetStrings(tester), <String>['تم إلغاء التوصيل', 'تم']);
      expect(find.text('Delivery cancelled'), findsNothing);
      // Scaffolding, not widget output — it names the fixture, so it stays EN.
      expect(find.text('Payload: weeklyCount 1, cancelled outright'),
          findsOneWidget);
    });

    // The preview matrix renders 'Cancelled outright' and 'Narrow phone' at
    // 200% text, but the canvas is the only place that happens; these render
    // tests run at 1x, so the accessibility ceiling would otherwise be asserted
    // nowhere.
    testWidgets('at 200% text the sheet grows without overflowing', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, cancellationSuccessSheetNarrowPhone);
      final double baseHeight = _sheetRect(tester).height;

      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        previewCanvas(cancellationSuccessSheetNarrowPhone, const Locale('en')),
      );
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: 'unlike LogoutDeleteConfirmSheet, this sheet has one short '
            'title and a four-letter CTA, so `mainAxisSize.min` has room',
      );
      expect(_sheetRect(tester).height, greaterThan(baseHeight));
    });

    testWidgets('the check mark does not scale with the text it heads', (
      WidgetTester tester,
    ) async {
      // Height, not size: the Column stretches every child, so the icon's box
      // is content-width wide and only its height carries the 56 pt.
      await pumpPreview(tester, cancellationSuccessSheetCancelled);
      expect(tester.getSize(find.byIcon(Icons.check_circle_outline)).height, 56);
      final double baseTitle =
          tester.getSize(find.text('Delivery cancelled')).height;

      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        previewCanvas(cancellationSuccessSheetCancelled, const Locale('en')),
      );
      await tester.pumpAndSettle();

      // A bare `Icon(size: 56)` only text-scales when the ambient
      // `IconThemeData.applyTextScaling` is set, and it is not. At 200% the
      // title grows around a glyph that does not move, so the element carrying
      // "it worked" stops being the largest thing on the sheet.
      expect(tester.getSize(find.byIcon(Icons.check_circle_outline)).height, 56);
      expect(
        tester.getSize(find.text('Delivery cancelled')).height,
        greaterThan(baseTitle * 1.9),
      );
    });

    testWidgets('the Done CTA keeps a 48 pt target on the narrowest phone', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, cancellationSuccessSheetNarrowPhone);

      final Rect cta = _ctaRect(tester);
      expect(cta.height, 48, reason: 'Sizes.fourXLarge, fixed at every scale');
      // Stretched by the Column's `crossAxisAlignment.stretch` to the full
      // content width: 320 - 2 * Spacing.large.
      expect(cta.width, 280);

      expect(
        find.bySemanticsLabel('Done'),
        findsOneWidget,
        reason: 'cancellation_sheet_done_cta must stay announced as a button',
      );
    });
  });
}
