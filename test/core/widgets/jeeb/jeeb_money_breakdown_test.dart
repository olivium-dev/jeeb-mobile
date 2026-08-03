import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/jeeb_commission.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_money_breakdown.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_outlined_card.dart';

import 'jeeb_card_test_harness.dart';

/// Gates for redesign-2026-08 §5 #24.
///
/// FAIL-WITHOUT: this is the only widget every platform-fee row passes
/// through. If the D41/D44 guard goes, "Commission" can reach a Jeeber's
/// screen from any of 24 lanes and nothing else in the suite notices until
/// `decision_violations_test` catches one already-shipped screen.
void main() {
  final ColorScheme scheme = AppTheme.light().colorScheme;
  final Color muted = (AppTheme.light().extension<JeebSemanticColors>() ??
          JeebSemanticColors.light())
      .mutedText;

  // 17's economics card, verbatim (`tpl 1010-1023`) minus the board's refused
  // "Jeeb fee" framing.
  Widget composerCard() => JeebMoneyBreakdown(
        rows: <JeebMoneyLine>[
          const JeebMoneyLine(
            label: 'Your offer',
            value: r'$8.00',
            identifier: 'offer_composer_offer_line',
          ),
          JeebMoneyLine(
            label: 'Platform fee (${JeebMoneyBreakdown.feePercent}%)',
            value: r'−$0.80',
            identifier: 'offer_composer_fee_line',
          ),
        ],
        total: const JeebMoneyLine(
          label: 'You keep (cash)',
          value: r'$7.20',
          identifier: 'offer_composer_net_line',
        ),
        footnote: r'$0.80 is reserved from your wallet now — released if '
            "you're not picked.",
        footnoteIdentifier: 'offer_composer_reserve_note',
      );

  group('JeebMoneyBreakdown shell', () {
    testWidgets('is an outlined r16 card with NO shadow', (tester) async {
      await tester.pumpWidget(wrapCard(composerCard()));

      expect(find.byType(JeebOutlinedCard), findsOneWidget);
      final BoxDecoration decoration =
          decorationOf(tester, find.byType(JeebMoneyBreakdown));
      expect(decoration.color, scheme.surface);
      expect(decoration.boxShadow, isNull, reason: 'R7: outline-over-shadow');
      expect(decoration.borderRadius, BorderRadius.circular(16));
      final Border border = decoration.border! as Border;
      expect(border.top.color, scheme.outline);
      expect(border.top.width, 1.5);
    });

    testWidgets('pads 15/16 (plus the card stroke it paints over)',
        (tester) async {
      await tester.pumpWidget(wrapCard(composerCard()));

      final Padding padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(JeebMoneyBreakdown),
              matching: find.byType(Padding),
            )
            .first,
      );
      // Border-box correction: the 1.5px stroke sits outside the CSS padding.
      expect(
        padding.padding.resolve(TextDirection.ltr),
        const EdgeInsets.symmetric(horizontal: 17.5, vertical: 16.5),
      );
    });

    testWidgets('draws a 1px outlineVariant rule above the total',
        (tester) async {
      await tester.pumpWidget(wrapCard(composerCard()));

      final Finder ruleFinder = find.descendant(
        of: find.byType(JeebMoneyBreakdown),
        matching: find.byType(ColoredBox),
      );
      expect(tester.widget<ColoredBox>(ruleFinder).color, scheme.outlineVariant);
      expect(tester.getSize(ruleFinder).height, 1);
    });

    testWidgets('no total means no rule', (tester) async {
      await tester.pumpWidget(
        wrapCard(
          const JeebMoneyBreakdown(
            rows: <JeebMoneyLine>[
              JeebMoneyLine(label: 'Your offer', value: r'$8.00'),
            ],
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(JeebMoneyBreakdown),
          matching: find.byType(ColoredBox),
        ),
        findsNothing,
      );
    });
  });

  group('JeebMoneyBreakdown typography', () {
    testWidgets('row = 13.5/w600 muted label + 13.5/w700 navy value',
        (tester) async {
      await tester.pumpWidget(wrapCard(composerCard()));

      final TextStyle label = tester.widget<Text>(find.text('Your offer')).style!;
      expect(label.fontSize, 13.5);
      expect(label.fontWeight, FontWeight.w600);
      expect(label.color, muted);

      final TextStyle value = tester.widget<Text>(find.text(r'$8.00')).style!;
      expect(value.fontSize, 13.5);
      expect(value.fontWeight, FontWeight.w700);
      expect(value.color, scheme.onSurface);
    });

    testWidgets('total = 15/w800 with a 17px value', (tester) async {
      await tester.pumpWidget(wrapCard(composerCard()));

      final TextStyle label =
          tester.widget<Text>(find.text('You keep (cash)')).style!;
      expect(label.fontSize, 15);
      expect(label.fontWeight, FontWeight.w800);
      expect(label.color, scheme.onSurface);

      final TextStyle value = tester.widget<Text>(find.text(r'$7.20')).style!;
      expect(value.fontSize, 17);
      expect(value.fontWeight, FontWeight.w800);
    });

    testWidgets('footnote = 11.5/w500 muted + a 14px filled lock',
        (tester) async {
      await tester.pumpWidget(wrapCard(composerCard()));

      final TextStyle note = tester
          .widget<Text>(find.textContaining('reserved from your wallet'))
          .style!;
      expect(note.fontSize, 11.5);
      expect(note.fontWeight, FontWeight.w500);
      expect(note.color, muted);

      final Icon lock = tester.widget<Icon>(find.byType(Icon));
      expect(lock.icon, Icons.lock, reason: 'R10: filled, no outline variants');
      expect(lock.size, 14);
      expect(lock.color, muted);
    });

    testWidgets('a valueless row renders the label alone — 17 pending state',
        (tester) async {
      await tester.pumpWidget(
        wrapCard(
          const JeebMoneyBreakdown(
            rows: <JeebMoneyLine>[
              JeebMoneyLine(label: 'Platform fee: 10% of your offer'),
            ],
          ),
        ),
      );

      expect(find.text('Platform fee: 10% of your offer'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(JeebMoneyBreakdown),
          matching: find.byType(Text),
        ),
        findsOneWidget,
        reason: 'the card must look deliberate, never blank or half-empty',
      );
    });
  });

  group('JeebMoneyBreakdown semantics', () {
    testWidgets('every line can carry a frozen identifier', (tester) async {
      await tester.pumpWidget(wrapCard(composerCard()));

      // Maestro jm-045 AC1 addresses all three by id.
      expect(
        find.bySemanticsIdentifier('offer_composer_offer_line'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('offer_composer_fee_line'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('offer_composer_net_line'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('offer_composer_reserve_note'),
        findsOneWidget,
      );
    });

    testWidgets('adds no node for a line that asks for none', (tester) async {
      await tester.pumpWidget(
        wrapCard(
          const JeebMoneyBreakdown(
            rows: <JeebMoneyLine>[
              JeebMoneyLine(label: 'Your offer', value: r'$8.00'),
            ],
          ),
        ),
      );

      // The consumer may own the node itself; an unconditional wrapper would
      // sit between their container node and its children.
      expect(
        find.descendant(
          of: find.byType(JeebMoneyBreakdown),
          matching: find.byType(Semantics),
        ),
        findsNothing,
      );
    });
  });

  group('D41/D44 — the single enforcement point', () {
    testWidgets('accepts the shipped Platform-fee framing', (tester) async {
      await tester.pumpWidget(wrapCard(composerCard()));

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Platform fee'), findsOneWidget);
      expect(find.textContaining('Commission'), findsNothing);
    });

    testWidgets('refuses a Commission label', (tester) async {
      await tester.pumpWidget(
        wrapCard(
          const JeebMoneyBreakdown(
            rows: <JeebMoneyLine>[
              JeebMoneyLine(label: 'Commission (10%)', value: r'−$0.80'),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('refuses the Arabic commission framing too', (tester) async {
      await tester.pumpWidget(
        wrapCard(
          const JeebMoneyBreakdown(
            rows: <JeebMoneyLine>[
              JeebMoneyLine(label: 'عمولة المنصة', value: r'−$0.80'),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('refuses a percentage that disagrees with the rate',
        (tester) async {
      await tester.pumpWidget(
        wrapCard(
          const JeebMoneyBreakdown(
            rows: <JeebMoneyLine>[
              // The gateway tier catalogue advertised 25% for weeks while
              // settlement paid 10%. Copy-pasting that number is the defect.
              JeebMoneyLine(label: 'Platform fee (25%)', value: r'−$2.00'),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isAssertionError);
    });

    test('the fee math derives from kJeebCommissionRate', () {
      expect(JeebMoneyBreakdown.platformFeeOn(8), closeTo(0.8, 1e-9));
      expect(JeebMoneyBreakdown.netKeptFrom(8), closeTo(7.2, 1e-9));
      expect(
        JeebMoneyBreakdown.platformFeeOn(8),
        closeTo(8 * kJeebCommissionRate, 1e-9),
      );
      expect(JeebMoneyBreakdown.feePercent, kJeebCommissionPercent);
    });
  });

  group('JeebMoneyBreakdown RTL', () {
    testWidgets('mirrors label and amount, and lays out without overflow',
        (tester) async {
      await tester.pumpWidget(
        wrapCard(composerCard(), direction: TextDirection.rtl),
      );

      expect(tester.takeException(), isNull);
      final double label = tester.getTopLeft(find.text('Your offer')).dx;
      final double value = tester.getTopLeft(find.text(r'$8.00')).dx;
      expect(
        value,
        lessThan(label),
        reason: 'the amount sits at the visual END, which is the left in RTL',
      );
    });

    testWidgets('the footnote glyph leads from the end side', (tester) async {
      await tester.pumpWidget(
        wrapCard(composerCard(), direction: TextDirection.rtl),
      );

      final double lock = tester.getTopLeft(find.byType(Icon)).dx;
      final double note = tester
          .getTopLeft(find.textContaining('reserved from your wallet'))
          .dx;
      expect(lock, greaterThan(note));
    });
  });
}
