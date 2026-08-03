import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_segmented_toggle.dart';

import 'jeeb_remainder_test_harness.dart';

/// Gates for redesign-2026-08 §5 #19.
///
/// FAIL-WITHOUT: 20's language rows carry frozen keys
/// (`settings-row-language-en`/`-ar`, tapped by `settings_screen_test.dart:161`)
/// and frozen identifiers (`settings_language_en_option`/`_ar_option`). A toggle
/// that cannot carry per-segment keys silently drops both.
void main() {
  final ColorScheme scheme = AppTheme.light().colorScheme;

  const List<JeebSegment> languageSegments = <JeebSegment>[
    JeebSegment(
      label: 'English',
      key: Key('settings-row-language-en'),
      identifier: 'settings_language_en_option',
    ),
    JeebSegment(
      label: 'العربية',
      key: Key('settings-row-language-ar'),
      identifier: 'settings_language_ar_option',
    ),
  ];

  Widget toggle({
    int selectedIndex = 0,
    ValueChanged<int>? onChanged,
    String? identifier,
  }) {
    return JeebSegmentedToggle(
      segments: languageSegments,
      selectedIndex: selectedIndex,
      identifier: identifier,
      onChanged: onChanged ?? (_) {},
    );
  }

  BoxDecoration segmentDecoration(WidgetTester tester, String label) {
    final DecoratedBox box = tester.widget<DecoratedBox>(
      find
          .ancestor(
            of: find.text(label),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    return box.decoration as BoxDecoration;
  }

  group('JeebSegmentedToggle visuals', () {
    testWidgets('outer track is a 1.5px outlined pill padded 4',
        (tester) async {
      await tester.pumpWidget(wrapRemainder(toggle()));

      final BoxDecoration track =
          remainderDecorationOf(tester, find.byType(JeebSegmentedToggle));
      expect(track.borderRadius, BorderRadius.circular(999));
      final Border border = track.border! as Border;
      expect(border.top.color, scheme.outline);
      expect(border.top.width, 1.5);

      final Padding padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(JeebSegmentedToggle),
              matching: find.byType(Padding),
            )
            .first,
      );
      // 4 track padding + the 1.5px stroke (border-box).
      expect(
        padding.padding.resolve(TextDirection.ltr),
        const EdgeInsets.all(5.5),
      );
    });

    testWidgets('selection is a navy fill swap, never a border',
        (tester) async {
      await tester.pumpWidget(wrapRemainder(toggle()));

      final BoxDecoration selected = segmentDecoration(tester, 'English');
      expect(selected.color, scheme.primary);
      expect(selected.border, isNull);

      final BoxDecoration unselected = segmentDecoration(tester, 'العربية');
      expect(unselected.color, Colors.transparent);
      expect(unselected.border, isNull);
    });

    testWidgets('label is 13.5/w700, onPrimary when selected and navy when not',
        (tester) async {
      await tester.pumpWidget(wrapRemainder(toggle()));

      final TextStyle selected =
          tester.widget<Text>(find.text('English')).style!;
      expect(selected.fontSize, 13.5);
      expect(selected.fontWeight, FontWeight.w700);
      expect(selected.color, scheme.onPrimary);

      expect(
        tester.widget<Text>(find.text('العربية')).style!.color,
        scheme.primary,
      );
    });

    testWidgets('segments share the width equally', (tester) async {
      await tester.pumpWidget(wrapRemainder(toggle()));

      final List<Element> expanded =
          find.byType(Expanded).evaluate().toList(growable: false);
      expect(expanded.length, 2);
      final double first = tester.getSize(find.byType(Expanded).at(0)).width;
      final double second = tester.getSize(find.byType(Expanded).at(1)).width;
      expect(first, closeTo(second, 0.01));
    });
  });

  group('JeebSegmentedToggle behaviour', () {
    testWidgets('reports the tapped index, including a re-tap of the selection',
        (tester) async {
      final List<int> taps = <int>[];
      await tester.pumpWidget(
        wrapRemainder(toggle(onChanged: taps.add)),
      );

      await tester.tap(find.byKey(const Key('settings-row-language-ar')));
      expect(taps, <int>[1]);

      await tester.tap(find.byKey(const Key('settings-row-language-en')));
      expect(
        taps,
        <int>[1, 0],
        reason: 'a re-tap must still report, or the control feels dead',
      );
    });

    testWidgets('an out-of-range index selects nothing rather than throwing',
        (tester) async {
      await tester.pumpWidget(wrapRemainder(toggle(selectedIndex: 7)));

      expect(tester.takeException(), isNull);
      expect(segmentDecoration(tester, 'English').color, Colors.transparent);
      expect(segmentDecoration(tester, 'العربية').color, Colors.transparent);
    });
  });

  group('JeebSegmentedToggle semantics', () {
    testWidgets('every segment is a mutually-exclusive button with its id',
        (tester) async {
      await tester.pumpWidget(wrapRemainder(toggle(selectedIndex: 1)));

      final SemanticsNode en = tester.getSemantics(
        find.bySemanticsIdentifier('settings_language_en_option'),
      );
      expect(en.label, 'English');
      expect(en.flagsCollection.isButton, isTrue);
      expect(en.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
      expect(en.flagsCollection.isSelected, Tristate.isFalse);

      final SemanticsNode ar = tester.getSemantics(
        find.bySemanticsIdentifier('settings_language_ar_option'),
      );
      expect(ar.flagsCollection.isSelected, Tristate.isTrue);
    });

    testWidgets('a track identifier does not swallow the segment ids',
        (tester) async {
      await tester.pumpWidget(
        wrapRemainder(toggle(identifier: 'settings_language_toggle')),
      );

      expect(
        find.bySemanticsIdentifier('settings_language_toggle'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('settings_language_en_option'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('settings_language_ar_option'),
        findsOneWidget,
      );
    });
  });

  group('JeebSegmentedToggle RTL smoke', () {
    testWidgets('segment 0 mirrors to the start edge and still taps',
        (tester) async {
      final List<int> taps = <int>[];
      await tester.pumpWidget(wrapRemainder(toggle(onChanged: taps.add)));
      expect(
        tester.getCenter(find.text('English')).dx,
        lessThan(tester.getCenter(find.text('العربية')).dx),
      );

      await tester.pumpWidget(
        wrapRemainder(
          toggle(onChanged: taps.add),
          direction: TextDirection.rtl,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getCenter(find.text('English')).dx,
        greaterThan(tester.getCenter(find.text('العربية')).dx),
        reason: 'index 0 follows the start edge; nothing is flipped by hand',
      );

      await tester.tap(find.byKey(const Key('settings-row-language-ar')));
      expect(taps.last, 1);
    });
  });

  testWidgets('survives a bare ThemeData.light() harness', (tester) async {
    await tester.pumpWidget(wrapUnthemed(toggle()));
    expect(tester.takeException(), isNull);
  });
}
