// M6 R15-4 — the kit doc used to tell call sites that an unwrapped chip was a
// conformance failure. It is not: WCAG 2.2 SC 2.5.8 (AA) is 24x24 CSS px.
// 44x44 is SC 2.5.5 (AAA) and 48dp is Material guidance. This turns the
// corrected doc into a measurement so the question cannot reopen.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/accessibility/accessibility.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_select_chip.dart';

/// WCAG 2.2 SC 2.5.8 Target Size (Minimum) — the **AA** bar, in CSS px = dp.
const double _wcagAaTargetDp = 24;

/// SC 2.5.5 Target Size (Enhanced) — **AAA**, quoted only to prove the chips
/// are deliberately below it rather than accidentally above the AA bar.
const double _wcagAaaTargetDp = 44;

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.midnight(),
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: child),
      ),
    );

void main() {
  group('JeebSelectChip target size (M6 R15-4)', () {
    for (final JeebChipRole role in JeebChipRole.values) {
      testWidgets('$role clears the 24x24 AA bar unwrapped',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          _host(
            SizedBox(
              // `choice` takes its width from JeebChipRow.expanded's flex, so
              // it needs a bounded box to measure at all.
              width: 120,
              child: JeebSelectChip(
                role: role,
                label: 'Nearby',
                onTap: () {},
              ),
            ),
          ),
        );

        final Size size = tester.getSize(find.byType(JeebSelectChip));
        expect(size.height, greaterThanOrEqualTo(_wcagAaTargetDp));
        expect(size.width, greaterThanOrEqualTo(_wcagAaTargetDp));
      });
    }

    testWidgets('and stays deliberately under the AAA / Material sizes',
        (WidgetTester tester) async {
      // The board rhythm depends on this: wave-B ruled R15's 33dp tag row ships
      // board-faithful, because MinTapTarget inflates its 8dp run gap to ~22dp.
      for (final JeebChipRole role in JeebChipRole.values) {
        await tester.pumpWidget(
          _host(
            SizedBox(
              width: 120,
              child: JeebSelectChip(role: role, label: 'Nearby', onTap: () {}),
            ),
          ),
        );
        final double height = tester.getSize(find.byType(JeebSelectChip)).height;
        expect(height, lessThan(_wcagAaaTargetDp));
        expect(height, lessThan(A11y.minTapTargetSize));
      }
    });

    testWidgets('DISCRIMINATION — MinTapTarget is what a 48dp rule would need',
        (WidgetTester tester) async {
      // Proves the two bars are genuinely different numbers on this widget: the
      // wrapped form clears 48, the bare form does not, and both clear 24.
      await tester.pumpWidget(
        _host(
          MinTapTarget(
            onTap: () {},
            child: const JeebSelectChip(
              role: JeebChipRole.inlineAction,
              label: 'Track',
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(MinTapTarget)).height,
        greaterThanOrEqualTo(A11y.minTapTargetSize),
      );
      expect(
        tester.getSize(find.byType(JeebSelectChip)).height,
        lessThan(A11y.minTapTargetSize),
      );
    });
  });
}
