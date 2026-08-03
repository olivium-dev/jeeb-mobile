import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_select_chip.dart';

/// Local harness: kept private so concurrent kit lanes cannot break each other
/// by renaming a shared helper.
Widget _wrap(Widget child, {TextDirection direction = TextDirection.ltr}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Directionality(
      textDirection: direction,
      child: Scaffold(
        body: Center(child: SizedBox(width: 340, child: child)),
      ),
    ),
  );
}

BoxDecoration _pillDecoration(WidgetTester tester) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byType(JeebSelectChip),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return box.decoration as BoxDecoration;
}

TextStyle _labelStyle(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label)).style!;

void main() {
  group('JeebSelectChip — fill / border state machine', () {
    testWidgets('unselected is white with a 1.5px outline stroke',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const JeebSelectChip(
            role: JeebChipRole.filter,
            label: 'Replies',
          ),
        ),
      );

      final BuildContext context = tester.element(find.byType(JeebSelectChip));
      final ColorScheme scheme = Theme.of(context).colorScheme;
      final BoxDecoration decoration = _pillDecoration(tester);

      expect(decoration.color, scheme.surface);
      expect(decoration.border, isNotNull);
      expect(decoration.border!.top.color, scheme.outline);
      expect(decoration.border!.top.width, JeebSelectChip.borderWidth);
      expect(decoration.borderRadius, jeebPillRadius);
    });

    testWidgets('selected is a navy fill with NO border — a fill swap',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const JeebSelectChip(
            role: JeebChipRole.filter,
            label: 'Pending',
            selected: true,
          ),
        ),
      );

      final BuildContext context = tester.element(find.byType(JeebSelectChip));
      final ColorScheme scheme = Theme.of(context).colorScheme;
      final BoxDecoration decoration = _pillDecoration(tester);

      expect(decoration.color, scheme.primary);
      expect(decoration.border, isNull);
      expect(_labelStyle(tester, 'Pending').color, scheme.onPrimary);
    });
  });

  group('JeebSelectChip — the five-role table (02-PLAN R2)', () {
    testWidgets('each role ships its own measured size', (
      WidgetTester tester,
    ) async {
      const Map<JeebChipRole, double> expected = <JeebChipRole, double>{
        JeebChipRole.filter: 14.5,
        JeebChipRole.sort: 12.5,
        JeebChipRole.choice: 13.5,
        JeebChipRole.quickReply: 12,
        JeebChipRole.inlineAction: 13,
      };

      for (final MapEntry<JeebChipRole, double> entry in expected.entries) {
        await tester.pumpWidget(
          _wrap(JeebSelectChip(role: entry.key, label: 'x')),
        );
        expect(
          _labelStyle(tester, 'x').fontSize,
          entry.value,
          reason: 'role ${entry.key} must not drift from its measured size',
        );
      }
    });

    testWidgets('unselected ink is brown for filter/sort and navy for the rest',
        (WidgetTester tester) async {
      const Set<JeebChipRole> brown = <JeebChipRole>{
        JeebChipRole.filter,
        JeebChipRole.sort,
      };

      for (final JeebChipRole role in JeebChipRole.values) {
        await tester.pumpWidget(_wrap(JeebSelectChip(role: role, label: 'x')));
        final ColorScheme scheme =
            Theme.of(tester.element(find.byType(JeebSelectChip))).colorScheme;
        expect(
          _labelStyle(tester, 'x').color,
          brown.contains(role) ? scheme.onSurfaceVariant : scheme.primary,
          reason: 'the unselected ink is NOT constant across roles',
        );
      }
    });

    testWidgets('only `sort` steps up to w700 when selected', (
      WidgetTester tester,
    ) async {
      for (final JeebChipRole role in JeebChipRole.values) {
        await tester.pumpWidget(
          _wrap(JeebSelectChip(role: role, label: 'x', selected: true)),
        );
        expect(
          _labelStyle(tester, 'x').fontWeight,
          role == JeebChipRole.sort ? FontWeight.w700 : FontWeight.w600,
        );
      }
    });

    testWidgets('choice has zero horizontal padding — the width is the row\'s',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const JeebChipRow.expanded(
            children: <Widget>[
              JeebSelectChip(role: JeebChipRole.choice, label: '20 min'),
              JeebSelectChip(role: JeebChipRole.choice, label: '40 min'),
            ],
          ),
        ),
      );

      final Padding padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(JeebSelectChip).first,
              matching: find.byType(Padding),
            )
            .first,
      );
      expect(
        padding.padding.resolve(TextDirection.ltr).horizontal,
        0,
      );

      // Equal-width pills: the whole point of the `flex: 1` row.
      final Size first = tester.getSize(find.byType(JeebSelectChip).first);
      final Size second = tester.getSize(find.byType(JeebSelectChip).last);
      expect(first.width, second.width);
    });

    testWidgets('the capsule renders under 48dp (11 asserts this)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const JeebSelectChip(role: JeebChipRole.sort, label: 'Lowest price'),
        ),
      );
      expect(tester.getSize(find.byType(JeebSelectChip)).height, lessThan(48));
    });
  });

  group('JeebSelectChip — count', () {
    testWidgets('selected renders the count inline in the label style', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const JeebSelectChip(
            role: JeebChipRole.filter,
            label: 'Pending',
            selected: true,
            count: 1,
          ),
        ),
      );

      // Separate Texts — a concatenated 'Pending 1' would break find.text.
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(_labelStyle(tester, '1'), _labelStyle(tester, 'Pending'));
      // No orange disc in the selected mode.
      expect(
        find.descendant(
          of: find.byType(JeebSelectChip),
          matching: find.byType(Container),
        ),
        findsNothing,
      );
    });

    testWidgets('unselected renders the Ø18 orange badge', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const JeebSelectChip(
            role: JeebChipRole.filter,
            label: 'Replies',
            count: 3,
          ),
        ),
      );

      expect(find.text('Replies'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      final BuildContext context = tester.element(find.byType(JeebSelectChip));
      final JeebRoles roles = context.jeebRoles;
      final Container badge = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(JeebSelectChip),
              matching: find.byType(Container),
            )
            .first,
      );
      final BoxDecoration decoration = badge.decoration! as BoxDecoration;
      expect(decoration.color, roles.accent);
      expect(decoration.borderRadius, jeebPillRadius);

      final Size size = tester.getSize(
        find
            .descendant(
              of: find.byType(JeebSelectChip),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(size.height, 18);
      expect(size.width, greaterThanOrEqualTo(18));

      final TextStyle style = _labelStyle(tester, '3');
      expect(style.fontSize, 11);
      expect(style.fontWeight, FontWeight.w800);
      expect(style.color, roles.onAccent);
    });
  });

  group('JeebSelectChip — interaction & semantics', () {
    testWidgets('tap fires onTap', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(
        _wrap(
          JeebSelectChip(
            role: JeebChipRole.inlineAction,
            label: 'Accept',
            onTap: () => taps++,
          ),
        ),
      );

      await tester.tap(find.byType(JeebSelectChip));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('no identifier and no semanticLabel adds NO Semantics node', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          JeebSelectChip(
            role: JeebChipRole.sort,
            label: 'Best',
            onTap: () {},
          ),
        ),
      );

      // The consumer idiom is its own outer Semantics + ExcludeSemantics; a
      // kit container node there would duplicate or swallow the frozen id.
      // (InkWell's own non-container annotations are expected and harmless.)
      expect(
        find.descendant(
          of: find.byType(JeebSelectChip),
          matching: find.byWidgetPredicate(
            (Widget widget) => widget is Semantics && widget.container,
          ),
        ),
        findsNothing,
      );
    });

    testWidgets('an identifier produces a findable, selection-reporting node', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          JeebSelectChip(
            role: JeebChipRole.sort,
            label: 'Today',
            selected: true,
            identifier: 'earnings_period_today',
            onTap: () {},
          ),
        ),
      );

      expect(
        find.bySemanticsIdentifier('earnings_period_today'),
        findsOneWidget,
      );

      final Semantics node = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byType(JeebSelectChip),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(node.properties.selected, isTrue);
      expect(node.properties.button, isTrue);
      expect(node.explicitChildNodes, isTrue);
    });

    testWidgets('a nested leading identifier survives the wrapper', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          JeebSelectChip(
            role: JeebChipRole.filter,
            label: 'Jun 1 – 30',
            identifier: 'order_history_range',
            leading: Semantics(
              identifier: 'order_history_range_glyph',
              child: const SizedBox(width: 14, height: 14),
            ),
          ),
        ),
      );

      expect(find.bySemanticsIdentifier('order_history_range'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('order_history_range_glyph'),
        findsOneWidget,
      );
    });
  });

  group('JeebChipRow', () {
    testWidgets('lays chips out with the 8px default gap', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const JeebChipRow(
            children: <Widget>[
              JeebSelectChip(role: JeebChipRole.sort, label: 'A'),
              JeebSelectChip(role: JeebChipRole.sort, label: 'B'),
            ],
          ),
        ),
      );

      expect(JeebChipRow.defaultSpacing, 8);
      final double gap = tester.getTopLeft(find.byType(JeebSelectChip).last).dx -
          tester.getTopRight(find.byType(JeebSelectChip).first).dx;
      expect(gap, JeebChipRow.defaultSpacing);
    });

    testWidgets('scrollable is a non-lazy Row inside a horizontal scroll view',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          JeebChipRow.scrollable(
            children: <Widget>[
              for (int i = 0; i < 12; i++)
                JeebSelectChip(
                  role: JeebChipRole.quickReply,
                  label: 'reply $i',
                  identifier: 'quick_reply_$i',
                ),
            ],
          ),
        ),
      );

      final SingleChildScrollView view =
          tester.widget<SingleChildScrollView>(find.byType(
        SingleChildScrollView,
      ));
      expect(view.scrollDirection, Axis.horizontal);
      // Non-lazy: every pill is built, so off-screen ids stay addressable.
      expect(find.byType(JeebSelectChip, skipOffstage: false), findsNWidgets(12));
      expect(find.bySemanticsIdentifier('quick_reply_11'), findsOneWidget);
    });

    testWidgets('an identifier wraps the row without swallowing chip ids', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const JeebChipRow(
            identifier: 'client_location_saved_places_row',
            children: <Widget>[
              JeebSelectChip(
                role: JeebChipRole.quickReply,
                label: 'Home',
                identifier: 'location_select_saved_address_home',
              ),
            ],
          ),
        ),
      );

      expect(
        find.bySemanticsIdentifier('client_location_saved_places_row'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('location_select_saved_address_home'),
        findsOneWidget,
      );
    });
  });

  group('RTL smoke', () {
    testWidgets('leading glyph and count badge mirror to the end side', (
      WidgetTester tester,
    ) async {
      Future<void> pump(TextDirection direction) => tester.pumpWidget(
            _wrap(
              const JeebSelectChip(
                role: JeebChipRole.filter,
                label: 'الردود',
                count: 3,
                leading: SizedBox(
                  key: ValueKey<String>('glyph'),
                  width: 14,
                  height: 14,
                ),
              ),
              direction: direction,
            ),
          );

      await pump(TextDirection.ltr);
      final double glyphLtr =
          tester.getCenter(find.byKey(const ValueKey<String>('glyph'))).dx;
      final double labelLtr = tester.getCenter(find.text('الردود')).dx;
      final double badgeLtr = tester.getCenter(find.text('3')).dx;
      expect(glyphLtr, lessThan(labelLtr));
      expect(labelLtr, lessThan(badgeLtr));

      await pump(TextDirection.rtl);
      final double glyphRtl =
          tester.getCenter(find.byKey(const ValueKey<String>('glyph'))).dx;
      final double labelRtl = tester.getCenter(find.text('الردود')).dx;
      final double badgeRtl = tester.getCenter(find.text('3')).dx;
      expect(glyphRtl, greaterThan(labelRtl));
      expect(labelRtl, greaterThan(badgeRtl));
    });

    testWidgets('JeebChipRow packs chips from the start edge in both directions',
        (WidgetTester tester) async {
      Future<void> pump(TextDirection direction) => tester.pumpWidget(
            _wrap(
              const JeebChipRow(
                children: <Widget>[
                  JeebSelectChip(role: JeebChipRole.sort, label: 'first'),
                  JeebSelectChip(role: JeebChipRole.sort, label: 'last'),
                ],
              ),
              direction: direction,
            ),
          );

      await pump(TextDirection.ltr);
      expect(
        tester.getCenter(find.text('first')).dx,
        lessThan(tester.getCenter(find.text('last')).dx),
      );

      await pump(TextDirection.rtl);
      expect(
        tester.getCenter(find.text('first')).dx,
        greaterThan(tester.getCenter(find.text('last')).dx),
      );
    });

    testWidgets('the expanded row mirrors too', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const JeebChipRow.expanded(
            children: <Widget>[
              JeebSelectChip(role: JeebChipRole.choice, label: '20 min'),
              JeebSelectChip(role: JeebChipRole.choice, label: '60 min'),
            ],
          ),
          direction: TextDirection.rtl,
        ),
      );

      expect(
        tester.getCenter(find.text('20 min')).dx,
        greaterThan(tester.getCenter(find.text('60 min')).dx),
      );
    });
  });
}
