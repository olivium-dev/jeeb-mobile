// Render tests for the ChatMessageBubble previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`; the `expectedText` map is the
// part that matters — it pins each preview to ITS OWN content, so a refactor
// that made every card render the same bubble would fail here instead of
// looking fine in the canvas.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/previews/chat/chat_message_bubble_preview.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'ChatMessageBubble',
    const <String, Widget Function()>{
      'Incoming + reply': chatMessageBubblePair,
      'Status ladder': chatMessageBubbleStatusLadder,
      'Longest plausible message': chatMessageBubbleLongText,
      'Arabic message in an EN thread': chatMessageBubbleMixedScript,
      'Image with no local bytes': chatMessageBubbleImageNoBytes,
      'Undated history row': chatMessageBubbleUndated,
    },
    expectedText: const <String, String>{
      'Incoming + reply': 'The blue box, please',
      'Status ladder': 'failed — this one never left',
      'Longest plausible message':
          'Hi! Please pick up the two large bags of ice, a pack of paper cups, '
              'and the birthday cake reserved under the name Fawaz — the '
              'counter staff already have it boxed and paid for, so you only '
              'need to show them this message.',
      'Arabic message in an EN thread': 'وصلت للبناية، أنا عند المصعد',
      'Image with no local bytes': 'Left it with the concierge',
      'Undated history row': 'No created_at came back for this row',
    },
  );

  group('ChatMessageBubble preview specifics', () {
    testWidgets('only the sender bubble carries a clock (D3)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatMessageBubblePair);

      // Two bubbles, one clock: the incoming timestamp slot stays empty.
      expect(find.text('09:41'), findsOneWidget);
    });

    testWidgets('an undated row renders its ticks but no fabricated clock', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatMessageBubbleUndated);

      // The dated sibling supplies the only clock in this preview; the undated
      // row must not add a second one, and must never show a 1970-era time.
      expect(find.text('09:41'), findsOneWidget);
      expect(find.text('00:00'), findsNothing);
      expect(
        find.byKey(const Key('chat-status-undated-1')),
        findsOneWidget,
        reason: 'the undated row is still a real message and keeps its ticks',
      );
    });

    testWidgets('a bare CDN object_ref degrades to the placeholder (P4/P5)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatMessageBubbleImageNoBytes);

      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);
    });

    testWidgets('every send status draws a distinct glyph', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, chatMessageBubbleStatusLadder);

      expect(find.byIcon(Icons.access_time), findsOneWidget); // sending
      expect(find.byIcon(Icons.done), findsOneWidget); // sent
      expect(find.byIcon(Icons.done_all), findsNWidgets(2)); // delivered + read
      expect(find.byIcon(Icons.error_outline), findsOneWidget); // failed
    });
  });
}
