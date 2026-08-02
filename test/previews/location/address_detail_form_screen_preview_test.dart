// Render tests for the AddressDetailFormScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand.
//
// This is a SCREEN, and every preview pins its own device window inside the
// tree (the render tests all pump onto one fixed 800 x 600 surface, so the
// annotation `size` alone would measure six states at the same box). The
// shared suite therefore addresses each state by its caption, and the
// `preview specifics` group pins the two things the captions cannot: that each
// frame really is the window it claims, and that the add/edit gate the whole
// screen turns on — JEBV4-176's "no Save without a REAL dropped pin" — is the
// state actually being drawn.
//
// The `documented defects` group guards behaviour the previews exposed and the
// screen has NOT fixed. If one starts failing because the screen was fixed,
// delete the guard — do not restore the expectation.

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
      // this ever comes up enabled, the fabricated-Beirut-coordinate defect is
      // back and a customer can save an address they never pointed at.
      expect(find.byType(CaptureLocationPin), findsNothing);
      expect(_saveButton(tester).isEnabled, isFalse);
      expect(_saveButton(tester).isLoading, isFalse);

      // Nothing is pre-filled — the fields carry the empty string, not a hint
      // masquerading as a value.
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
      // saved point, so Save is live for the same reason the edit path's is.
      expect(_saveButton(tester).isEnabled, isTrue);
    });

    testWidgets('session-resolving state is the spinner branch, not the form', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, addressDetailFormScreenSessionResolving);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // The `FutureBuilder` waiting branch returns its own bare Scaffold, so
      // none of the form's chrome exists yet.
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
      // creating an address or editing one.
      expect(find.text(_screenTitle), findsOneWidget);
      expect(find.text(_saveCta), findsOneWidget);
    });

    testWidgets('the reason Save is disabled is never drawn', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, addressDetailFormScreenAddPath);

      // `_PinPreview` puts "Pick a location on the map" in a Semantics label
      // and nowhere else, so the only on-screen signal that a pin is required
      // is a dimmed button.
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
      // screen: `AddressFormL10n` writes its hints as finished values rather
      // than as formats, and `InputDecorator` draws them in the field. Only
      // the ink colour separates "you typed this" from "we suggested this".
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
      // renders neither a category picker nor a default toggle: five text
      // fields and the map band are the whole form. Every address created on
      // the add path is therefore saved as `home`.
      expect(find.byType(OmdsTextField), findsNWidgets(5));
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(SegmentedButton<Object?>), findsNothing);
    });
  });
}
