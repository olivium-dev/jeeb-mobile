// Render tests for the AddressDetailFormScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/location/presentation/screens/address_detail_form_screen.dart';
import 'package:jeeb_mobile/features/location/presentation/widgets/capture_location_pin.dart';

import '../preview_test_harness.dart';

/// Exact ARB copy, so a reworded string breaks the test instead of silently
/// unpinning the preview.
const String _screenTitle = 'Address details';
const String _saveCta = 'Save address';

/// The device windows the previews declare, restated here so a preview wired
/// to the wrong frame fails instead of looking plausible.
const Size _phoneFrame = Size(390, 844);
const Size _compactFrame = Size(320, 568);

/// The save CTA as the screen builds it.
OmdsLoadingButton _saveButton(WidgetTester tester) =>
    tester.widget<OmdsLoadingButton>(find.byType(OmdsLoadingButton));

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'AddressDetailFormScreen',
    const <String, Widget Function()>{
      'Add path': addressDetailFormScreenAddPath,
      'Edit path': addressDetailFormScreenEditPath,
      'Longest content': addressDetailFormScreenLongestContent,
      'Session resolving': addressDetailFormScreenSessionResolving,
      'Compact phone': addressDetailFormScreenCompactPhone,
      'Text ceiling': addressDetailFormScreenTextCeiling,
    },
    expectedText: const <String, String>{
      'Add path': 'Add path · nothing picked yet · Save gated on a real pin',
      'Edit path': 'Edit path · saved pin adopted · Save enabled',
      'Longest content':
          'Longest content · uncapped label, 4-sentence notes',
      'Session resolving': 'Session resolving · keychain read still pending',
      'Compact phone': 'Compact phone · 320 x 568 · saved address',
      'Text ceiling': 'Text ceiling · EN 200% · saved address',
    },
  );

  group('AddressDetailFormScreen preview specifics', () {
    testWidgets('add path draws an EMPTY form with no pin and Save disabled', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, addressDetailFormScreenAddPath);

      // The JEBV4-176 gate: no pin was dropped, so the CTA must be dead. If
      expect(find.byType(CaptureLocationPin), findsNothing);
      expect(_saveButton(tester).isEnabled, isFalse);
      expect(_saveButton(tester).isLoading, isFalse);

      // Nothing is pre-filled — the fields carry the empty string, not a hint
      expect(find.text('Home'), findsNothing);
      expect(find.text('Nassif Building'), findsNothing);
    });

    testWidgets('edit path opens on the saved address, pin and all', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, addressDetailFormScreenEditPath);

      expect(find.byType(CaptureLocationPin), findsOneWidget);
      expect(_saveButton(tester).isEnabled, isTrue);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Nassif Building'), findsOneWidget);
      expect(find.text('2nd floor, Apt 5'), findsOneWidget);
      expect(find.text('+961 3 000 077'), findsOneWidget);
    });

    testWidgets('longest content fills every field from ONE fixture', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, addressDetailFormScreenLongestContent);

      expect(
        find.text(
          "Grandmother's apartment above the Sunday vegetable market",
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('the main door is locked after 6pm'),
        findsOneWidget,
      );
      // Long content does not un-gate the CTA: the fixture carries a real
      expect(_saveButton(tester).isEnabled, isTrue);
    });

    testWidgets('session-resolving state is the spinner branch, not the form', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, addressDetailFormScreenSessionResolving);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // The `FutureBuilder` waiting branch returns its own bare Scaffold, so
      expect(find.text(_screenTitle), findsNothing);
      expect(find.byType(OmdsLoadingButton), findsNothing);
      expect(find.byType(CaptureLocationPin), findsNothing);
    });

    testWidgets('each state renders in the device window it names', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, addressDetailFormScreenEditPath);
      expect(tester.getSize(find.byType(AddressDetailFormScreen)), _phoneFrame);

      await pumpPreview(tester, addressDetailFormScreenCompactPhone);
      expect(
        tester.getSize(find.byType(AddressDetailFormScreen)),
        _compactFrame,
      );
    });
  });

  group('AddressDetailFormScreen documented defects', () {
    testWidgets('add and edit are the same screen with different text in it', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, addressDetailFormScreenAddPath);
      expect(find.text(_screenTitle), findsOneWidget);
      expect(find.text(_saveCta), findsOneWidget);

      await pumpPreview(tester, addressDetailFormScreenEditPath);
      // Same title, same CTA copy: nothing DRAWN tells a user whether they are
      expect(find.text(_screenTitle), findsOneWidget);
      expect(find.text(_saveCta), findsOneWidget);
    });

    testWidgets('the reason Save is disabled is never drawn', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, addressDetailFormScreenAddPath);

      // `_PinPreview` puts "Pick a location on the map" in a Semantics label
      expect(_saveButton(tester).isEnabled, isFalse);
      expect(find.text('Pick a location on the map'), findsNothing);
      expect(
        find.bySemanticsLabel('Pick a location on the map'),
        findsOneWidget,
      );
    });

    testWidgets('the empty add form is covered in what look like values', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, addressDetailFormScreenAddPath);

      // Every controller is empty, yet three complete-looking answers are on
      expect(_saveButton(tester).isEnabled, isFalse);
      expect(find.text('4th floor, Apt 12'), findsOneWidget);
      expect(find.text('Ring twice; blue door.'), findsOneWidget);
      expect(find.text('Home, Office, etc.'), findsOneWidget);
    });

    testWidgets('no control exists for the two fields the form persists', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, addressDetailFormScreenEditPath);

      // `_category` and `isDefault` are read in `_onSave` but `_FormBody`
      expect(find.byType(OmdsTextField), findsNWidgets(5));
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(SegmentedButton<Object?>), findsNothing);
    });
  });
}
