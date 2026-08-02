// Render tests for the ClientLocationAddRow previews.

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
    testWidgets('the default row carries the JM-024 contract id', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientLocationAddRowDefault);

      expect(rowIn(tester).identifier, 'location_select_new_location_cta');
      expect(rowIn(tester).identifier, isNot('client_location_add_new'));
    });

    // Both strings come from the ARB, and the a11y label is the ONLY string a
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
    testWidgets('the whole row clears the minimum tap target', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientLocationAddRowDefault);

      final Size row = tester.getSize(find.byType(ClientLocationAddRow));
      expect(row.height, greaterThanOrEqualTo(kMinInteractiveDimension));
    });

    // What the long-label previews exist to show, and it is NOT "the row grows":
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
    testWidgets('the narrow state pins a 320dp-class row width', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientLocationAddRowNarrowPhone);

      expect(tester.getSize(find.byType(ClientLocationAddRow)).width, 288);
    });

    // B-02b: while an order create is in flight the screen's `_SubmitLock`
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
