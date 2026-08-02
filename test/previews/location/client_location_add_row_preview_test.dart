// Render tests for the ClientLocationAddRow previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the shared template — see
// `test/previews/preview_test_harness.dart`.
//
// Every state of this row is a string, and four of the five look alike at a
// glance (label on the start edge, navy "+" on the end edge). `expectedText`
// therefore pins a DIFFERENT string per state — a suite that only asked "did
// something render" would pass even if the file rendered the default row five
// times.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/location/presentation/widgets/client_location_add_row.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'ClientLocationAddRow',
    const <String, Widget Function()>{
      'Localized default': clientLocationAddRowDefault,
      'Long label truncates': clientLocationAddRowLongLabel,
      'Long Arabic label truncates': clientLocationAddRowLongArabicLabel,
      'Narrow phone · 320dp': clientLocationAddRowNarrowPhone,
      'Locked · create in flight': clientLocationAddRowLocked,
    },
    expectedText: const <String, String>{
      'Localized default': 'New Location',
      'Long label truncates': clientLocationAddRowLongLabelText,
      'Long Arabic label truncates': clientLocationAddRowLongArabicLabelText,
      'Narrow phone · 320dp': 'Add another delivery location',
      'Locked · create in flight': 'Locked · create in flight',
    },
  );

  group('ClientLocationAddRow preview specifics', () {
    ClientLocationAddRow rowIn(WidgetTester tester) =>
        tester.widget<ClientLocationAddRow>(
          find.byType(ClientLocationAddRow),
        );

    // The default preview must be wired the way `ClientLocationScreen` wires
    // it, not with the widget's legacy default id — the JM-024 contract id is
    // what 63_W1_TEST_PLAN §2.3 and the delivery-create tests look for.
    testWidgets('the default row carries the JM-024 contract id', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientLocationAddRowDefault);

      expect(rowIn(tester).identifier, 'location_select_new_location_cta');
      expect(rowIn(tester).identifier, isNot('client_location_add_new'));
    });

    // Both strings come from the ARB, and the a11y label is the ONLY string a
    // screen-reader user hears (the visible label sits under ExcludeSemantics).
    // A preview that hardcoded English would render an identical canvas while
    // hiding a missing translation, so pin both locales.
    testWidgets('label and a11y label follow the ambient locale', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientLocationAddRowDefault);
      expect(rowIn(tester).label, 'New Location');
      expect(rowIn(tester).addSemanticLabel, 'Add a new location');

      await pumpPreview(
        tester,
        clientLocationAddRowDefault,
        locale: const Locale('ar'),
      );
      expect(rowIn(tester).label, 'موقع جديد');
      expect(rowIn(tester).addSemanticLabel, 'إضافة موقع جديد');
    });

    // The AR RTL rendering of every preview is only worth looking at if the row
    // actually mirrors: label on the start edge, "+" on the end edge. The row
    // uses `EdgeInsetsDirectional` and a plain `Row`, so this holds today —
    // pinned because a future `EdgeInsets.only(left:)` would not fail anything
    // else in the suite.
    testWidgets('the row mirrors: label starts, "+" ends', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientLocationAddRowDefault);
      expect(
        tester.getTopLeft(find.text('New Location')).dx,
        lessThan(tester.getTopLeft(find.byIcon(Icons.add)).dx),
      );

      await pumpPreview(
        tester,
        clientLocationAddRowDefault,
        locale: const Locale('ar'),
      );
      expect(
        tester.getTopLeft(find.text('موقع جديد')).dx,
        greaterThan(tester.getTopLeft(find.byIcon(Icons.add)).dx),
      );
    });

    // The row itself is the tap target (the 40dp circle is decoration inside a
    // 48dp box), so the row — not the circle — has to clear Material's minimum.
    testWidgets('the whole row clears the minimum tap target', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientLocationAddRowDefault);

      final Size row = tester.getSize(find.byType(ClientLocationAddRow));
      expect(row.height, greaterThanOrEqualTo(kMinInteractiveDimension));
    });

    // What the long-label previews exist to show, and it is NOT "the row grows":
    // `TextOverflow.ellipsis` with no `maxLines` caps the paragraph at one line,
    // so an over-wide label is truncated rather than reflowed. Measured against
    // the default label's own single line rather than a hardcoded pixel height,
    // so this keeps meaning the same thing if the text theme changes.
    testWidgets('the long label truncates onto one line, never wraps', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientLocationAddRowDefault);
      final double oneLine = tester.getSize(find.text('New Location')).height;

      await pumpPreview(tester, clientLocationAddRowLongLabel);
      final Text label = tester.widget<Text>(find.text(clientLocationAddRowLongLabelText));
      expect(label.overflow, TextOverflow.ellipsis);
      expect(label.maxLines, isNull, reason: 'ellipsis without maxLines');

      final RenderParagraph paragraph =
          tester.renderObject<RenderParagraph>(find.text(clientLocationAddRowLongLabelText));
      expect(
        paragraph.size.height,
        oneLine,
        reason: 'still one line — the ellipsis caps the paragraph',
      );
      expect(
        paragraph.getMaxIntrinsicWidth(double.infinity),
        greaterThan(paragraph.size.width),
        reason: 'the label wants more width than the row gives it',
      );
      // And the row stays a row: the trailing button is not pushed off.
      expect(tester.getSize(find.byType(ClientLocationAddRow)).height, 64);
    });

    testWidgets('the long Arabic label truncates the same way', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        clientLocationAddRowDefault,
        locale: const Locale('ar'),
      );
      final double oneLine = tester.getSize(find.text('موقع جديد')).height;

      await pumpPreview(
        tester,
        clientLocationAddRowLongArabicLabel,
        locale: const Locale('ar'),
      );
      final RenderParagraph paragraph =
          tester.renderObject<RenderParagraph>(find.text(clientLocationAddRowLongArabicLabelText));
      expect(paragraph.size.height, oneLine);
      expect(
        paragraph.getMaxIntrinsicWidth(double.infinity),
        greaterThan(paragraph.size.width),
      );
    });

    // The accessibility edge the EN-200% rendering of the narrow preview shows:
    // the 48dp button and its 16dp gutter do not scale with text, and the label
    // cannot reflow, so on a 320dp phone at 2x the row's only affordance text is
    // what gets cut. Nothing here asserts a fix — it pins the fact so a future
    // `maxLines`/wrap change registers as a deliberate behaviour change.
    testWidgets('at 200% text the narrow row truncates its label', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpPreview(tester, clientLocationAddRowNarrowPhone);

      final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
        find.text('Add another delivery location'),
      );
      expect(
        paragraph.getMaxIntrinsicWidth(double.infinity),
        greaterThan(paragraph.size.width),
      );
      // The button keeps its full 48dp box while the text loses room.
      expect(tester.getSize(find.byType(ClientLocationAddRow)).width, 288);
    });

    // The narrow state only means something if it is actually narrow: a widget
    // test pumps an 800dp surface, so without the explicit SizedBox this would
    // silently become another wide preview.
    testWidgets('the narrow state pins a 320dp-class row width', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientLocationAddRowNarrowPhone);

      expect(tester.getSize(find.byType(ClientLocationAddRow)).width, 288);
    });

    // B-02b: while an order create is in flight the screen's `_SubmitLock`
    // dims the row AND swallows its taps. The preview reproduces both, with the
    // same token, or it is showing a state that cannot happen.
    testWidgets('the locked state is dimmed and non-interactive', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientLocationAddRowLocked);

      expect(
        find.ancestor(
          of: find.byType(ClientLocationAddRow),
          matching: find.byWidgetPredicate(
            (Widget w) => w is IgnorePointer && w.ignoring,
          ),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Opacity>(
              find
                  .ancestor(
                    of: find.byType(ClientLocationAddRow),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity,
        UIConstants.opacityDisabled,
      );
      // Still the real row underneath, not a stand-in.
      expect(rowIn(tester).label, 'New Location');
    });
  });
}
