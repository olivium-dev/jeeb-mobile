import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/jeeb_midnight_palette.dart';
import 'package:jeeb_mobile/core/theme/jeeb_radii.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_chat_bubble.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_surface_tone.dart';

import 'jeeb_chat_test_harness.dart';

/// Gates for the thread row (kit §5 #16).
///
/// FAIL-WITHOUT: without these, the 18/6 tail stops mirroring, the read state
/// silently becomes a cyan tick again (`readTick` has zero occurrences on the
/// board), the two sides drift back to the same glass — R20's whole idea is that
/// the thread reads by temperature — and the inert voice disc grows a Maestro id
/// for a permanent no-op, the exact B-04 defect.
void main() {
  final ColorScheme scheme = kChatTheme.colorScheme;
  const Key bubbleKey = Key('chat-bubble-m1');

  group('JeebChatBubble surface', () {
    testWidgets('incoming is rest glass, flat, tail at bottom-START',
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
      // Token sheet §4: rest glass = white 7% + 1px white 12%, NO blur.
      expect(decoration.color, const Color(0x12FFFFFF));
      expect(decoration.color, kChatSemantics.glassFill);
      expect(decoration.border!.top.color, const Color(0x1FFFFFFF));
      expect(decoration.border!.top.width, 1);
      expect(decoration.boxShadow, isNull);
      expect(find.byType(BackdropFilter), findsNothing);

      final BorderRadius resolved =
          (decoration.borderRadius! as BorderRadiusDirectional)
              .resolve(TextDirection.ltr);
      expect(JeebChatBubble.cornerRadius, JeebRadii.lg);
      expect(resolved.topLeft, const Radius.circular(JeebRadii.lg));
      expect(resolved.topRight, const Radius.circular(JeebRadii.lg));
      expect(resolved.bottomRight, const Radius.circular(JeebRadii.lg));
      expect(resolved.bottomLeft, const Radius.circular(6));
    });

    testWidgets('outgoing is warm orange glass, flat, mirrored tail',
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
      // R20 measured: orange 24% fill + 1px orange 45%, still no blur here —
      // the board's `blur(10)` is the screen's to spend (M2-16).
      expect(decoration.color, const Color.fromRGBO(215, 59, 0, 0.24));
      expect(decoration.color, kChatSemantics.bubbleOutFill);
      expect(decoration.color, isNot(scheme.primary));
      expect(decoration.color, isNot(JeebMidnight.orange));
      expect(decoration.border!.top.color, kChatSemantics.bubbleOutBorder);
      expect(
        decoration.border!.top.color,
        const Color.fromRGBO(215, 59, 0, 0.45),
      );
      expect(decoration.border!.top.width, 1);
      // `bubbleOut` is retired by the ratified shadow migration map.
      expect(decoration.boxShadow, isNull);
      expect(find.byType(BackdropFilter), findsNothing);

      final BorderRadius resolved =
          (decoration.borderRadius! as BorderRadiusDirectional)
              .resolve(TextDirection.ltr);
      // `18 18 6 18` — the 6 lands on the tail (bottom-END) corner.
      expect(resolved.topLeft, const Radius.circular(JeebRadii.lg));
      expect(resolved.topRight, const Radius.circular(JeebRadii.lg));
      expect(resolved.bottomRight, const Radius.circular(6));
      expect(resolved.bottomLeft, const Radius.circular(JeebRadii.lg));
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

    testWidgets('body ink is Midnight ink in, board white out', (tester) async {
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

      // Incoming is glass on navy, so it keeps `#EDEFFC`.
      expect(incoming.style.color, JeebMidnight.ink);
      expect(incoming.style.color, scheme.onSurface);
      // Ramp re-cut §6: body is 14.5/w500 on a 21px line.
      expect(incoming.style.fontSize, 14.5);
      expect(incoming.style.fontWeight, FontWeight.w500);
      expect(incoming.style.height, 21 / 14.5);
      // Outgoing sits on the tinted fill, where R20 draws the `#fff` literal.
      expect(outgoing.style.color, const Color(0xFFFFFFFF));
      expect(outgoing.style.color, scheme.onPrimary);
      expect(outgoing.style.color, isNot(JeebMidnight.ink));
      expect(outgoing.style.fontSize, 14.5);
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
      // readTick (#20F0FF) survives as a token but has zero board occurrences.
      expect(read.style!.color, isNot(JeebMidnight.readTick));
      // R20 measured: the outgoing meta line is `#FFB499` on the tinted fill,
      // which is the accent quartet's onContainer — not the cool inkSoft.
      expect(read.style!.color, JeebMidnight.orangeTint);
      expect(read.style!.color, kChatRoles.onAccentContainer);
      expect(read.style!.color, isNot(kChatSemantics.inkSoft));
      expect(
        find.bySemanticsIdentifier('chat_detail_message_read'),
        findsOneWidget,
      );
    });

    testWidgets('the incoming clock carries the board-literal mutedText',
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
      // R20 board literal; #8A93D8 passes AA on every navy (sheet §9, worst 5.17).
      expect(clock.style!.color, JeebMidnight.inkMuted);
      expect(clock.style!.color, isNot(JeebMidnight.inkSoft));
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

      final Finder discFinder = find.ancestor(
        of: find.byIcon(Icons.play_arrow_rounded),
        matching: find.byType(Container),
      ).first;
      expect(tester.getSize(discFinder), const Size(32, 32));
      expect(
        tester.widget<Icon>(find.byIcon(Icons.play_arrow_rounded)).size,
        14,
      );

      // A play control is not one of §2.2's orange moments — it is glass.
      final BoxDecoration disc =
          tester.widget<Container>(discFinder).decoration! as BoxDecoration;
      expect(disc.color, kChatSemantics.glassFillEmphasis);
      expect(disc.color, isNot(JeebMidnight.orange));
      expect(
        tester.widget<Icon>(find.byIcon(Icons.play_arrow_rounded)).color,
        JeebMidnight.ink,
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

    testWidgets('photo renders the 120×74 glass tile on the sm rung',
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
      // The board's r10 snaps to the ladder's `sm` rung (§5, ±2 tolerance).
      expect(JeebChatMedia.photoRadius, JeebRadii.sm);

      final BoxDecoration slab =
          tester.widget<Container>(tile).decoration! as BoxDecoration;
      expect(slab.color, kChatSemantics.glassFillEmphasis);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.image_outlined)).color,
        JeebMidnight.inkMuted,
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
