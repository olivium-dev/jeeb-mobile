// Render tests for the CustomerProfileRows previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// The five states share one label set — they are the SAME eight rows, and the
// only prop is a bool — so `expectedText` alone cannot tell them apart the way
// it can for a widget whose copy changes. The `preview specifics` group below
// carries that weight instead: it pins the row COUNT, the pinned width and the
// pinned text scale, which is what actually distinguishes these five.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/customer_profile/presentation/widgets/customer_profile_row.dart';
import 'package:jeeb_mobile/features/customer_profile/presentation/widgets/customer_profile_rows.dart';
import 'package:jeeb_mobile/previews/customer_profile/customer_profile_rows_preview.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'CustomerProfileRows',
    const <String, Widget Function()>{
      'Client · 390': customerProfileRowsClient,
      'Jeeber · register hidden': customerProfileRowsJeeber,
      'Narrow 320': customerProfileRowsNarrowPhone,
      '200% text · 390': customerProfileRowsLargeText,
      'Jeeber narrow · 200% text': customerProfileRowsJeeberNarrowLargeText,
    },
    expectedText: const <String, String>{
      // Only the two `showRegister` states can render these.
      'Client · 390': 'Register as a delivery',
      '200% text · 390': 'Register',
      // Rows every state carries, one each, so no two states are pinned on the
      // same string.
      'Jeeber · register hidden': 'Sign out',
      'Narrow 320': 'Saved addresses',
      'Jeeber narrow · 200% text': 'Contact us',
    },
  );

  group('CustomerProfileRows preview specifics', () {
    testWidgets('client renders 8 rows including the register pill', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, customerProfileRowsClient);

      expect(find.byType(CustomerProfileRow), findsNWidgets(8));
      expect(find.text('Register'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('customer_profile_register_delivery_row'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('jeeber drops the register row entirely (JM-035 AC2)', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, customerProfileRowsJeeber);

      expect(find.byType(CustomerProfileRow), findsNWidgets(7));
      expect(find.text('Register as a delivery'), findsNothing);
      expect(find.text('Register'), findsNothing);
      expect(
        find.bySemanticsIdentifier('customer_profile_register_delivery_row'),
        findsNothing,
      );
      // The rest of the Account section stays — hiding the row must not take
      // the section with it.
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Password and security'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the narrow preview really is 320 pt wide under test', (
      WidgetTester tester,
    ) async {
      // The render harness pumps an 800 pt surface. If the width were left to
      // the canvas `size`, this state would lay out at 800 pt here and be
      // indistinguishable from the default one.
      await pumpPreview(tester, customerProfileRowsNarrowPhone);
      expect(tester.getSize(find.byType(CustomerProfileRows)).width, 320.0);

      await pumpPreview(tester, customerProfileRowsClient);
      expect(tester.getSize(find.byType(CustomerProfileRows)).width, 390.0);
    });

    testWidgets('the 200% preview really renders at 2x under test', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, customerProfileRowsLargeText);
      final double scaled = tester.getSize(find.text('Sign out')).height;

      await pumpPreview(tester, customerProfileRowsClient);
      final double normal = tester.getSize(find.text('Sign out')).height;

      expect(scaled, greaterThan(normal * 1.5));
    });

    testWidgets('at 200% the register label yields all its width to the pill', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, customerProfileRowsClient);
      final double label1x =
          tester.getSize(find.text('Register as a delivery')).width;
      final double pill1x = tester.getSize(find.text('Register')).width;

      await pumpPreview(tester, customerProfileRowsLargeText);
      final double label2x =
          tester.getSize(find.text('Register as a delivery')).width;
      final double pill2x = tester.getSize(find.text('Register')).width;

      // The pill is intrinsically sized and grows with the text; the label is
      // the Expanded child and pays for it. Same phone width, opposite signs.
      expect(pill2x, greaterThan(pill1x));
      expect(label2x, lessThan(label1x));
    });

    // DOCUMENTED DEFECT, not a desired behaviour. On a 320 pt phone at the 200%
    // accessibility ceiling the register row overflows its trailing edge and the
    // label is allotted zero width — see the notes on
    // `customerProfileRowsNarrowPhone`. Pinned so the defect cannot be widened
    // silently; DELETE this test when the row is fixed (it will start failing,
    // which is the point).
    testWidgets('DEFECT: register row overflows at 320 pt + 200% text', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpPreview(tester, customerProfileRowsNarrowPhone);

      expect(
        tester.takeException().toString(),
        contains('overflowed'),
        reason: 'If this now passes cleanly the row was fixed — delete this '
            'test and the defect notes in the preview.',
      );
    });

    testWidgets('the same width and scale are clean without the pill', (
      WidgetTester tester,
    ) async {
      // The control for the defect above: 320 pt, 200%, one row fewer.
      await pumpPreview(tester, customerProfileRowsJeeberNarrowLargeText);

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(CustomerProfileRows)).width, 320.0);
      expect(find.byType(CustomerProfileRow), findsNWidgets(7));
    });
  });
}
