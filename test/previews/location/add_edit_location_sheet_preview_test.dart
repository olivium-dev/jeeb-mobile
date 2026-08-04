// Render tests for the AddEditLocationSheet previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/location/presentation/widgets/add_edit_location_sheet.dart';

import '../preview_test_harness.dart';

/// The four form boxes, in build order: label, address, latitude, longitude.
List<String> _fieldValues(WidgetTester tester) => tester
    .widgetList<EditableText>(find.byType(EditableText))
    .map((EditableText e) => e.controller.text)
    .toList(growable: false);

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'AddEditLocationSheet',
    const <String, Widget Function()>{
      'Add · empty': addEditLocationSheetAddEmpty,
      'Edit · seeded home': addEditLocationSheetEditHome,
      'Edit · no address': addEditLocationSheetNoAddress,
      'Edit · long label': addEditLocationSheetLongLabel,
      'Edit · raw GPS precision': addEditLocationSheetRawGpsPrecision,
      'Modal presentation · Arabic label': addEditLocationSheetInModalRoute,
    },
    expectedText: const <String, String>{
      // The address box — 'Home' would not do, the Home chip renders it too.
      'Edit · seeded home': 'Sassine Square, Ashrafieh',
      // The label box: the one state whose address box is empty.
      'Edit · no address': 'Office',
      'Edit · long label':
          'Grandmother building, third entrance behind the pharmacy',
      // Seventeen characters of raw `double.toString()` in a half-width box.
      'Edit · raw GPS precision': '33.88691234567891',
      // Arabic label typed into the English UI, only in the modal state.
      'Modal presentation · Arabic label': 'بيت تيتا',
    },
  );

  group('AddEditLocationSheet preview specifics', () {
    testWidgets('Add · empty is the only state with a disabled Save', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, addEditLocationSheetAddEmpty);

      // Four empty boxes: nothing leaked in from a fixture, and `_isValid` is
      expect(_fieldValues(tester), <String>['', '', '', '']);
      expect(
        tester.widget<OmdsPrimaryButton>(find.byType(OmdsPrimaryButton))
            .isEnabled,
        isFalse,
        reason: 'the disabled CTA is the only guard against saving a location '
            'with no label and unparseable coordinates',
      );
      expect(find.text('Edit location'), findsNothing);
    });

    testWidgets('every Edit state enables Save and drops the Add title', (
      WidgetTester tester,
    ) async {
      for (final Widget Function() preview in <Widget Function()>[
        addEditLocationSheetEditHome,
        addEditLocationSheetNoAddress,
        addEditLocationSheetLongLabel,
        addEditLocationSheetRawGpsPrecision,
      ]) {
        await pumpPreview(tester, preview);

        expect(
          tester.widget<OmdsPrimaryButton>(find.byType(OmdsPrimaryButton))
              .isEnabled,
          isTrue,
        );
        expect(find.text('Add new location'), findsNothing);
      }
    });

    testWidgets('the heading and the CTA render the same string', (
      WidgetTester tester,
    ) async {
      // Pinned deliberately: `_SheetTitle` and the primary button are both fed
      await pumpPreview(tester, addEditLocationSheetAddEmpty);
      expect(find.text('Add new location'), findsNWidgets(2));

      await pumpPreview(tester, addEditLocationSheetEditHome);
      expect(find.text('Edit location'), findsNWidgets(2));
    });

    testWidgets('seeded home fills all four boxes from the wire values', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, addEditLocationSheetEditHome);

      // Label and address are not crossed, and the coordinates arrive as the
      expect(
        _fieldValues(tester),
        <String>['Home', 'Sassine Square, Ashrafieh', '33.8869', '35.5131'],
      );
      // 'Home' twice: the label box AND the selected category chip.
      expect(find.text('Home'), findsNWidgets(2));
    });

    testWidgets('no-address state leaves the box empty, never "null"', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, addEditLocationSheetNoAddress);

      expect(
        _fieldValues(tester),
        <String>['Office', '', '33.8938', '35.5018'],
      );
      expect(find.text('null'), findsNothing);
      // Its own category, not the Home default `initState` falls back to.
      expect(find.text('Work'), findsOneWidget);
    });

    testWidgets('modal preview shows the real bottom-sheet frame', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, addEditLocationSheetInModalRoute);

      // Pushed through AddEditLocationSheet.show, not hand-placed: the only
      expect(find.byType(BottomSheet), findsOneWidget);
      final Rect sheet = tester.getRect(find.byType(AddEditLocationSheet));
      final Rect host = tester.getRect(find.byType(Navigator).last);
      expect(sheet.bottom, host.bottom, reason: 'sheet must be bottom-anchored');
    });

    testWidgets('the bare previews carry no bottom-sheet frame', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, addEditLocationSheetEditHome);

      expect(find.byType(BottomSheet), findsNothing);
    });
  });
}
