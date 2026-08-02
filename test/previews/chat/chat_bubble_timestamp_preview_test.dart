// Render tests for the ChatBubbleTimestamp previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// One state deviates from that template on purpose. 'Ordering anchor · no
// clock' renders `SizedBox.shrink()` — the ABSENCE is the state — so there is
// no text of the widget's own for `expectedText` to bind to. It binds to the
// preview's caption instead, and the contract that actually matters (no Text
// anywhere under the widget) is asserted in the specifics group against a
// dated sibling, so the assertion cannot pass vacuously.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
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
      // send time. The widget must be present and empty — not "00:00", not a
      // dimmed placeholder.
      expect(find.byType(ChatBubbleTimestamp), findsOneWidget);
      expect(_clock(), findsNothing);

      // The SAME epoch instant with the flag left true proves the assertion
      // above is not vacuous: the suppression is the flag, not the value.
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
      // widget's own callers are all local-time. The two sibling call sites on
      // the same `Hm` skeleton call `.toLocal()` first; this one cannot.
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
      // A stray `Alignment.centerRight` would pin the clock to the physical
      // right in both locales, and only this assertion would see it.
      expect(await offsetFromBubbleCentre(const Locale('en')), greaterThan(0));
      expect(await offsetFromBubbleCentre(const Locale('ar')), lessThan(0));
    });

    testWidgets('the Arabic clock is byte-identical to the English one', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatBubbleTimestampOfferFooter,
          locale: const Locale('ar'));

      // Measured, not assumed. intl 0.20.2 ships no `ZERODIGIT` in the generic
      // `ar` date symbols — only `ar_EG` has one — so `DateFormat.Hm('ar')`
      // formats with ASCII digits and the Arabic clock renders "12:34", not
      // "١٢:٣٤". Worth pinning for two reasons: the neighbouring
      // `chat_date_separator_preview.dart` documents the opposite ("must show
      // ... Arabic-Indic digits"), and the day the app adds an `ar_EG` locale
      // this widget silently switches digit system with no code change.
      expect(find.text('12:34'), findsOneWidget);
      expect(find.text('١٢:٣٤'), findsNothing);
    });

    test('the default ink is unreadable on the sender bubble, both themes', () {
      for (final ThemeData theme in <ThemeData>[
        AppTheme.light(),
        AppTheme.dark(),
      ]) {
        final ColorScheme scheme = theme.colorScheme;
        final Color defaultInk = Color.alphaBlend(
          scheme.onSurfaceVariant.withValues(alpha: UIConstants.opacityHigh),
          scheme.primary,
        );
        final Color callerInk = Color.alphaBlend(
          scheme.onPrimary.withValues(alpha: UIConstants.opacityHigh),
          scheme.primary,
        );

        // What `chatBubbleTimestampDefaultInkOnBubble` shows: a surface role
        // asked to read on a filled brand bubble. 1.65:1 in light.
        expect(
          _contrast(defaultInk, scheme.primary),
          lessThan(3.0),
          reason: 'If this now passes 3:1 the widget default has become safe '
              'on a filled bubble and the "default colour" preview + this '
              'guard can go.',
        );
        // What `chat_message_bubble.dart:574` passes instead, and why the app
        // does not ship the number above.
        expect(
          _contrast(callerInk, scheme.primary),
          greaterThan(4.5),
          reason: 'The caller-supplied ink must clear AA for 11pt text.',
        );
      }
    });
  });
}
