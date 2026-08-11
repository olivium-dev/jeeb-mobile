import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_radii.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/theme/jeeb_shadows.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_pill_nav.dart';

/// Gates for MIDNIGHT M1-4 (study-notes ruling 2). Expected values come from
/// `docs/redesign-midnight/01-TOKEN-SHEET.md`, never from the implementation.
///
/// FAIL-WITHOUT: the orange-budget test is the only thing standing between the
/// nav and five orange tabs — the failure the master plan §2.2 exists to prevent.
void main() {
  final ThemeData theme = AppTheme.midnight();
  final ColorScheme scheme = theme.colorScheme;
  final JeebSemanticColors semantics = theme.extension<JeebSemanticColors>()!;

  const List<JeebPillNavItem> items = <JeebPillNavItem>[
    JeebPillNavItem(
      icon: Icons.move_to_inbox_rounded,
      label: 'Requests',
      identifier: 'pill_nav_requests',
    ),
    JeebPillNavItem(
      icon: Icons.local_shipping_rounded,
      label: 'Delivery',
      identifier: 'pill_nav_delivery',
    ),
    JeebPillNavItem(
      icon: Icons.dashboard_rounded,
      label: 'Dashboard',
      identifier: 'pill_nav_dashboard',
      semanticLabel: 'Dashboard tab',
    ),
    JeebPillNavItem(
      icon: Icons.account_balance_wallet_rounded,
      label: 'Earnings',
      identifier: 'pill_nav_earnings',
    ),
    JeebPillNavItem(
      icon: Icons.person_rounded,
      label: 'Profile',
      identifier: 'pill_nav_profile',
    ),
  ];

  Widget wrapNav({
    int selectedIndex = 0,
    ValueChanged<int>? onSelected,
    TextDirection direction = TextDirection.ltr,
    ThemeData? themeOverride,
    double width = 440,
  }) {
    return MaterialApp(
      theme: themeOverride ?? theme,
      home: Directionality(
        textDirection: direction,
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: JeebPillNav(
                items: items,
                selectedIndex: selectedIndex,
                onSelected: onSelected ?? (_) {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration capsuleDecoration(WidgetTester tester) {
    final DecoratedBox box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(JeebPillNav),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    return box.decoration as BoxDecoration;
  }

  group('JeebPillNav capsule', () {
    testWidgets('is a navy pill with a 1px glassBorder and floatNav',
        (tester) async {
      await tester.pumpWidget(wrapNav());

      final BoxDecoration decoration = capsuleDecoration(tester);
      expect(decoration.color, scheme.surface);
      expect(decoration.color, const Color(0xFF0B1351));
      expect(decoration.borderRadius, BorderRadius.circular(JeebRadii.pill));
      final Border border = decoration.border! as Border;
      expect(border.top.color, semantics.glassBorder);
      expect(border.top.color, const Color(0x1FFFFFFF));
      expect(border.top.width, 1);
      expect(decoration.boxShadow, JeebShadows.floatNav);
      expect(decoration.boxShadow!.single.color, const Color(0x66000000));
      expect(decoration.boxShadow!.single.offset, const Offset(0, 20));
      expect(decoration.boxShadow!.single.blurRadius, 46);
    });

    testWidgets('detaches 16 from both edges and floats 20 above the bottom',
        (tester) async {
      expect(
        JeebPillNav.defaultMargin.resolve(TextDirection.ltr),
        const EdgeInsets.fromLTRB(16, 0, 16, 20),
      );

      await tester.pumpWidget(wrapNav());
      final Rect host = tester.getRect(find.byType(JeebPillNav));
      final Rect capsule = tester.getRect(find.byType(ClipRRect).first);
      expect(capsule.left - host.left, 16);
      expect(host.right - capsule.right, 16);
      expect(host.bottom - capsule.bottom, 20);
    });

    testWidgets('draws no blur — the capsule is opaque navy', (tester) async {
      await tester.pumpWidget(wrapNav());
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('stands ~72 tall — 12 + 28 + 4 + label + 12', (tester) async {
      await tester.pumpWidget(wrapNav());
      expect(
        tester.getSize(find.byType(ClipRRect).first).height,
        closeTo(72, 4),
        reason: 'R1 measures 72; the capsule must not grow its own box',
      );
    });
  });

  group('JeebPillNav orange budget', () {
    testWidgets('the active pill is the ONLY orange in the nav',
        (tester) async {
      await tester.pumpWidget(wrapNav(selectedIndex: 2));

      const Color orange = Color(0xFFD73B00);

      final Iterable<BoxDecoration> decorations = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(JeebPillNav),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((DecoratedBox box) => box.decoration as BoxDecoration);
      expect(
        decorations.where((BoxDecoration d) => d.color == orange).length,
        1,
        reason: 'exactly one orange fill: the active pill',
      );

      final Iterable<Color?> iconInks = tester
          .widgetList<Icon>(
            find.descendant(
              of: find.byType(JeebPillNav),
              matching: find.byType(Icon),
            ),
          )
          .map((Icon icon) => icon.color);
      expect(iconInks.where((Color? c) => c == orange), isEmpty);

      final Iterable<Color?> labelInks = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(JeebPillNav),
              matching: find.byType(Text),
            ),
          )
          .map((Text text) => text.style?.color);
      expect(labelInks.where((Color? c) => c == orange), isEmpty);
    });

    testWidgets('the active pill is 50x28 accent with white onAccent ink',
        (tester) async {
      await tester.pumpWidget(wrapNav(selectedIndex: 1));

      final BoxDecoration pill = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(JeebPillNav),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((DecoratedBox box) => box.decoration as BoxDecoration)
          .firstWhere((BoxDecoration d) => d.color == const Color(0xFFD73B00));
      expect(pill.borderRadius, BorderRadius.circular(JeebRadii.pill));

      final Icon active = tester.widget<Icon>(
        find.byIcon(Icons.local_shipping_rounded),
      );
      expect(active.size, 18);
      expect(active.color, const Color(0xFFFFFFFF));

      final Size pillSize = tester.getSize(
        find
            .ancestor(
              of: find.byIcon(Icons.local_shipping_rounded),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(pillSize, const Size(50, 28));
    });
  });

  group('JeebPillNav slots', () {
    testWidgets('draws 5 always-visible labels, periwinkle at rest',
        (tester) async {
      await tester.pumpWidget(wrapNav());

      for (final JeebPillNavItem item in items) {
        expect(find.text(item.label), findsOneWidget);
      }

      final TextStyle resting = tester.widget<Text>(find.text('Profile')).style!;
      expect(resting.color, scheme.onSurfaceVariant);
      expect(resting.color, const Color(0xFF8A93D8));
      expect(resting.fontSize, 10.5);
      expect(resting.fontWeight, FontWeight.w600);

      final Icon restingIcon = tester.widget<Icon>(
        find.byIcon(Icons.person_rounded),
      );
      expect(restingIcon.size, 20);
      expect(restingIcon.color, const Color(0xFF8A93D8));
    });

    testWidgets('the active label is onSurface white at full weight',
        (tester) async {
      await tester.pumpWidget(wrapNav(selectedIndex: 4));

      final TextStyle active = tester.widget<Text>(find.text('Profile')).style!;
      expect(active.color, scheme.onSurface);
      expect(active.color, const Color(0xFFEDEFFC));
      expect(active.fontSize, 10.5);
      expect(active.fontWeight, FontWeight.w700);
    });

    testWidgets('every icon band is 28 tall and sits 4 above its label',
        (tester) async {
      await tester.pumpWidget(wrapNav());
      expect(JeebPillNav.iconRowHeight, 28);
      expect(JeebPillNav.iconLabelGap, 4);

      final Rect band = tester.getRect(
        find
            .ancestor(
              of: find.byIcon(Icons.local_shipping_rounded),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(band.height, 28);
      expect(tester.getRect(find.text('Delivery')).top - band.bottom, 4);
    });

    testWidgets('reports the tapped index, re-taps included', (tester) async {
      final List<int> taps = <int>[];
      await tester.pumpWidget(
        wrapNav(selectedIndex: 0, onSelected: taps.add),
      );

      await tester.tap(find.text('Earnings'));
      await tester.tap(find.text('Requests'));
      expect(taps, <int>[3, 0]);
    });
  });

  group('JeebPillNav hit targets', () {
    testWidgets('each slot clears 48dp without inflating any metric',
        (tester) async {
      await tester.pumpWidget(wrapNav());

      for (final JeebPillNavItem item in items) {
        final Size slot = tester.getSize(
          find.bySemanticsIdentifier(item.identifier),
        );
        expect(
          slot.width,
          greaterThanOrEqualTo(JeebPillNav.minTapTarget),
          reason: '${item.identifier} is too narrow to tap',
        );
        expect(
          slot.height,
          greaterThanOrEqualTo(JeebPillNav.minTapTarget),
          reason: '${item.identifier} is too short to tap',
        );
      }

      // Hit-test expansion, not layout: the visible column is icon band + gap +
      // label, and the 12/12 padding is inside the tappable slot.
      final Rect slot =
          tester.getRect(find.bySemanticsIdentifier('pill_nav_delivery'));
      final Rect icons = tester.getRect(
        find
            .ancestor(
              of: find.byIcon(Icons.local_shipping_rounded),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(icons.top - slot.top, JeebPillNav.slotVerticalPadding);
      expect(
        slot.bottom - tester.getRect(find.text('Delivery')).bottom,
        JeebPillNav.slotVerticalPadding,
      );
    });

    testWidgets('a tap on the padding still selects the slot', (tester) async {
      final List<int> taps = <int>[];
      await tester.pumpWidget(wrapNav(onSelected: taps.add));

      final Rect slot =
          tester.getRect(find.bySemanticsIdentifier('pill_nav_earnings'));
      await tester.tapAt(Offset(slot.center.dx, slot.top + 2));
      expect(taps, <int>[3]);
    });
  });

  group('JeebPillNav semantics', () {
    testWidgets('every slot emits its frozen identifier as a button',
        (tester) async {
      await tester.pumpWidget(wrapNav(selectedIndex: 2));

      for (final JeebPillNavItem item in items) {
        final Finder node = find.bySemanticsIdentifier(item.identifier);
        expect(node, findsOneWidget, reason: item.identifier);
        final SemanticsNode semanticsNode = tester.getSemantics(node);
        expect(semanticsNode.label, item.semanticLabel ?? item.label);
        expect(semanticsNode.flagsCollection.isButton, isTrue);
      }

      expect(
        tester
            .getSemantics(find.bySemanticsIdentifier('pill_nav_dashboard'))
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      expect(
        tester
            .getSemantics(find.bySemanticsIdentifier('pill_nav_profile'))
            .flagsCollection
            .isSelected,
        Tristate.isFalse,
      );
    });
  });

  group('JeebPillNav RTL', () {
    testWidgets('mirrors slot order and keeps identifiers put', (tester) async {
      await tester.pumpWidget(wrapNav(direction: TextDirection.rtl));

      final double first =
          tester.getCenter(find.bySemanticsIdentifier('pill_nav_requests')).dx;
      final double last =
          tester.getCenter(find.bySemanticsIdentifier('pill_nav_profile')).dx;
      expect(first, greaterThan(last), reason: 'slot 1 sits at the start edge');
      expect(tester.takeException(), isNull);
    });

    testWidgets('the margin mirrors with the text direction', (tester) async {
      await tester.pumpWidget(
        wrapNav(direction: TextDirection.rtl),
      );

      final Rect host = tester.getRect(find.byType(JeebPillNav));
      final Rect capsule = tester.getRect(find.byType(ClipRRect).first);
      expect(capsule.left - host.left, 16);
      expect(host.right - capsule.right, 16);
    });

    testWidgets('taps land on the right slot under RTL', (tester) async {
      final List<int> taps = <int>[];
      await tester.pumpWidget(
        wrapNav(direction: TextDirection.rtl, onSelected: taps.add),
      );

      await tester.tap(find.text('Dashboard'));
      expect(taps, <int>[2]);
    });
  });

  testWidgets('survives a bare ThemeData.light() harness', (tester) async {
    await tester.pumpWidget(wrapNav(themeOverride: ThemeData.light()));
    expect(tester.takeException(), isNull);
  });

  // Close-out 2026-08-11: five fixed-width slots cannot grow, so an unclamped
  // 2.0 accessibility scale ellipsized every label down to nothing.
  testWidgets('nav labels clamp their text scale so they degrade, not vanish',
      (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: wrapNav(),
      ),
    );

    final Text label = tester.widget<Text>(find.text('Requests'));
    expect(
      label.textScaler?.scale(10),
      10 * JeebPillNav.maxLabelTextScale,
    );
    expect(tester.takeException(), isNull);
  });
}
