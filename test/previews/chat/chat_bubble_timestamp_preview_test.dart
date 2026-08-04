// Render tests for the ChatBubbleTimestamp previews.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_bubble_timestamp.dart';

import '../preview_test_harness.dart';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Offer card footer · 12:34': chatBubbleTimestampOfferFooter,
  'Sender bubble · caller colour': chatBubbleTimestampSenderBubble,
  'Sender bubble · default colour': chatBubbleTimestampDefaultInkOnBubble,
  'Ordering anchor · no clock': chatBubbleTimestampOrderingAnchor,
  'Epoch anchor drawn as 00:00': chatBubbleTimestampEpochDrawn,
  'UTC instant, not localized': chatBubbleTimestampUtcInstant,
};

/// The widget's entire output: the one [Text] it draws, when it draws one.
Finder _clock() => find.descendant(
      of: find.byType(ChatBubbleTimestamp),
      matching: find.byType(Text),
    );

/// WCAG relative-contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final double lumA = a.computeLuminance();
  final double lumB = b.computeLuminance();
  final double hi = math.max(lumA, lumB);
  final double lo = math.min(lumA, lumB);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'ChatBubbleTimestamp',
    _previews,
    expectedText: const <String, String>{
      'Offer card footer · 12:34': '12:34',
      'Sender bubble · caller colour': '09:41',
      'Sender bubble · default colour': '23:58',
      'Ordering anchor · no clock': 'anchor only — no clock is drawn',
      'Epoch anchor drawn as 00:00': '00:00',
      'UTC instant, not localized': '21:05',
    },
  );

  group('ChatBubbleTimestamp preview specifics', () {
    testWidgets('an ordering anchor draws no clock at all', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatBubbleTimestampOrderingAnchor);

      // `hasServerTimestamp: false` means sentAt is an ordering anchor, not a
      expect(find.byType(ChatBubbleTimestamp), findsOneWidget);
      expect(_clock(), findsNothing);

      // The SAME epoch instant with the flag left true proves the assertion
      await pumpPreview(tester, chatBubbleTimestampEpochDrawn);
      expect(_clock(), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
    });

    testWidgets('midnight is a zero-padded 24-hour clock, never 12:00 AM', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatBubbleTimestampEpochDrawn);

      expect(find.textContaining('AM'), findsNothing);
      expect(find.textContaining('PM'), findsNothing);
    });

    testWidgets('a UTC instant prints the UTC hour, not the local one', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatBubbleTimestampUtcInstant);

      // DateFormat converts no zones: 21:05 UTC stays 21:05 even though the
      expect(find.text('21:05'), findsOneWidget);
      expect(find.text('00:05'), findsNothing);
    });

    testWidgets('the clock mirrors to the physical left in Arabic', (
      WidgetTester tester,
    ) async {
      Future<double> offsetFromBubbleCentre(Locale locale) async {
        await pumpPreview(tester, chatBubbleTimestampOfferFooter,
            locale: locale);
        return tester.getCenter(_clock()).dx -
            tester.getCenter(find.byType(ChatBubbleTimestamp)).dx;
      }

      // The widget's only layout opinion is `AlignmentDirectional.centerEnd`.
      expect(await offsetFromBubbleCentre(const Locale('en')), greaterThan(0));
      expect(await offsetFromBubbleCentre(const Locale('ar')), lessThan(0));
    });

    testWidgets('the Arabic clock is byte-identical to the English one', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatBubbleTimestampOfferFooter,
          locale: const Locale('ar'));

      // Measured, not assumed. intl 0.20.2 ships no `ZERODIGIT` in the generic
      expect(find.text('12:34'), findsOneWidget);
      expect(find.text('١٢:٣٤'), findsNothing);
    });

    testWidgets(
        'the sender stand-in paints the SHIPPED outgoing bubble, not a '
        'solid accent slab', (WidgetTester tester) async {
      await pumpPreview(tester, chatBubbleTimestampSenderBubble);

      final BoxDecoration decoration = tester
          .widget<Container>(
            find
                .ancestor(
                  of: find.byType(ChatBubbleTimestamp),
                  matching: find.byType(Container),
                )
                .last,
          )
          .decoration! as BoxDecoration;
      final JeebSemanticColors tokens = JeebSemanticColors.midnight();

      // The preview used to draw `colorScheme.primary` — a solid #D73B00 slab
      // the shipped bubble has never been. Reverting to it fails both rows.
      expect(decoration.color, tokens.bubbleOutFill);
      expect(decoration.color, isNot(AppTheme.midnightScheme.primary));
      expect(
        (decoration.border! as Border).top.color,
        tokens.bubbleOutBorder,
      );
    });

    test('the caller ink out-reads the widget default on that bubble', () {
      // Both inks are measured on the bubble as it actually composites over the
      // thread surface, not on a slab of `primary` that is never drawn.
      const ColorScheme scheme = AppTheme.midnightScheme;
      final Color bubble = Color.alphaBlend(
        JeebSemanticColors.midnight().bubbleOutFill,
        scheme.surface,
      );
      final Color defaultInk = Color.alphaBlend(
        scheme.onSurfaceVariant.withValues(alpha: UIConstants.opacityHigh),
        bubble,
      );
      final Color callerInk = Color.alphaBlend(
        scheme.onPrimary.withValues(alpha: UIConstants.opacityHigh),
        bubble,
      );

      expect(
        _contrast(callerInk, bubble),
        greaterThan(_contrast(defaultInk, bubble)),
        reason: 'the "default colour" preview exists to show the weaker ink; '
            'if these ever tie, that preview no longer demonstrates anything.',
      );
      expect(
        _contrast(callerInk, bubble),
        greaterThan(4.5),
        reason: 'The caller-supplied ink must clear AA for 11pt text.',
      );
    });
  });
}
