// The shared filter kit: the Ø40 tune disc, the applied-filter pills and the
// modal-sheet chrome the two filter sheets wear.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/accessibility/accessibility.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_filter_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_filter_pills.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_filter_sheet.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget widget, {
    TextDirection direction = TextDirection.ltr,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.midnight(),
        home: Directionality(
          textDirection: direction,
          child: Scaffold(body: Center(child: widget)),
        ),
      ),
    );
  }

  BoxDecoration discOf(WidgetTester tester) {
    final DecoratedBox box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(JeebFilterButton),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    return box.decoration as BoxDecoration;
  }

  int decoratedBoxesIn(WidgetTester tester, Type root) {
    return tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(root),
            matching: find.byType(DecoratedBox),
          ),
        )
        .length;
  }

  group('JeebFilterButton', () {
    testWidgets('carries its identifier as a button and fires onTap',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      var taps = 0;
      await pump(
        tester,
        JeebFilterButton(
          onTap: () => taps++,
          semanticLabel: 'Filter requests',
          identifier: 'client_requests_filter_cta',
        ),
      );

      final Finder disc =
          find.bySemanticsIdentifier('client_requests_filter_cta');
      expect(disc, findsOneWidget);
      final SemanticsNode node = tester.getSemantics(disc);
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.label, 'Filter requests');

      await tester.tap(disc, warnIfMissed: false);
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('rests on the glass hairline with no badge',
        (WidgetTester tester) async {
      await pump(
        tester,
        JeebFilterButton(onTap: () {}, semanticLabel: 'Filter'),
      );

      final JeebSemanticColors glass = JeebSemanticColors.midnight();
      expect((discOf(tester).border! as Border).top.color, glass.glassBorder);
      expect(discOf(tester).shape, BoxShape.circle);
      expect(
        find.descendant(
          of: find.byType(JeebFilterButton),
          matching: find.byType(Stack),
        ),
        findsNothing,
      );
      expect(decoratedBoxesIn(tester, JeebFilterButton), 1);
    });

    testWidgets('active swaps the hairline for accent and adds the badge dot',
        (WidgetTester tester) async {
      await pump(
        tester,
        JeebFilterButton(
          onTap: () {},
          semanticLabel: 'Filter',
          active: true,
        ),
      );

      final BuildContext context =
          tester.element(find.byType(JeebFilterButton));

      expect(
        (discOf(tester).border! as Border).top.color,
        context.jeebRoles.accent,
      );
      // Disc + badge ring + badge dot: the visibly different tree.
      expect(decoratedBoxesIn(tester, JeebFilterButton), 3);
      expect(
        find.descendant(
          of: find.byType(JeebFilterButton),
          matching: find.byType(Stack),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the badge sits at the END corner, so RTL mirrors it',
        (WidgetTester tester) async {
      await pump(
        tester,
        JeebFilterButton(
          onTap: () {},
          semanticLabel: 'Filter',
          active: true,
        ),
        direction: TextDirection.rtl,
      );

      final Rect disc = tester.getRect(find.byType(Icon));
      final Rect badge = tester.getRect(find.byType(PositionedDirectional));
      expect(badge.center.dx, lessThan(disc.center.dx));
    });

    testWidgets('the hit box clears 48x48 while the disc stays 40',
        (WidgetTester tester) async {
      await pump(
        tester,
        JeebFilterButton(onTap: () {}, semanticLabel: 'Filter'),
      );

      final Size target = tester.getSize(find.byType(MinTapTarget));
      expect(target.width, greaterThanOrEqualTo(A11y.minTapTargetSize));
      expect(target.height, greaterThanOrEqualTo(A11y.minTapTargetSize));
      expect(
        tester.getSize(find.byType(SizedBox).at(0)).height,
        JeebFilterButton.diameter,
      );
    });
  });

  group('JeebFilterPill', () {
    Widget pill({
      required VoidCallback onClear,
      VoidCallback? onTap,
    }) {
      return JeebFilterPill(
        label: 'Status: Pending',
        onClear: onClear,
        clearSemanticLabel: 'Clear status filter',
        onTap: onTap,
        identifier: 'client_requests_filter_pill_status',
        clearIdentifier: 'client_requests_filter_pill_status_clear',
      );
    }

    testWidgets('the clear target fires onClear and never onTap',
        (WidgetTester tester) async {
      var clears = 0;
      var taps = 0;
      await pump(
        tester,
        pill(onClear: () => clears++, onTap: () => taps++),
      );

      await tester.tap(find.byIcon(Icons.close));
      expect(clears, 1);
      expect(taps, 0);
    });

    testWidgets('the body fires onTap and never onClear',
        (WidgetTester tester) async {
      var clears = 0;
      var taps = 0;
      await pump(
        tester,
        pill(onClear: () => clears++, onTap: () => taps++),
      );

      await tester.tap(find.text('Status: Pending'));
      expect(taps, 1);
      expect(clears, 0);
    });

    testWidgets('both targets keep their own identifier',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pump(tester, pill(onClear: () {}, onTap: () {}));

      final Finder body =
          find.bySemanticsIdentifier('client_requests_filter_pill_status');
      final Finder clear =
          find.bySemanticsIdentifier('client_requests_filter_pill_status_clear');
      expect(body, findsOneWidget);
      expect(clear, findsOneWidget);
      expect(tester.getSemantics(clear).label, 'Clear status filter');
      expect(tester.getSemantics(body).flagsCollection.isButton, isTrue);
      handle.dispose();
    });

    testWidgets('paints the accent-tinted capsule', (WidgetTester tester) async {
      await pump(tester, pill(onClear: () {}));

      final BuildContext context = tester.element(find.byType(JeebFilterPill));
      final JeebRoles roles = context.jeebRoles;
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(JeebFilterPill),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final BoxDecoration decoration = box.decoration as BoxDecoration;
      expect(decoration.color, roles.accentContainer);
      expect(
        (decoration.border! as Border).top.color,
        roles.accent.withValues(alpha: JeebFilterPill.borderAlpha),
      );
    });
  });

  group('JeebFilterPillRow', () {
    testWidgets('renders nothing when empty', (WidgetTester tester) async {
      await pump(tester, const JeebFilterPillRow(pills: <Widget>[]));

      expect(
        find.descendant(
          of: find.byType(JeebFilterPillRow),
          matching: find.byType(Wrap),
        ),
        findsNothing,
      );
      expect(tester.getSize(find.byType(JeebFilterPillRow)), Size.zero);
    });

    testWidgets('wraps the pills it is given', (WidgetTester tester) async {
      await pump(
        tester,
        JeebFilterPillRow(
          padding: const EdgeInsetsDirectional.all(8),
          pills: <Widget>[
            JeebFilterPill(
              label: 'One',
              onClear: () {},
              clearSemanticLabel: 'Clear one',
            ),
            JeebFilterPill(
              label: 'Two',
              onClear: () {},
              clearSemanticLabel: 'Clear two',
            ),
          ],
        ),
      );

      expect(find.byType(JeebFilterPill), findsNWidgets(2));
      final Wrap wrap = tester.widget<Wrap>(find.byType(Wrap));
      expect(wrap.spacing, JeebFilterPillRow.spacing);
      expect(wrap.runSpacing, JeebFilterPillRow.spacing);
    });
  });

  group('JeebFilterSheetScaffold', () {
    testWidgets('renders the title, the groups and both CTAs',
        (WidgetTester tester) async {
      await pump(
        tester,
        const JeebFilterSheetScaffold(
          title: 'Filter requests',
          subtitle: '3 applied',
          onClear: _noop,
          onApply: _noop,
          clearLabel: 'Clear all',
          applyLabel: 'Show results',
          identifier: 'client_requests_filter_sheet',
          children: <Widget>[
            JeebFilterSheetGroupLabel(text: 'STATUS'),
            SizedBox(height: 24),
          ],
        ),
      );

      expect(find.text('Filter requests'), findsOneWidget);
      expect(find.text('3 applied'), findsOneWidget);
      expect(find.text('STATUS'), findsOneWidget);
      expect(find.text('Clear all'), findsOneWidget);
      expect(find.text('Show results'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('both CTAs fire', (WidgetTester tester) async {
      var clears = 0;
      var applies = 0;
      await pump(
        tester,
        JeebFilterSheetScaffold(
          title: 'Filter offers',
          onClear: () => clears++,
          onApply: () => applies++,
          clearLabel: 'Clear all',
          applyLabel: 'Apply',
          children: const <Widget>[SizedBox(height: 24)],
        ),
      );

      await tester.tap(find.text('Clear all'));
      await tester.tap(find.text('Apply'));
      expect(clears, 1);
      expect(applies, 1);
    });

    testWidgets('clearEnabled: false leaves the ghost CTA inert',
        (WidgetTester tester) async {
      var clears = 0;
      await pump(
        tester,
        JeebFilterSheetScaffold(
          title: 'Filter offers',
          onClear: () => clears++,
          onApply: _noop,
          clearLabel: 'Clear all',
          applyLabel: 'Apply',
          clearEnabled: false,
          children: const <Widget>[SizedBox(height: 24)],
        ),
      );

      await tester.tap(find.text('Clear all'), warnIfMissed: false);
      expect(clears, 0);
    });

    testWidgets('the footer clears the bottom viewPadding',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.midnight(),
          home: const MediaQuery(
            data: MediaQueryData(
              viewPadding: EdgeInsets.only(bottom: 34),
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Scaffold(
                body: JeebFilterSheetScaffold(
                  title: 'Filter requests',
                  onClear: _noop,
                  onApply: _noop,
                  clearLabel: 'Clear all',
                  applyLabel: 'Apply',
                  children: <Widget>[SizedBox(height: 24)],
                ),
              ),
            ),
          ),
        ),
      );

      final Rect cta = tester.getRect(find.text('Apply'));
      final Rect sheet = tester.getRect(find.byType(JeebFilterSheetScaffold));
      expect(sheet.bottom - cta.bottom, greaterThan(34));
    });
  });
}

void _noop() {}
