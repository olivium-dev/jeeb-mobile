import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_navy_surface_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_outlined_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_price_meter.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_tier_chip.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_tier_row.dart';

import 'jeeb_remainder_test_harness.dart';

/// Gates for redesign-2026-08 §5 #8.
///
/// FAIL-WITHOUT: 07's a11y node is read byte for byte by
/// `delivery_create_screens_test.dart:130,137` (`flagsCollection.isChecked`).
/// If `.compact` drifts to the `selected:` shape that 08 uses, those tests fail
/// in a way that looks like a screen bug and gets "fixed" in the wrong file.
void main() {
  final ThemeData theme = AppTheme.light();
  final ColorScheme scheme = theme.colorScheme;
  final JeebColorRoles roles = theme.extension<JeebColorRoles>()!;
  final JeebSemanticColors semantics = theme.extension<JeebSemanticColors>()!;

  Widget compact({
    bool selected = false,
    String? badge,
    VoidCallback? onTap,
  }) {
    return JeebTierRow.compact(
      mark: '⚡',
      title: 'Flash',
      summary: 'Under 1 hour · Highest price',
      badge: badge,
      selected: selected,
      identifier: 'request_type_flash_radio',
      semanticLabel: 'Flash. Under 1 hour · Highest price.',
      selectedHint: 'Selected',
      onTap: onTap ?? () {},
    );
  }

  Widget catalog({
    bool selected = false,
    String? badgeLabel,
    IconData? metaIcon = Icons.two_wheeler,
    bool slaForceLtr = true,
    VoidCallback? onTap,
  }) {
    return JeebTierRow.catalog(
      emoji: '⚡',
      name: 'Flash',
      priceLevel: 4,
      priceCaption: 'Highest price',
      slaLabel: '≤ 1 hr',
      metaLabel: 'Bike / scooter',
      metaIcon: metaIcon,
      badgeLabel: badgeLabel,
      slaForceLtr: slaForceLtr,
      selected: selected,
      identifier: 'tier_selection_card_flash',
      semanticLabel: 'Flash. Up to one hour. Bike or scooter. Highest price.',
      selectedHint: 'Selected tier',
      onTap: onTap ?? () {},
    );
  }

  group('JeebTierRow.compact', () {
    testWidgets('unselected is a white outlined card, r16, pad 14/16',
        (tester) async {
      await tester.pumpWidget(wrapRemainder(compact()));

      expect(find.byType(JeebOutlinedCard), findsOneWidget);
      final JeebOutlinedCard card =
          tester.widget<JeebOutlinedCard>(find.byType(JeebOutlinedCard));
      expect(card.state, JeebCardState.normal);
      expect(card.radius, 16);
      expect(card.padding, JeebTierRow.compactPadding);
    });

    testWidgets('selected is a navy fill swap with 0 10 22 — not a border',
        (tester) async {
      await tester.pumpWidget(wrapRemainder(compact(selected: true)));

      expect(find.byType(JeebNavySurfaceCard), findsOneWidget);
      final BoxDecoration decoration =
          remainderDecorationOf(tester, find.byType(JeebNavySurfaceCard));
      expect(decoration.color, scheme.primary);
      expect(decoration.border, isNull);
      expect(decoration.boxShadow, JeebNavySurfaceCard.selectedShadow);
    });

    testWidgets('the indicator is an accent disc + white check when selected',
        (tester) async {
      await tester.pumpWidget(wrapRemainder(compact(selected: true)));

      // The HTML wins over plan §5 #8's inverted description: tpl 361 is
      // `background: var(--jeeb-orange)` with `fill="#fff"`.
      final Finder disc = find.descendant(
        of: find.byType(JeebTierRow),
        matching: find.byType(Container),
      );
      final Container indicator = tester.widget<Container>(disc.last);
      final BoxDecoration decoration = indicator.decoration! as BoxDecoration;
      expect(decoration.color, roles.accent);
      expect(decoration.shape, BoxShape.circle);
      expect(tester.getSize(disc.last), const Size(22, 22));

      final Icon check = tester.widget<Icon>(find.byIcon(Icons.check));
      expect(check.color, roles.onAccent);
      expect(check.size, 13);
    });

    testWidgets('the indicator is a 2px ring when unselected', (tester) async {
      await tester.pumpWidget(wrapRemainder(compact()));

      final Finder disc = find.descendant(
        of: find.byType(JeebTierRow),
        matching: find.byType(Container),
      );
      final BoxDecoration decoration =
          tester.widget<Container>(disc.last).decoration! as BoxDecoration;
      expect(decoration.color, isNull);
      expect(
        (decoration.border! as Border).top.color,
        scheme.surfaceContainerHighest,
      );
      expect((decoration.border! as Border).top.width, 2);
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('title is 16/w700 and summary 12/w500, both re-toned on navy',
        (tester) async {
      await tester.pumpWidget(wrapRemainder(compact()));
      final TextStyle title = tester.widget<Text>(find.text('Flash')).style!;
      expect(title.fontSize, 16);
      expect(title.fontWeight, FontWeight.w700);
      expect(title.color, scheme.onSurface);

      final TextStyle summary = tester
          .widget<Text>(find.text('Under 1 hour · Highest price'))
          .style!;
      expect(summary.fontSize, 12);
      expect(summary.fontWeight, FontWeight.w500);
      expect(summary.color, semantics.mutedText);

      await tester.pumpWidget(wrapRemainder(compact(selected: true)));
      expect(
        tester.widget<Text>(find.text('Flash')).style!.color,
        scheme.onPrimary,
      );
      expect(
        tester
            .widget<Text>(find.text('Under 1 hour · Highest price'))
            .style!
            .color,
        scheme.onPrimary.withValues(alpha: 0.7),
        reason: 'the re-tone comes from the card, not from a parameter',
      );
    });

    testWidgets('has no price meter — 07 draws zero meter dots',
        (tester) async {
      await tester.pumpWidget(wrapRemainder(compact()));
      expect(find.byType(JeebPriceMeter), findsNothing);
    });

    testWidgets(
        'the Most picked badge is the one accentTint use, and goes solid on navy',
        (tester) async {
      await tester.pumpWidget(wrapRemainder(compact(badge: 'Most picked')));
      final BoxDecoration tinted = tester
          .widget<DecoratedBox>(
            find
                .ancestor(
                  of: find.text('Most picked'),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          )
          .decoration as BoxDecoration;
      expect(tinted.color, semantics.accentTint);
      final TextStyle label =
          tester.widget<Text>(find.text('Most picked')).style!;
      expect(label.fontSize, 10.5);
      expect(label.fontWeight, FontWeight.w800);
      expect(label.color, roles.accent);

      // 07's default tier is also the flagged one, so selected + badged is a
      // real state: a 12% tint on navy would be invisible.
      await tester.pumpWidget(
        wrapRemainder(compact(badge: 'Most picked', selected: true)),
      );
      final BoxDecoration solid = tester
          .widget<DecoratedBox>(
            find
                .ancestor(
                  of: find.text('Most picked'),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          )
          .decoration as BoxDecoration;
      expect(solid.color, roles.accent);
      expect(
        tester.widget<Text>(find.text('Most picked')).style!.color,
        roles.onAccent,
      );
    });

    testWidgets('emits RequestTierCard\'s a11y node byte for byte',
        (tester) async {
      await tester.pumpWidget(wrapRemainder(compact(selected: true)));

      final Finder node =
          find.bySemanticsIdentifier('request_type_flash_radio');
      final SemanticsNode data = tester.getSemantics(node);
      expect(data.flagsCollection.isChecked, CheckedState.isTrue);
      expect(data.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.label, 'Flash. Under 1 hour · Highest price.');
      expect(data.hint, 'Selected');

      await tester.pumpWidget(wrapRemainder(compact()));
      final SemanticsNode unselected = tester.getSemantics(node);
      expect(unselected.flagsCollection.isChecked, CheckedState.isFalse);
      expect(unselected.hint, isEmpty, reason: 'the hint is selected-only');
    });

    testWidgets('fires onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrapRemainder(compact(onTap: () => taps++)));
      await tester.tap(find.text('Flash'));
      expect(taps, 1);
    });
  });

  group('JeebTierRow.catalog', () {
    testWidgets('delegates the price meter and the SLA chip', (tester) async {
      await tester.pumpWidget(wrapRemainder(catalog()));

      final JeebPriceMeter meter =
          tester.widget<JeebPriceMeter>(find.byType(JeebPriceMeter));
      expect(meter.level, 4);
      expect(meter.caption, 'Highest price');

      expect(find.byType(JeebTierChip), findsOneWidget);
      expect(find.text('≤ 1 hr'), findsOneWidget);
    });

    testWidgets('isolates a latin-numeric SLA label to LTR, with an opt-out',
        (tester) async {
      await tester.pumpWidget(
        wrapRemainder(catalog(), direction: TextDirection.rtl),
      );
      expect(
        Directionality.of(tester.element(find.byType(JeebTierChip))),
        TextDirection.ltr,
      );

      await tester.pumpWidget(
        wrapRemainder(
          catalog(slaForceLtr: false),
          direction: TextDirection.rtl,
        ),
      );
      expect(
        Directionality.of(tester.element(find.byType(JeebTierChip))),
        TextDirection.rtl,
        reason: 'a pure-Arabic label must follow the ambient direction',
      );
    });

    testWidgets('the check appears only when selected, at the second row end',
        (tester) async {
      await tester.pumpWidget(wrapRemainder(catalog()));
      expect(find.byIcon(Icons.check), findsNothing);

      await tester.pumpWidget(wrapRemainder(catalog(selected: true)));
      final Icon check = tester.widget<Icon>(find.byIcon(Icons.check));
      expect(check.size, JeebTierRow.checkSize);
      expect(check.color, scheme.onPrimary);
      // Second row: below the tier name, and at the row's end edge.
      expect(
        tester.getCenter(find.byIcon(Icons.check)).dy,
        greaterThan(tester.getCenter(find.text('Flash')).dy),
      );
      expect(
        tester.getCenter(find.byIcon(Icons.check)).dx,
        greaterThan(tester.getCenter(find.text('Bike / scooter')).dx),
      );
    });

    testWidgets('the Recommended badge is a solid accent pill at 10/w800',
        (tester) async {
      await tester.pumpWidget(
        wrapRemainder(catalog(badgeLabel: 'Recommended')),
      );

      final BoxDecoration pill = tester
          .widget<DecoratedBox>(
            find
                .ancestor(
                  of: find.text('Recommended'),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          )
          .decoration as BoxDecoration;
      expect(pill.color, roles.accent);

      final TextStyle label =
          tester.widget<Text>(find.text('Recommended')).style!;
      expect(label.fontSize, 10);
      expect(label.fontWeight, FontWeight.w800);
      expect(label.color, roles.onAccent);
    });

    testWidgets('the vehicle glyph is optional and muted', (tester) async {
      await tester.pumpWidget(wrapRemainder(catalog()));
      expect(
        tester.widget<Icon>(find.byIcon(Icons.two_wheeler)).color,
        semantics.mutedText,
      );

      await tester.pumpWidget(wrapRemainder(catalog(metaIcon: null)));
      expect(find.byIcon(Icons.two_wheeler), findsNothing);
    });

    testWidgets('keeps tier_card.dart\'s a11y shape (container + selected)',
        (tester) async {
      await tester.pumpWidget(wrapRemainder(catalog(selected: true)));

      final SemanticsNode data = tester.getSemantics(
        find.bySemanticsIdentifier('tier_selection_card_flash'),
      );
      expect(data.flagsCollection.isSelected, Tristate.isTrue);
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hint, 'Selected tier');
      expect(
        data.label,
        'Flash. Up to one hour. Bike or scooter. Highest price.',
      );
    });

    testWidgets('the meter and chip invert on the selected card', (tester) async {
      await tester.pumpWidget(wrapRemainder(catalog(selected: true)));

      // Caption ink proves the tone reached the delegated meter.
      expect(
        tester.widget<Text>(find.text('Highest price')).style!.color,
        scheme.onPrimary.withValues(alpha: 0.7),
      );
      expect(
        tester.widget<Text>(find.text('≤ 1 hr')).style!.color,
        scheme.onPrimary,
      );
    });

    testWidgets('fires onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrapRemainder(catalog(onTap: () => taps++)));
      await tester.tap(find.text('Flash'));
      expect(taps, 1);
    });
  });

  group('JeebTierRow RTL smoke', () {
    testWidgets('compact mirrors: emoji at the start, indicator at the end',
        (tester) async {
      await tester.pumpWidget(wrapRemainder(compact()));
      final double ltrMark = tester.getCenter(find.text('⚡')).dx;
      final double ltrTitle = tester.getCenter(find.text('Flash')).dx;
      expect(ltrMark, lessThan(ltrTitle));

      await tester.pumpWidget(
        wrapRemainder(compact(), direction: TextDirection.rtl),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getCenter(find.text('⚡')).dx,
        greaterThan(tester.getCenter(find.text('Flash')).dx),
      );
    });

    testWidgets('catalog mirrors: the meter follows the end edge',
        (tester) async {
      await tester.pumpWidget(wrapRemainder(catalog()));
      expect(
        tester.getCenter(find.byType(JeebPriceMeter)).dx,
        greaterThan(tester.getCenter(find.text('Flash')).dx),
      );

      await tester.pumpWidget(
        wrapRemainder(catalog(), direction: TextDirection.rtl),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getCenter(find.byType(JeebPriceMeter)).dx,
        lessThan(tester.getCenter(find.text('Flash')).dx),
      );
    });

    testWidgets('the selected catalog check mirrors to the start edge',
        (tester) async {
      await tester.pumpWidget(
        wrapRemainder(catalog(selected: true), direction: TextDirection.rtl),
      );
      expect(
        tester.getCenter(find.byIcon(Icons.check)).dx,
        lessThan(tester.getCenter(find.text('Bike / scooter')).dx),
      );
    });
  });

  testWidgets('both forms survive a bare ThemeData.light() harness',
      (tester) async {
    await tester.pumpWidget(
      wrapUnthemed(
        Column(
          children: <Widget>[
            compact(badge: 'Most picked'),
            catalog(badgeLabel: 'Recommended', selected: true),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
