import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_list_row.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_navy_surface_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_outlined_card.dart';

import 'jeeb_card_test_harness.dart';

/// Gates for redesign-2026-08 §5 #25.
///
/// FAIL-WITHOUT: 20 and 23 both re-home frozen identifiers onto this row. A
/// hardcoded `Icons.chevron_right`, a swallowed identifier or a lost
/// `showChevron` escape hatch each break a shipped Maestro flow silently —
/// Maestro is not in CI.
void main() {
  final ColorScheme scheme = AppTheme.light().colorScheme;
  final Color muted = (AppTheme.light().extension<JeebSemanticColors>() ??
          JeebSemanticColors.light())
      .mutedText;

  // 23's Earnings row, verbatim (`tpl 1387-1394`).
  Widget earningsRow({VoidCallback? onTap}) => JeebListRow(
        icon: Icons.show_chart,
        title: 'Earnings',
        subtitle: 'Cash collected, fees paid',
        onTap: onTap ?? () {},
      );

  group('JeebListRow anatomy', () {
    testWidgets('navy glyph, navy w700 title, muted subtitle, muted chevron',
        (tester) async {
      await tester.pumpWidget(wrapCard(earningsRow()));

      final Icon glyph = tester.widget<Icon>(find.byIcon(Icons.show_chart));
      expect(glyph.size, 19);
      expect(glyph.color, scheme.primary);

      final TextStyle title = tester.widget<Text>(find.text('Earnings')).style!;
      expect(title.fontSize, 14);
      expect(title.fontWeight, FontWeight.w700);
      expect(title.color, scheme.primary);

      final TextStyle subtitle = tester
          .widget<Text>(find.text('Cash collected, fees paid'))
          .style!;
      expect(subtitle.fontSize, 11.5);
      expect(subtitle.fontWeight, FontWeight.w500);
      expect(subtitle.color, muted);

      final Icon chevron =
          tester.widget<Icon>(find.byIcon(Icons.chevron_right));
      expect(chevron.size, 16);
      expect(chevron.color, muted);
    });

    testWidgets('pads 14/16', (tester) async {
      await tester.pumpWidget(wrapCard(earningsRow()));

      final Padding padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(JeebListRow),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect(
        padding.padding.resolve(TextDirection.ltr),
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
    });

    testWidgets('subtitle is optional', (tester) async {
      await tester.pumpWidget(
        wrapCard(const JeebListRow(title: 'Addresses')),
      );

      expect(find.text('Addresses'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('showChevron:false drops the chevron — 20 sign-out row',
        (tester) async {
      await tester.pumpWidget(
        wrapCard(
          JeebListRow(
            icon: Icons.logout,
            iconSize: 18,
            title: 'Sign out',
            showChevron: false,
            onTap: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(tester.widget<Icon>(find.byIcon(Icons.logout)).size, 18);
    });

    testWidgets('a partial titleStyle override keeps the surface ink',
        (tester) async {
      // 20's sign-out row overrides weight only; it must not lose the ink.
      await tester.pumpWidget(
        wrapCard(
          const JeebListRow(
            title: 'Sign out',
            titleStyle: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      );

      final TextStyle style = tester.widget<Text>(find.text('Sign out')).style!;
      expect(style.fontWeight, FontWeight.w600);
      expect(style.color, scheme.primary);
    });

    testWidgets('a trailing widget replaces the chevron', (tester) async {
      await tester.pumpWidget(
        wrapCard(
          const JeebListRow(
            title: 'Reserved right now',
            trailing: Text(r'$0.80'),
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.text(r'$0.80'), findsOneWidget);
    });
  });

  group('JeebListRow interaction', () {
    testWidgets('taps fire', (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrapCard(earningsRow(onTap: () => taps++)));

      await tester.tap(find.text('Earnings'));
      expect(taps, 1);
    });

    testWidgets('disabled rows dim and swallow taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrapCard(
          JeebListRow(
            title: 'Sign out',
            isEnabled: false,
            onTap: () => taps++,
          ),
        ),
      );

      await tester.tap(find.text('Sign out'));
      expect(taps, 0);
      final Opacity opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(JeebListRow),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, JeebListRow.disabledOpacity);
    });
  });

  group('JeebListRow semantics', () {
    testWidgets('carries the identifier and merges title + subtitle',
        (tester) async {
      await tester.pumpWidget(
        wrapCard(
          JeebListRow(
            identifier: 'wallet_earnings_row',
            icon: Icons.show_chart,
            title: 'Earnings',
            subtitle: 'Cash collected, fees paid',
            onTap: () {},
          ),
        ),
      );

      final Finder row = find.bySemanticsIdentifier('wallet_earnings_row');
      expect(row, findsOneWidget);
      // One labelled button node, not three unlabelled fragments.
      expect(
        tester.getSemantics(row).label,
        'Earnings\nCash collected, fees paid',
      );
    });

    testWidgets('adds no node when the consumer owns it', (tester) async {
      // 23 and today's `wallet_hub_screen.dart` wrap the row themselves; a
      // second button node inside the first is a regression, not a detail.
      await tester.pumpWidget(
        wrapCard(
          Semantics(
            identifier: 'wallet_see_all_activity',
            button: true,
            container: true,
            child: JeebListRow(title: 'All activity', onTap: () {}),
          ),
        ),
      );

      final Finder row = find.bySemanticsIdentifier('wallet_see_all_activity');
      expect(row, findsOneWidget);
      expect(tester.getSemantics(row).label, 'All activity');
      expect(
        find.descendant(
          of: find.byType(JeebListRow),
          matching: find.byWidgetPredicate(
            (Widget widget) => widget is Semantics && widget.container,
          ),
        ),
        findsNothing,
        reason: 'a second container node inside the consumer\'s own node '
            'splits the row into two announcements',
      );
    });
  });

  group('JeebListRow composition', () {
    testWidgets('a grouped card owns the 1px inset divider between rows',
        (tester) async {
      await tester.pumpWidget(
        wrapCard(
          JeebOutlinedCard.grouped(
            children: <Widget>[
              JeebListRow(title: 'Earnings', onTap: () {}),
              JeebListRow(title: 'All activity', onTap: () {}),
            ],
          ),
        ),
      );

      // n-1 rules, drawn by the card because only it knows which row is last.
      final Finder rules = find.descendant(
        of: find.byType(JeebOutlinedCard),
        matching: find.byType(ColoredBox),
      );
      expect(rules, findsOneWidget);
      expect(tester.widget<ColoredBox>(rules).color, scheme.outlineVariant);
      expect(tester.getSize(rules).height, 1);
    });

    testWidgets('re-tones itself on a navy surface — no onNavy flag',
        (tester) async {
      await tester.pumpWidget(
        wrapCard(
          JeebNavySurfaceCard(
            child: JeebListRow(
              icon: Icons.show_chart,
              title: 'Earnings',
              subtitle: 'Cash collected, fees paid',
              onTap: () {},
            ),
          ),
        ),
      );

      expect(
        tester.widget<Text>(find.text('Earnings')).style!.color,
        scheme.onPrimary,
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.show_chart)).color,
        scheme.onPrimary,
      );
      expect(
        tester.widget<Text>(find.text('Cash collected, fees paid')).style!.color,
        scheme.onPrimary.withValues(alpha: 0.7),
      );
    });
  });

  group('JeebListRow RTL', () {
    testWidgets('the chevron mirrors via DirectionalIcons', (tester) async {
      await tester.pumpWidget(
        wrapCard(earningsRow(), direction: TextDirection.rtl),
      );

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('glyph leads from the end side, chevron trails at the start',
        (tester) async {
      await tester.pumpWidget(
        wrapCard(earningsRow(), direction: TextDirection.rtl),
      );

      expect(tester.takeException(), isNull);
      final double glyph = tester.getTopLeft(find.byIcon(Icons.show_chart)).dx;
      final double title = tester.getTopLeft(find.text('Earnings')).dx;
      final double chevron =
          tester.getTopLeft(find.byIcon(Icons.chevron_left)).dx;
      expect(glyph, greaterThan(title));
      expect(chevron, lessThan(title));
    });
  });
}
