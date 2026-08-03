import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_shadows.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_chat_bubble.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_surface_tone.dart';

import 'jeeb_chat_test_harness.dart';

/// Gates for the thread row (kit §5 #16).
///
/// FAIL-WITHOUT: without these, the 18/6 tail stops mirroring, the read state
/// silently becomes a cyan tick again (`readTick` has zero occurrences on the
/// board), and the inert voice disc grows a Maestro id for a permanent no-op —
/// the exact B-04 defect.
void main() {
  final ColorScheme scheme = AppTheme.light().colorScheme;
  const Key bubbleKey = Key('chat-bubble-m1');

  group('JeebChatBubble surface', () {
    testWidgets('incoming is surfaceContainerHigh, flat, tail at bottom-START',
        (tester) async {
      await tester.pumpWidget(
        wrapChat(
          const JeebChatBubble(
            side: JeebChatBubbleSide.incoming,
            bubbleKey: bubbleKey,
            text: 'Hi!',
          ),
        ),
      );

      final BoxDecoration decoration =
          chatDecorationOf(tester, find.byKey(bubbleKey));
      expect(decoration.color, scheme.surfaceContainerHigh);
      expect(decoration.boxShadow, isNull);

      final BorderRadius resolved =
          (decoration.borderRadius! as BorderRadiusDirectional)
              .resolve(TextDirection.ltr);
      expect(resolved.topLeft, const Radius.circular(18));
      expect(resolved.topRight, const Radius.circular(18));
      expect(resolved.bottomRight, const Radius.circular(18));
      expect(resolved.bottomLeft, const Radius.circular(6));
    });

    testWidgets('outgoing is navy with bubbleOut and the mirrored tail',
        (tester) async {
      await tester.pumpWidget(
        wrapChat(
          const JeebChatBubble(
            side: JeebChatBubbleSide.outgoing,
            bubbleKey: bubbleKey,
            text: 'Yes perfect',
          ),
        ),
      );

      final BoxDecoration decoration =
          chatDecorationOf(tester, find.byKey(bubbleKey));
      expect(decoration.color, scheme.primary);
      expect(decoration.boxShadow, JeebShadows.bubbleOut);

      final BorderRadius resolved =
          (decoration.borderRadius! as BorderRadiusDirectional)
              .resolve(TextDirection.ltr);
      expect(resolved.bottomRight, const Radius.circular(6));
      expect(resolved.bottomLeft, const Radius.circular(18));
    });

    testWidgets('caps at 78% of the column even under tight constraints',
        (tester) async {
      // FAIL-WITHOUT: a list row hands the bubble a *tight* width, and
      // ConstrainedBox enforces its incoming constraints — a ceiling placed
      // outside the Align is clamped straight back to the full column.
      await tester.pumpWidget(
        wrapChat(
          ListView(
            children: const <Widget>[
              JeebChatBubble(
                side: JeebChatBubbleSide.incoming,
                bubbleKey: bubbleKey,
                text: 'Hi! I am at the pharmacy — they only have the 24-tablet '
                    'box, is that ok for you today?',
              ),
            ],
          ),
        ),
      );

      final double width = tester.getSize(find.byKey(bubbleKey)).width;
      expect(width, lessThanOrEqualTo(kChatFrameWidth * 0.78));
      // and it really reached the ceiling rather than shrink-wrapping short
      expect(width, greaterThan(kChatFrameWidth * 0.7));
    });

    testWidgets('body ink follows the side', (tester) async {
      await tester.pumpWidget(
        wrapChat(
          const Column(
            children: <Widget>[
              JeebChatBubble(
                side: JeebChatBubbleSide.incoming,
                text: 'in',
              ),
              JeebChatBubble(
                side: JeebChatBubbleSide.outgoing,
                text: 'out',
              ),
            ],
          ),
        ),
      );

      final DefaultTextStyle incoming = tester.widget<DefaultTextStyle>(
        find.ancestor(
          of: find.text('in'),
          matching: find.byType(DefaultTextStyle),
        ).first,
      );
      final DefaultTextStyle outgoing = tester.widget<DefaultTextStyle>(
        find.ancestor(
          of: find.text('out'),
          matching: find.byType(DefaultTextStyle),
        ).first,
      );

      expect(incoming.style.color, scheme.onSurface);
      expect(incoming.style.fontSize, 13.5);
      expect(outgoing.style.color, scheme.onPrimary);
    });
  });

  group('JeebChatBubble meta line', () {
    testWidgets('read state is TEXT and never the cyan tick', (tester) async {
      await tester.pumpWidget(
        wrapChat(
          const JeebChatBubble(
            side: JeebChatBubbleSide.outgoing,
            text: 'Yes perfect, take it!',
            time: '9:25',
            status: JeebChatStatus.text(
              'Read',
              identifier: 'chat_detail_message_read',
            ),
          ),
        ),
      );

      expect(find.text('9:25'), findsOneWidget);
      expect(find.text(JeebChatBubble.metaSeparator), findsOneWidget);
      expect(find.text('Read'), findsOneWidget);
      // No glyph at all in the read state — the board draws a word.
      expect(
        find.descendant(
          of: find.byType(JeebChatBubble),
          matching: find.byType(Icon),
        ),
        findsNothing,
      );

      final Text read = tester.widget<Text>(find.text('Read'));
      expect(read.style!.fontSize, 10);
      expect(read.style!.fontWeight, FontWeight.w600);
      // JeebSemanticColors.readTick (#20F0FF) has zero board occurrences.
      expect(read.style!.color, isNot(const Color(0xFF20F0FF)));
      expect(read.style!.color, scheme.onSecondaryContainer);
      expect(
        find.bySemanticsIdentifier('chat_detail_message_read'),
        findsOneWidget,
      );
    });

    testWidgets('the incoming clock refuses the 3.07:1 periwinkle',
        (tester) async {
      await tester.pumpWidget(
        wrapChat(
          const JeebChatBubble(
            side: JeebChatBubbleSide.incoming,
            text: 'Hi!',
            time: '9:24',
          ),
        ),
      );

      final Text clock = tester.widget<Text>(find.text('9:24'));
      expect(clock.style!.color, scheme.onSurfaceVariant);
      expect(clock.style!.color, isNot(scheme.onSecondaryContainer));
    });

    testWidgets('an icon status carries its own id and no separator',
        (tester) async {
      await tester.pumpWidget(
        wrapChat(
          const JeebChatBubble(
            side: JeebChatBubbleSide.outgoing,
            text: 'ok',
            time: '9:25',
            status: JeebChatStatus.icon(
              Icons.done_all,
              identifier: 'chat_detail_message_delivered',
              nodeKey: Key('chat-status-m1'),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.done_all), findsOneWidget);
      expect(find.text(JeebChatBubble.metaSeparator), findsNothing);
      expect(find.byKey(const Key('chat-status-m1')), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('chat_detail_message_delivered'),
        findsOneWidget,
      );
    });

    testWidgets('no meta row at all when neither time nor status is given',
        (tester) async {
      await tester.pumpWidget(
        wrapChat(
          const JeebChatBubble(
            side: JeebChatBubbleSide.incoming,
            bubbleKey: bubbleKey,
            text: 'x',
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(bubbleKey),
          matching: find.byType(Row),
        ),
        findsNothing,
      );
    });
  });

  group('JeebChatBubble media slot', () {
    testWidgets('voice renders the Ø32 disc, the waveform slot and the label',
        (tester) async {
      await tester.pumpWidget(
        wrapChat(
          const JeebChatBubble(
            side: JeebChatBubbleSide.incoming,
            media: JeebChatMedia.voice(
              waveform: SizedBox(key: Key('waveform'), width: 24, height: 16),
              label: '0:06 · photo of the box',
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('waveform')), findsOneWidget);
      expect(find.text('0:06 · photo of the box'), findsOneWidget);

      final Size disc = tester.getSize(
        find.ancestor(
          of: find.byIcon(Icons.play_arrow_rounded),
          matching: find.byType(Container),
        ).first,
      );
      expect(disc, const Size(32, 32));
      expect(
        tester.widget<Icon>(find.byIcon(Icons.play_arrow_rounded)).size,
        14,
      );
    });

    testWidgets('the inert play disc gets no id and no tap affordance (B-04)',
        (tester) async {
      await tester.pumpWidget(
        wrapChat(
          const JeebChatBubble(
            side: JeebChatBubbleSide.incoming,
            media: JeebChatMedia.voice(
              waveform: SizedBox.shrink(),
              label: '0:06',
              // onPlay deliberately omitted — there is no audio player.
            ),
          ),
        ),
      );

      expect(find.bySemanticsIdentifier('chat_detail_voice_button'),
          findsNothing);
      expect(
        find.descendant(
          of: find.byType(JeebChatBubble),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
    });

    testWidgets('publishes the surface tone so the waveform re-inks itself',
        (tester) async {
      // The seam with kit #14: `JeebWaveform.inBubble()` resolves its ink from
      // `JeebSurfaceTone.of(context).onNavy`, so the bubble must publish a tone
      // or every outgoing voice note draws a navy mark on a navy bubble.
      // Probed rather than imported, so this gate does not couple to the
      // waveform lane's API.
      late bool incomingOnNavy;
      late bool outgoingOnNavy;
      await tester.pumpWidget(
        wrapChat(
          Column(
            children: <Widget>[
              JeebChatBubble(
                side: JeebChatBubbleSide.incoming,
                media: JeebChatMedia.voice(
                  waveform: _ToneProbe(
                    onTone: (bool value) => incomingOnNavy = value,
                  ),
                  label: '0:06',
                ),
              ),
              JeebChatBubble(
                side: JeebChatBubbleSide.outgoing,
                media: JeebChatMedia.voice(
                  waveform: _ToneProbe(
                    onTone: (bool value) => outgoingOnNavy = value,
                  ),
                  label: '0:06',
                ),
              ),
            ],
          ),
        ),
      );

      expect(incomingOnNavy, isFalse);
      expect(outgoingOnNavy, isTrue);
    });

    testWidgets('photo renders the 120×74 r10 tile with the 20px glyph',
        (tester) async {
      await tester.pumpWidget(
        wrapChat(
          const JeebChatBubble(
            side: JeebChatBubbleSide.incoming,
            media: JeebChatMedia.photo(),
          ),
        ),
      );

      final Finder tile = find.ancestor(
        of: find.byIcon(Icons.image_outlined),
        matching: find.byType(Container),
      ).first;
      expect(tester.getSize(tile), const Size(120, 74));
      expect(tester.widget<Icon>(find.byIcon(Icons.image_outlined)).size, 20);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.image_outlined)).color,
        scheme.onSecondaryContainer,
      );
    });
  });

  group('JeebChatBubble semantics', () {
    testWidgets('emits the message id without swallowing the status id',
        (tester) async {
      await tester.pumpWidget(
        wrapChat(
          const JeebChatBubble(
            side: JeebChatBubbleSide.outgoing,
            identifier: 'chat_detail_message_m1',
            text: 'ok',
            time: '9:25',
            status: JeebChatStatus.icon(
              Icons.done,
              identifier: 'chat_detail_message_sent',
            ),
          ),
        ),
      );

      expect(
        find.bySemanticsIdentifier('chat_detail_message_m1'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('chat_detail_message_sent'),
        findsOneWidget,
      );

      final Semantics node = tester.widget<Semantics>(
        find.descendant(
          of: find.byType(JeebChatBubble),
          matching: find.byType(Semantics),
        ).first,
      );
      expect(node.container, isTrue);
      expect(node.explicitChildNodes, isTrue);
    });

    testWidgets('adds no Semantics node when nothing needs one',
        (tester) async {
      await tester.pumpWidget(
        wrapChat(
          const JeebChatBubble(
            side: JeebChatBubbleSide.incoming,
            text: 'x',
          ),
        ),
      );

      // 21 forbids a bare Semantics between a consumer's container node and
      // its children.
      expect(
        find.descendant(
          of: find.byType(JeebChatBubble),
          matching: find.byType(Semantics),
        ),
        findsNothing,
      );
    });
  });

  group('JeebChatBubble RTL', () {
    testWidgets('incoming hugs the leading edge in both directions',
        (tester) async {
      await tester.pumpWidget(
        wrapChat(
          const JeebChatBubble(
            side: JeebChatBubbleSide.incoming,
            bubbleKey: bubbleKey,
            text: 'مرحبا',
          ),
        ),
      );
      expect(tester.getRect(find.byKey(bubbleKey)).left, 0);

      await tester.pumpWidget(
        wrapChat(
          const JeebChatBubble(
            side: JeebChatBubbleSide.incoming,
            bubbleKey: bubbleKey,
            text: 'مرحبا',
          ),
          direction: TextDirection.rtl,
        ),
      );
      expect(tester.getRect(find.byKey(bubbleKey)).right, kChatFrameWidth);
    });

    testWidgets('outgoing hugs the trailing edge in both directions',
        (tester) async {
      await tester.pumpWidget(
        wrapChat(
          const JeebChatBubble(
            side: JeebChatBubbleSide.outgoing,
            bubbleKey: bubbleKey,
            text: 'ok',
          ),
        ),
      );
      expect(tester.getRect(find.byKey(bubbleKey)).right, kChatFrameWidth);

      await tester.pumpWidget(
        wrapChat(
          const JeebChatBubble(
            side: JeebChatBubbleSide.outgoing,
            bubbleKey: bubbleKey,
            text: 'ok',
          ),
          direction: TextDirection.rtl,
        ),
      );
      expect(tester.getRect(find.byKey(bubbleKey)).left, 0);
    });

    testWidgets('the tail mirrors under RTL', (tester) async {
      await tester.pumpWidget(
        wrapChat(
          const JeebChatBubble(
            side: JeebChatBubbleSide.incoming,
            bubbleKey: bubbleKey,
            text: 'x',
          ),
          direction: TextDirection.rtl,
        ),
      );

      final BoxDecoration decoration =
          chatDecorationOf(tester, find.byKey(bubbleKey));
      final BorderRadius resolved =
          (decoration.borderRadius! as BorderRadiusDirectional)
              .resolve(TextDirection.rtl);
      // start == right under RTL, so the tail flips sides.
      expect(resolved.bottomRight, const Radius.circular(6));
      expect(resolved.bottomLeft, const Radius.circular(18));
    });

    testWidgets('the clock stays in an LTR isolate under RTL', (tester) async {
      await tester.pumpWidget(
        wrapChat(
          const JeebChatBubble(
            side: JeebChatBubbleSide.outgoing,
            text: 'حسناً',
            time: '9:25',
            status: JeebChatStatus.text('تمت القراءة'),
          ),
          direction: TextDirection.rtl,
        ),
      );

      final Directionality isolate = tester.widget<Directionality>(
        find.ancestor(
          of: find.text('9:25'),
          matching: find.byType(Directionality),
        ).first,
      );
      expect(isolate.textDirection, TextDirection.ltr);

      // ...but the localized read word must NOT be dragged into it, or the
      // Arabic renders LTR.
      final Directionality wordScope = tester.widget<Directionality>(
        find.ancestor(
          of: find.text('تمت القراءة'),
          matching: find.byType(Directionality),
        ).first,
      );
      expect(wordScope.textDirection, TextDirection.rtl);
    });
  });
}

/// Reports the [JeebSurfaceTone] visible at the waveform slot, so the seam with
/// kit #14 is proved without importing it.
class _ToneProbe extends StatelessWidget {
  const _ToneProbe({required this.onTone});

  final ValueChanged<bool> onTone;

  @override
  Widget build(BuildContext context) {
    onTone(JeebSurfaceTone.of(context).onNavy);
    return const SizedBox(width: 24, height: 16);
  }
}
