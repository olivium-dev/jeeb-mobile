import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_select_chip.dart';

void main() {
  for (final direction in TextDirection.values) {
    for (final role in JeebChipRole.values) {
      for (final selected in <bool>[false, true]) {
        testWidgets('$direction $role selected=$selected reflows completely', (
          tester,
        ) async {
          final semantics = tester.ensureSemantics();
          try {
            for (final width in <double>[96, 312]) {
              final label = direction == TextDirection.ltr
                  ? 'Waiting for a response from the delivery partner'
                  : 'بانتظار الحصول على رد من شريك التوصيل';
              var taps = 0;
              await tester.pumpWidget(
                MaterialApp(
                  theme: AppTheme.midnight(),
                  home: MediaQuery(
                    data: const MediaQueryData(
                      textScaler: TextScaler.linear(2),
                    ),
                    child: Directionality(
                      textDirection: direction,
                      child: Scaffold(
                        body: SingleChildScrollView(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              width: width,
                              child: JeebSelectChip(
                                role: role,
                                label: label,
                                selected: selected,
                                count: 123456789,
                                leading: const Icon(Icons.check, size: 20),
                                identifier: 'reflow_chip',
                                onTap: () => taps++,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              expect(tester.takeException(), isNull);
              final chip = find.byType(JeebSelectChip);
              final bounds = tester.getRect(chip);
              expect(bounds.width, width);
              for (final text in <String>[label, '123456789']) {
                final finder = find.text(text);
                final paragraph = tester.renderObject<RenderParagraph>(finder);
                expect(paragraph.didExceedMaxLines, isFalse);
                expect(
                  bounds.intersect(tester.getRect(finder)),
                  tester.getRect(finder),
                );
                for (var index = 0; index < text.length; index++) {
                  // Soft-wrap whitespace selection can extend beyond the ink.
                  if (text[index].trim().isEmpty) continue;
                  final boxes = paragraph.getBoxesForSelection(
                    TextSelection(baseOffset: index, extentOffset: index + 1),
                  );
                  expect(boxes, isNotEmpty);
                  for (final box in boxes) {
                    expect(box.left, greaterThanOrEqualTo(0));
                    expect(box.right, lessThanOrEqualTo(paragraph.size.width));
                    expect(box.top, greaterThanOrEqualTo(0));
                    expect(
                      box.bottom,
                      lessThanOrEqualTo(paragraph.size.height),
                    );
                  }
                }
              }
              final iconBounds = tester.getRect(find.byIcon(Icons.check));
              expect(bounds.intersect(iconBounds), iconBounds);
              final data = tester
                  .getSemantics(find.bySemanticsIdentifier('reflow_chip'))
                  .getSemanticsData();
              expect(
                data.flagsCollection.isSelected == Tristate.isTrue,
                selected,
              );
              expect(data.flagsCollection.isButton, isTrue);
              expect(data.hasAction(SemanticsAction.tap), isTrue);
              await tester.tapAt(
                tester.getTopLeft(chip) + const Offset(10, 10),
              );
              expect(taps, 1);
            }
          } finally {
            semantics.dispose();
          }
        });

        testWidgets('$direction $role selected=$selected row compatibility', (
          tester,
        ) async {
          for (final form in <String>[
            'row',
            'scrollable',
            'expanded',
            'tall',
          ]) {
            final chip = JeebSelectChip(
              role: role,
              label: direction == TextDirection.ltr ? 'Go' : 'هيا',
              selected: selected,
              count: 12,
              leading: const Icon(Icons.check, size: 20),
            );
            final Widget row = switch (form) {
              'scrollable' => JeebChipRow.scrollable(children: [chip]),
              'expanded' => JeebChipRow.expanded(children: [chip, chip]),
              'tall' => SizedBox(height: 120, child: chip),
              _ => JeebChipRow(children: [chip]),
            };
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.midnight(),
                home: MediaQuery(
                  data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                  child: Directionality(
                    textDirection: direction,
                    child: Scaffold(
                      body: Center(child: SizedBox(width: 320, child: row)),
                    ),
                  ),
                ),
              ),
            );
            expect(tester.takeException(), isNull, reason: form);
            for (final element in find.byType(JeebSelectChip).evaluate()) {
              final finder = find.byElementPredicate(
                (value) => value == element,
              );
              final bounds = tester.getRect(finder);
              if (form == 'tall') {
                final label = find.descendant(
                  of: finder,
                  matching: find.text(chip.label),
                );
                expect(tester.getCenter(label).dy, bounds.center.dy);
              }
              for (final text
                  in find
                      .descendant(of: finder, matching: find.byType(Text))
                      .evaluate()) {
                final textFinder = find.byElementPredicate(
                  (value) => value == text,
                );
                expect(
                  bounds.intersect(tester.getRect(textFinder)),
                  tester.getRect(textFinder),
                );
              }
            }
          }
        });
      }
    }
  }
}
