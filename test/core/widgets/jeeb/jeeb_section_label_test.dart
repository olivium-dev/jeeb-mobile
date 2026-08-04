import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_section_label.dart';

import 'jeeb_meters_test_harness.dart';

/// Gates for the section header (§5 #10).
///
/// FAIL-WITHOUT: without the internal case transform 6 lanes each ship a
/// `.toUpperCase()` at the call site and the Arabic build runs a case
/// transform on a caseless script; without the `hint` slot 17 renders two
/// `Text`s that wrap and align independently; without the size default the
/// 11px minority reading spreads to all six screens.
void main() {
  // Token sheet §3: mutedText, superseding #777FC0 AND pass-1 dark #9DA3E0.
  const Color midnightMuted = Color(0xFF8A93D8);

  TextStyle styleOf(WidgetTester tester) =>
      tester.widget<Text>(find.byType(Text)).style!;

  group('casing', () {
    testWidgets('uppercases the label internally under en', (tester) async {
      await tester.pumpWidget(wrapMeter(const JeebSectionLabel('Your price')));

      expect(find.text('YOUR PRICE'), findsOneWidget);
      expect(find.text('Your price'), findsNothing);
    });

    testWidgets('passes an Arabic label through unchanged', (tester) async {
      await tester.pumpWidget(
        wrapMeter(
          const JeebSectionLabel('سعرك'),
          locale: const Locale('ar'),
          direction: TextDirection.rtl,
        ),
      );

      expect(find.text('سعرك'), findsOneWidget);
    });

    testWidgets('leaves a latin label alone under ar', (tester) async {
      // The gate is the locale, not the script: an order ref inside an Arabic
      // build must not be re-cased either.
      await tester.pumpWidget(
        wrapMeter(
          const JeebSectionLabel('Ord-9c37b6'),
          locale: const Locale('ar'),
          direction: TextDirection.rtl,
        ),
      );

      expect(find.text('Ord-9c37b6'), findsOneWidget);
    });

    test('resolveCase treats an absent locale as the cased default', () {
      expect(JeebSectionLabel.resolveCase('this week', null), 'THIS WEEK');
      expect(
        JeebSectionLabel.resolveCase('this week', const Locale('en')),
        'THIS WEEK',
      );
      expect(
        JeebSectionLabel.resolveCase('this week', const Locale('ar')),
        'this week',
      );
    });
  });

  group('type', () {
    testWidgets('defaults to 12.5 / w700 / ls 1.2 / mutedText',
        (tester) async {
      await tester.pumpWidget(wrapMeter(const JeebSectionLabel('Language')));

      final TextStyle style = styleOf(tester);
      expect(style.fontSize, JeebSectionLabel.defaultFontSize);
      expect(style.fontSize, 12.5);
      expect(style.fontWeight, FontWeight.w700);
      expect(style.letterSpacing, 1.2);
      expect(style.color, midnightMuted);
      // Both factories are Midnight now, so either accessor must agree.
      expect(style.color, JeebSemanticColors.light().mutedText);
      expect(style.color, JeebSemanticColors.midnight().mutedText);
    });

    testWidgets('small selects the shipped 11px form', (tester) async {
      await tester.pumpWidget(
        wrapMeter(const JeebSectionLabel('Live transcript', small: true)),
      );

      final TextStyle style = styleOf(tester);
      expect(style.fontSize, JeebSectionLabel.smallFontSize);
      expect(style.fontSize, 11);
      // Everything else is the same token.
      expect(style.fontWeight, FontWeight.w700);
      expect(style.letterSpacing, 1.2);
      expect(style.color, midnightMuted);
    });

    testWidgets('keeps the mutedText ink on a navy card', (tester) async {
      // The Midnight board draws "Available to bid" #8A93D8 on a glow card and
      // every other label the same — deliberately not wired to JeebSurfaceTone.
      await tester.pumpWidget(
        wrapMeter(
          const ColoredBox(
            // Token sheet §1 surface.
            color: Color(0xFF0B1351),
            child: JeebSectionLabel('Available to bid'),
          ),
        ),
      );

      expect(styleOf(tester).color, midnightMuted);
    });
  });

  group('hint slot', () {
    testWidgets('renders one Text, not two', (tester) async {
      await tester.pumpWidget(
        wrapMeter(
          const JeebSectionLabel('Pickup ETA', hint: '· ≤ 60 min'),
        ),
      );

      expect(find.byType(Text), findsOneWidget);
      expect(find.text('PICKUP ETA · ≤ 60 min'), findsOneWidget);
    });

    testWidgets('the continuation is w600 with no tracking and is not cased',
        (tester) async {
      await tester.pumpWidget(
        wrapMeter(
          const JeebSectionLabel('Pickup ETA', hint: '· Flash allows ≤ 60 min'),
        ),
      );

      final RichText rich = tester.widget<RichText>(find.byType(RichText));
      // Text.rich nests the caller's span under one carrying the effective
      // style, so the label span is one level down.
      final TextSpan root = rich.text as TextSpan;
      expect(root.style!.fontSize, JeebSectionLabel.defaultFontSize);
      expect(root.style!.letterSpacing, 1.2);

      final TextSpan label = root.children!.single as TextSpan;
      expect(label.text, 'PICKUP ETA');

      final TextSpan continuation = label.children!.single as TextSpan;
      expect(continuation.text, ' · Flash allows ≤ 60 min');
      expect(continuation.style!.fontWeight, JeebSectionLabel.hintWeight);
      expect(continuation.style!.fontWeight, FontWeight.w600);
      expect(continuation.style!.letterSpacing, 0);
      // Inherits size + ink from the label span.
      expect(continuation.style!.fontSize, isNull);
      expect(continuation.style!.color, isNull);
    });
  });

  group('semantics', () {
    testWidgets('adds no node when no identifier is given', (tester) async {
      await tester.pumpWidget(wrapMeter(const JeebSectionLabel('Language')));

      expect(
        find.descendant(
          of: find.byType(JeebSectionLabel),
          matching: find.byType(Semantics),
        ),
        findsNothing,
      );
    });

    testWidgets('applies the identifier via an explicit Semantics wrapper',
        (tester) async {
      await tester.pumpWidget(
        wrapMeter(
          const JeebSectionLabel(
            'Notifications',
            identifier: 'settings_notifications_section_label',
          ),
        ),
      );

      final Semantics node = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byType(JeebSectionLabel),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(
        node.properties.identifier,
        'settings_notifications_section_label',
      );
    });
  });

  group('RTL', () {
    testWidgets('renders start-aligned and keeps hint order under rtl',
        (tester) async {
      await tester.pumpWidget(
        wrapMeter(
          const JeebSectionLabel('Pickup ETA', hint: '· ≤ 60 min'),
          direction: TextDirection.rtl,
          locale: const Locale('ar'),
        ),
      );

      expect(tester.takeException(), isNull);
      // AR does not uppercase, but the label here is latin and stays verbatim.
      expect(find.text('Pickup ETA · ≤ 60 min'), findsOneWidget);
      // The widget passes no textDirection, so it must resolve from the
      // ambient Directionality rather than defaulting to ltr.
      expect(
        tester
            .renderObject<RenderParagraph>(find.byType(RichText))
            .textDirection,
        TextDirection.rtl,
      );
    });

    testWidgets('leaves alignment to the ambient direction', (tester) async {
      // TextAlign.start (not .left) is what makes the label hug the gutter in
      // both directions; a hardcoded .left would strand it under ar.
      for (final TextDirection direction in TextDirection.values) {
        await tester.pumpWidget(
          wrapMeter(
            const JeebSectionLabel('This week'),
            direction: direction,
          ),
        );
        final RenderParagraph paragraph =
            tester.renderObject<RenderParagraph>(find.byType(RichText));
        expect(paragraph.textAlign, TextAlign.start);
        expect(paragraph.textDirection, direction);
      }
    });
  });
}
