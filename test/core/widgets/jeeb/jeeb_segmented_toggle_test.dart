import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_segmented_toggle.dart';

import 'jeeb_remainder_test_harness.dart';

/// Gates for redesign-2026-08 §5 #19, re-cut on the MIDNIGHT token sheet.
///
/// FAIL-WITHOUT: 20's language rows carry frozen keys
/// (`settings-row-language-en`/`-ar`, tapped by `settings_screen_test.dart:161`)
/// and frozen identifiers (`settings_language_en_option`/`_ar_option`). A toggle
/// that cannot carry per-segment keys silently drops both. And: the active
/// segment is WHITE on navy — if it regresses to `colorScheme.primary` the
/// control spends the screen's whole orange budget on a language switch.
void main() {
  // Token sheet §1/§3: white `#FFFFFF`, navy `#0B1351`, `inkSoft` `#B9C0F0`,
  // `glassFill` white 7%, `glassBorderStrong` white 16%.
  const Color white = Color(0xFFFFFFFF);
  const Color navyInk = Color(0xFF0B1351);
  const Color inkSoft = Color(0xFFB9C0F0);
  const Color glassFill = Color(0x12FFFFFF);
  const Color glassBorderStrong = Color(0x29FFFFFF);

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
    testWidgets('outer track is a 1px glass pill padded 4', (tester) async {
      await tester.pumpWidget(wrapRemainder(toggle()));

      final BoxDecoration track =
          remainderDecorationOf(tester, find.byType(JeebSegmentedToggle));
      expect(track.borderRadius, BorderRadius.circular(999));
      expect(track.color, glassFill);
      final Border border = track.border! as Border;
      expect(border.top.color, glassBorderStrong);
      expect(border.top.width, 1);

      final Padding padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(JeebSegmentedToggle),
              matching: find.byType(Padding),
            )
            .first,
      );
      // 4 track padding + the 1px stroke (border-box).
      expect(
        padding.padding.resolve(TextDirection.ltr),
        const EdgeInsets.all(5),
      );
    });

    testWidgets('selection is a WHITE fill swap, never a border and never orange',
        (tester) async {
      await tester.pumpWidget(wrapRemainder(toggle()));

      final BoxDecoration selected = segmentDecoration(tester, 'English');
      expect(selected.color, white);
      expect(selected.border, isNull);

      final BoxDecoration unselected = segmentDecoration(tester, 'العربية');
      expect(unselected.color, Colors.transparent);
      expect(unselected.border, isNull);
    });

    testWidgets('label is 13.5, navy w700 when selected and inkSoft w600 when not',
        (tester) async {
      await tester.pumpWidget(wrapRemainder(toggle()));

      final TextStyle selected =
          tester.widget<Text>(find.text('English')).style!;
      expect(selected.fontSize, 13.5);
      expect(selected.fontWeight, FontWeight.w700);
      expect(selected.color, navyInk);

      final TextStyle unselected =
          tester.widget<Text>(find.text('العربية')).style!;
      expect(unselected.fontSize, 13.5);
      expect(unselected.fontWeight, FontWeight.w600);
      expect(unselected.color, inkSoft);
    });

    testWidgets('segments share the width equally, 5 apart', (tester) async {
      await tester.pumpWidget(wrapRemainder(toggle()));

      final List<Element> expanded =
          find.byType(Expanded).evaluate().toList(growable: false);
      expect(expanded.length, 2);
      final double first = tester.getSize(find.byType(Expanded).at(0)).width;
      final double second = tester.getSize(find.byType(Expanded).at(1)).width;
      expect(first, closeTo(second, 0.01));

      final double gap = tester.getTopLeft(find.byType(Expanded).at(1)).dx -
          tester.getTopRight(find.byType(Expanded).at(0)).dx;
      expect(gap, closeTo(5, 0.01));
    });
  });

  group('JeebSegmentedToggle trackless placement (E1)', () {
    Widget trackless({int selectedIndex = 0, ValueChanged<int>? onChanged}) {
      return JeebSegmentedToggle(
        placement: JeebSegmentedPlacement.trackless,
        segments: languageSegments,
        selectedIndex: selectedIndex,
        onChanged: onChanged ?? (_) {},
      );
    }

    testWidgets('draws NO enclosing track', (tester) async {
      await tester.pumpWidget(wrapRemainder(trackless()));

      // The only decorated boxes left are the two pills themselves.
      final Iterable<DecoratedBox> boxes = tester.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(JeebSegmentedToggle),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(boxes.length, 2);
      expect(find.byType(Expanded), findsNothing);
    });

    testWidgets('the unselected pill carries the glass the track would have',
        (tester) async {
      await tester.pumpWidget(wrapRemainder(trackless()));

      final BoxDecoration selected = segmentDecoration(tester, 'English');
      expect(selected.color, white);
      expect(selected.border, isNull, reason: 'selection is a fill swap');

      final BoxDecoration unselected = segmentDecoration(tester, 'العربية');
      expect(unselected.color, glassFill);
      expect((unselected.border! as Border).top.color, glassBorderStrong);
      expect((unselected.border! as Border).top.width, 1);
    });

    testWidgets('pills hug their labels at E1\'s 10/18 pad, 10 apart',
        (tester) async {
      await tester.pumpWidget(wrapRemainder(trackless()));

      expect(
        JeebSegmentedToggle.tracklessSegmentPadding.resolve(TextDirection.ltr),
        const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
      );
      expect(JeebSegmentedToggle.tracklessGap, 10);

      final Rect first = tester.getRect(find.text('English'));
      final Rect second = tester.getRect(find.text('العربية'));
      // 18 pad on each facing edge + the 10 gap.
      expect(second.left - first.right, closeTo(18 + 10 + 18, 0.01));
    });

    testWidgets('still reports taps and keeps the frozen per-segment ids',
        (tester) async {
      final List<int> taps = <int>[];
      await tester.pumpWidget(wrapRemainder(trackless(onChanged: taps.add)));

      await tester.tap(find.byKey(const Key('settings-row-language-ar')));
      expect(taps, <int>[1]);
      expect(
        find.bySemanticsIdentifier('settings_language_ar_option'),
        findsOneWidget,
      );
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
