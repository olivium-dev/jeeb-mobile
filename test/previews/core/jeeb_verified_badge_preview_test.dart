import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb_verified_badge.dart';

import '../preview_test_harness.dart';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Customer row (production)': jeebVerifiedBadgeCustomerRow,
  'Jeeber row (production)': jeebVerifiedBadgeJeeberRow,
  'Long name (wraps)': jeebVerifiedBadgeLongName,
  'Size scale 12-40dp': jeebVerifiedBadgeSizeScale,
  'Empty label (silent)': jeebVerifiedBadgeUnlabelled,
  'Bare glyph on surface': jeebVerifiedBadgeBare,
};

/// WCAG relative-contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final double lumA = a.computeLuminance();
  final double lumB = b.computeLuminance();
  final double hi = math.max(lumA, lumB);
  final double lo = math.min(lumA, lumB);
  return (hi + 0.05) / (lo + 0.05);
}

/// The single badge in [preview], as a box.
Size _badgeBox(WidgetTester tester) =>
    tester.getSize(find.byType(JeebVerifiedBadge));

/// How many lines [text] wrapped onto, counted from the laid-ou
List<TextBox> _lineBoxes(WidgetTester tester, String text) {
  final RenderParagraph paragraph =
      tester.renderObject<RenderParagraph>(find.text(text));
  final List<TextBox> boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: text.length),
  );
  final Map<int, TextBox> byLine = <int, TextBox>{};
  for (final TextBox box in boxes) {
    byLine.putIfAbsent(box.top.round(), () => box);
  }
  final List<TextBox> lines = byLine.values.toList()
    ..sort((TextBox a, TextBox b) => a.top.compareTo(b.top));
  return lines;
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'JeebVerifiedBadge',
    _previews,
    expectedText: const <String, String>{
      'Customer row (production)': 'Sami Fawaz',
      'Jeeber row (production)': 'Kamal Hajj',
      'Long name (wraps)': 'Abdulrahman Al-Muhandis Al-Trabulsi',
      'Size scale 12-40dp': 'Size scale: 12 / 20 / 32 / 40 dp',
      'Empty label (silent)': 'Empty semanticsLabel: announced as nothing',
      'Bare glyph on surface': 'Bare 20dp glyph on surface',
    },
  );

  group('JeebVerifiedBadge preview specifics', () {
    testWidgets('every production state paints the 20dp default box', (
      WidgetTester tester,
    ) async {
      for (final String state in const <String>[
        'Customer row (production)',
        'Jeeber row (production)',
        'Long name (wraps)',
        'Empty label (silent)',
        'Bare glyph on surface',
      ]) {
        await pumpPreview(tester, _previews[state]!);
        expect(
          _badgeBox(tester),
          const Size(20, 20),
          reason: '$state must render `Sizes.large`, the size both callers take',
        );
      }
    });

    testWidgets('the size strip renders four DIFFERENT boxes', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeebVerifiedBadgeSizeScale);

      final List<Size> boxes = tester
          .widgetList<JeebVerifiedBadge>(find.byType(JeebVerifiedBadge))
          .map((JeebVerifiedBadge b) => Size(b.size, b.size))
          .toList();

      expect(boxes, <Size>[
        const Size(12, 12),
        const Size(20, 20),
        const Size(32, 32),
        const Size(40, 40),
      ]);
      for (final Size declared in boxes) {
        final int index = boxes.indexOf(declared);
        expect(
          tester.getSize(find.byType(JeebVerifiedBadge).at(index)),
          declared,
        );
      }
    });

    testWidgets('the long name wraps and the seal leaves the first line', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeebVerifiedBadgeCustomerRow);
      final Rect shortBadge = tester.getRect(find.byType(JeebVerifiedBadge));
      final Rect shortName = tester.getRect(find.text('Sami Fawaz'));
      final int shortLines = _lineBoxes(tester, 'Sami Fawaz').length;

      await pumpPreview(tester, jeebVerifiedBadgeLongName);
      const String longName = 'Abdulrahman Al-Muhandis Al-Trabulsi';
      final Rect longNameBox = tester.getRect(find.text(longName));
      final Rect longBadge = tester.getRect(find.byType(JeebVerifiedBadge));
      final List<TextBox> longLines = _lineBoxes(tester, longName);

      expect(
        longLines.length,
        greaterThan(shortLines),
        reason: 'the long-name state must actually wrap further than the short '
            'one, or it is the same state with a different string',
      );
      expect(longLines.length, greaterThanOrEqualTo(3));

      expect(longBadge.right, lessThanOrEqualTo(longNameBox.right + 28.0));

      expect((shortBadge.center.dy - shortName.center.dy).abs(), lessThan(1.0));
      expect(
        longBadge.center.dy - longNameBox.top,
        greaterThan(longLines.first.bottom - longLines.first.top),
        reason: 'the verification mark has detached from the first line of the '
            'name it verifies',
      );
    });

    testWidgets('the two shipping callers announce DIFFERENT labels', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(tester, jeebVerifiedBadgeCustomerRow);
      expect(find.bySemanticsLabel('Verified account'), findsOneWidget);

      await pumpPreview(tester, jeebVerifiedBadgeJeeberRow);
      expect(find.bySemanticsLabel('Verified account'), findsNothing);
      expect(find.bySemanticsLabel('Verified'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('the label is localized, not hardcoded English', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(
        tester,
        jeebVerifiedBadgeCustomerRow,
        locale: const Locale('ar'),
      );
      expect(find.bySemanticsLabel('Verified account'), findsNothing);
      expect(find.bySemanticsLabel('حساب موثّق'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('an empty label leaves an image node announced as nothing', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(tester, jeebVerifiedBadgeUnlabelled);

      final SemanticsNode node = tester.getSemantics(
        find.byType(JeebVerifiedBadge),
      );
      expect(node.label, isEmpty);
      expect(
        node.flagsCollection.isImage,
        isTrue,
        reason: 'a silent node flagged as an image is worse than no node: '
            '`excludeSemantics` would at least skip it',
      );

      handle.dispose();
    });

    testWidgets('the seal does NOT grow with text scale', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeebVerifiedBadgeCustomerRow);
      final Size badgeAt100 = _badgeBox(tester);
      final double nameAt100 = tester.getSize(find.text('Sami Fawaz')).height;

      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpPreview(tester, jeebVerifiedBadgeCustomerRow);

      expect(
        tester.getSize(find.text('Sami Fawaz')).height,
        greaterThan(nameAt100 * 1.5),
        reason: 'sanity check that the 200% rendering really is scaled',
      );
      expect(
        _badgeBox(tester),
        badgeAt100,
        reason: '`Icon.applyTextScaling` is left at its false default and '
            'nothing in AppTheme or OMDS sets it, so the badge is frozen at '
            '20dp beside a name that has doubled. At the accessibility ceiling '
            'the verification mark is under half the height of the letter next '
            'to it.',
      );
    });

    test('the glyph role only clears non-text contrast in the light scheme', () {
      final ColorScheme light = AppTheme.light().colorScheme;
      expect(
        _contrast(light.secondaryContainer, light.surface),
        greaterThanOrEqualTo(3.0),
        reason: 'brand navy on white — the rendering designers signed off, and '
            'it must not regress',
      );

      final ColorScheme dark = AppTheme.dark().colorScheme;
      expect(
        _contrast(dark.secondaryContainer, dark.surface),
        lessThan(3.0),
        reason: 'if this ever passes 3:1 the palette was fixed — delete this '
            'expectation and the note on `jeebVerifiedBadgeBare`',
      );
    });
  });
}
