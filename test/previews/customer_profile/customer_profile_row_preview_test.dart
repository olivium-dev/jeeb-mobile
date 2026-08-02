// Render tests for the CustomerProfileRow previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// The specifics group below pins the two structural claims the previews are
// documenting: the label truncates instead of wrapping (so the row never grows
// past 56dp), and the trailing "Register" pill is charged to the label rather
// than to the row. Both are measured off the render tree, so they hold under
// the test font as well as under bundled Inter.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/customer_profile/presentation/widgets/customer_profile_row.dart';
import 'package:jeeb_mobile/previews/customer_profile/customer_profile_row_preview.dart';

import '../preview_test_harness.dart';

/// Width the [Expanded] label was actually given, and the width it wanted.
({double given, double wanted}) _labelBudget(WidgetTester tester, String text) {
  final RenderParagraph paragraph =
      tester.renderObject<RenderParagraph>(find.text(text));
  return (
    given: paragraph.size.width,
    wanted: paragraph.getMaxIntrinsicWidth(double.infinity),
  );
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'CustomerProfileRow',
    const <String, Widget Function()>{
      'Chevron row · localized': customerProfileRowDefault,
      'Register pill trailing': customerProfileRowRegisterPill,
      'Long label truncates': customerProfileRowLongLabel,
      'Long Arabic label truncates': customerProfileRowLongArabicLabel,
      'Narrow phone · pill squeeze': customerProfileRowNarrowPhone,
      'Sign out · destructive': customerProfileRowSignOut,
    },
    expectedText: const <String, String>{
      'Chevron row · localized': 'Password and security',
      'Register pill trailing': 'Register as a delivery',
      'Long label truncates': kLongLabel,
      'Long Arabic label truncates': kLongArabicLabel,
      'Narrow phone · pill squeeze': kNarrowPhoneCaption,
      'Sign out · destructive': 'Sign out',
    },
  );

  group('CustomerProfileRow preview specifics', () {
    testWidgets('labels resolve from the ARB, not English literals', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        customerProfileRowDefault,
        locale: const Locale('ar'),
      );

      expect(find.text('كلمة المرور والأمان'), findsOneWidget);
      expect(find.text('Password and security'), findsNothing);
    });

    testWidgets('a long label truncates instead of wrapping — the row stays '
        '56dp', (WidgetTester tester) async {
      await pumpPreview(tester, customerProfileRowLongLabel);

      final ({double given, double wanted}) budget =
          _labelBudget(tester, kLongLabel);
      expect(
        budget.wanted,
        greaterThan(budget.given),
        reason: 'the state is only interesting while the label overflows',
      );
      // No `maxLines`, so `TextOverflow.ellipsis` caps the paragraph at one
      // line: the tail is dropped rather than reflowed onto a second line.
      expect(tester.getSize(find.byType(CustomerProfileRow)).height, 56.0);
    });

    testWidgets('the Arabic label truncates on its own terms', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        customerProfileRowLongArabicLabel,
        locale: const Locale('ar'),
      );

      final ({double given, double wanted}) budget =
          _labelBudget(tester, kLongArabicLabel);
      expect(budget.wanted, greaterThan(budget.given));
      expect(tester.getSize(find.byType(CustomerProfileRow)).height, 56.0);
    });

    testWidgets('the Register pill is charged to the label, not to the row', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, customerProfileRowSignOut);
      final double chevronBudget = _labelBudget(tester, 'Sign out').given;

      await pumpPreview(tester, customerProfileRowRegisterPill);
      final double pillBudget =
          _labelBudget(tester, 'Register as a delivery').given;

      // Same 390dp row; the pill's intrinsic width comes straight off the
      // Expanded label's budget, which is why the register row reaches the
      // truncation ceiling before its seven chevron siblings.
      expect(pillBudget, lessThan(chevronBudget));
      expect(tester.getSize(find.byType(CustomerProfileRow)).height, 56.0);
    });

    testWidgets('the narrow state is the 320dp row, not the 390dp one', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, customerProfileRowNarrowPhone);
      expect(tester.getSize(find.byType(CustomerProfileRow)).width, 320.0);

      await pumpPreview(tester, customerProfileRowRegisterPill);
      expect(tester.getSize(find.byType(CustomerProfileRow)).width, 390.0);
      expect(find.text(kNarrowPhoneCaption), findsNothing);
    });
  });
}
