// Render tests for the CustomerRegisterPill previews.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/customer_profile/presentation/widgets/customer_profile_row.dart';
import 'package:jeeb_mobile/features/customer_profile/presentation/widgets/customer_register_pill.dart';

import '../preview_test_harness.dart';

/// The pill's tappable core, keyed by the widget itself.
final Finder _pill = find.byKey(const Key('customer-profile-register-button'));

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'CustomerRegisterPill',
    const <String, Widget Function()>{
      'Pill alone': customerRegisterPillAlone,
      'In profile row': customerRegisterPillInRow,
      'Narrow phone': customerRegisterPillNarrowRow,
      'Beside chevron rows': customerRegisterPillBesideChevronRows,
      'Row at 200% text': customerRegisterPillRowAtLargeText,
      'Bounded parent': customerRegisterPillInBoundedParent,
    },
    expectedText: const <String, String>{
      'Pill alone': 'Pill alone · hugs its label, 40 dp tall',
      'In profile row': 'In profile row · 390 dp',
      'Narrow phone': 'Narrow phone · 320 dp',
      'Beside chevron rows': 'Beside chevron rows · alignment + weight',
      'Row at 200% text': 'Row at 200% text · pill stays 40 dp',
      'Bounded parent': 'Bounded parent · stretches, no longer a pill',
    },
  );

  group('CustomerRegisterPill preview specifics', () {
    testWidgets('the CTA is localized, not hardcoded English', (
      WidgetTester tester,
    ) async {
      // The pill's label is its entire content. If it ever regressed to a
      await pumpPreview(
        tester,
        customerRegisterPillInRow,
        locale: const Locale('ar'),
      );

      expect(find.text('تسجيل'), findsOneWidget);
      expect(find.text('Register'), findsNothing);
      expect(find.text('سجّل كموصِّل'), findsOneWidget);
    });

    testWidgets('adds no second announced button (JEBV4-98 / F10-F11)', (
      WidgetTester tester,
    ) async {
      // The pill and the row share one `onTap`. The widget excludes its own
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, customerRegisterPillInRow);

      final Finder rowFinder =
          find.bySemanticsIdentifier('customer_profile_register_delivery_row');
      expect(rowFinder, findsOneWidget);

      // The pill's text folds into the ROW's node rather than owning one.
      final SemanticsNode row = tester.getSemantics(rowFinder);
      expect(tester.getSemantics(find.text('Register')).id, row.id);

      // …and contributes no announced segment of its own. Asserted per segment
      expect(
        row.label.split('\n'),
        everyElement('Register as a delivery'),
        reason: 'the pill must not add a second "Register" announcement',
      );

      handle.dispose();
    });

    testWidgets('hugs its label in a Row but fills a bounded parent', (
      WidgetTester tester,
    ) async {
      // The "compact pill" shape belongs to the Row, not to the widget:
      await pumpPreview(tester, customerRegisterPillAlone);
      final Size hugged = tester.getSize(_pill);

      await pumpPreview(tester, customerRegisterPillInBoundedParent);
      final Size stretched = tester.getSize(_pill);

      expect(hugged.width, closeTo(144.8, 0.5));
      expect(stretched.width, closeTo(374.0, 0.5));
      expect(stretched.height, hugged.height);
    });

    testWidgets('is exactly 40 dp tall, at 1.0x and at 2.0x', (
      WidgetTester tester,
    ) async {
      // `Sizes.threeXLarge`, hard-coded into the button's `height:`. The label
      await pumpPreview(tester, customerRegisterPillInRow);
      expect(tester.getSize(_pill).height, 40.0);
      expect(tester.getSize(find.text('Register')).height, 20.0);

      await pumpPreview(tester, customerRegisterPillRowAtLargeText);
      expect(tester.getSize(_pill).height, 40.0);
      // 0.0 dp of headroom left at the 200% accessibility ceiling.
      expect(tester.getSize(find.text('Register')).height, 40.0);
    });

    testWidgets('crops its label above 200% instead of growing', (
      WidgetTester tester,
    ) async {
      // iOS Dynamic Type goes past 250%. There the label needs 50 dp and gets
      await pumpPreview(
        tester,
        () => MediaQuery.withClampedTextScaling(
          minScaleFactor: 2.5,
          maxScaleFactor: 2.5,
          child: customerRegisterPillAlone(),
        ),
      );

      final Finder label = find.text('Register');
      final TextStyle style = tester.widget<Text>(label).style!;
      final TextPainter painter = TextPainter(
        text: TextSpan(text: 'Register', style: style),
        textDirection: TextDirection.ltr,
        textScaler: const TextScaler.linear(2.5),
      )..layout();

      expect(painter.height, greaterThan(40.0));
      expect(tester.getSize(label).height, 40.0);
      expect(
        (tester.renderObject(label) as RenderParagraph).size.height,
        lessThan(painter.height),
      );
    });

    testWidgets('does not make its row taller than a chevron row', (
      WidgetTester tester,
    ) async {
      // The pill is 40 dp inside a 56 dp (`Sizes.fiveXLarge`) row minimum, so
      await pumpPreview(tester, customerRegisterPillBesideChevronRows);

      final Finder rows = find.byType(CustomerProfileRow);
      expect(rows, findsNWidgets(2));
      expect(tester.getSize(rows.at(0)).height, 56.0);
      expect(tester.getSize(rows.at(0)), tester.getSize(rows.at(1)));
    });
  });
}
