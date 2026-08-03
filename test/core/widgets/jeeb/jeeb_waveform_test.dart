import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_navy_surface_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_waveform.dart';

Widget _wrap(Widget child, {TextDirection direction = TextDirection.ltr}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Directionality(
      textDirection: direction,
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

/// Every bar the mark rendered, in child order.
List<SizedBox> _bars(WidgetTester tester) {
  return tester
      .widgetList<SizedBox>(
        find.descendant(
          of: find.byType(JeebWaveform),
          matching: find.byType(SizedBox),
        ),
      )
      // The gap spacers have no height; the container has no width.
      .where((SizedBox box) => box.width != null && box.height != null)
      .toList();
}

BoxDecoration _decorationAt(WidgetTester tester, int index) {
  final DecoratedBox box = tester
      .widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(JeebWaveform),
          matching: find.byType(DecoratedBox),
        ),
      )
      .elementAt(index);
  return box.decoration as BoxDecoration;
}

void main() {
  group('JeebWaveform geometry', () {
    testWidgets('cardMark is 4 bars w3 h 8/14/10/15 in a h16 container',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const JeebWaveform.cardMark()));

      final List<SizedBox> bars = _bars(tester);
      expect(bars.length, 4);
      expect(bars.map((SizedBox b) => b.height).toList(),
          <double>[8, 14, 10, 15]);
      expect(bars.every((SizedBox b) => b.width == 3), isTrue);
      expect(
        tester.getSize(find.byType(JeebWaveform)).height,
        JeebWaveform.cardMarkHeight,
      );
      // 4 bars w3 + 3 gaps of 2.
      expect(tester.getSize(find.byType(JeebWaveform)).width, 18);
    });

    testWidgets('onNavy is 5 bars w3 h 9/17/11/20/10 in a h24 container',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const JeebWaveform.onNavy()));

      final List<SizedBox> bars = _bars(tester);
      expect(bars.length, 5);
      expect(bars.map((SizedBox b) => b.height).toList(),
          <double>[9, 17, 11, 20, 10]);
      expect(
        tester.getSize(find.byType(JeebWaveform)).height,
        JeebWaveform.onNavyHeight,
      );
      // 5 bars w3 + 4 gaps of 3.
      expect(tester.getSize(find.byType(JeebWaveform)).width, 27);
    });

    testWidgets('inBubble is 5 bars w2.5 h 8/14/10/15/9 in a h16 container',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const JeebWaveform.inBubble()));

      final List<SizedBox> bars = _bars(tester);
      expect(bars.length, 5);
      expect(bars.map((SizedBox b) => b.height).toList(),
          <double>[8, 14, 10, 15, 9]);
      expect(bars.every((SizedBox b) => b.width == 2.5), isTrue);
      expect(
        tester.getSize(find.byType(JeebWaveform)).height,
        JeebWaveform.inBubbleHeight,
      );
    });

    testWidgets('live is 10 bars w4 in a h40 container, bottom-aligned',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const JeebWaveform.live()));

      final List<SizedBox> bars = _bars(tester);
      expect(bars.length, 10, reason: 'measured 05 tpl 258-267, not the plan\'s ~11');
      expect(
        bars.map((SizedBox b) => b.height).toList(),
        <double>[12, 22, 32, 18, 38, 26, 36, 16, 28, 12],
      );
      expect(bars.every((SizedBox b) => b.width == 4), isTrue);

      final Rect container = tester.getRect(find.byType(JeebWaveform));
      expect(container.height, JeebWaveform.liveHeight);
      // flex-end: every bar's bottom edge sits on the container's baseline.
      final Iterable<Rect> barRects = find
          .descendant(
            of: find.byType(JeebWaveform),
            matching: find.byType(DecoratedBox),
          )
          .evaluate()
          .map((Element e) => tester.getRect(find.byWidget(e.widget)));
      for (final Rect rect in barRects) {
        expect(rect.bottom, moreOrLessEquals(container.bottom));
      }
    });

    testWidgets('the unnamed constructor renders the same mark as the named one',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const JeebWaveform(mode: JeebWaveformMode.live)),
      );
      expect(_bars(tester).length, 10);
      expect(JeebWaveform.heightOf(JeebWaveformMode.live),
          JeebWaveform.liveHeight);
    });

    testWidgets('every bar is a full stadium (r9)', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const JeebWaveform.cardMark()));
      expect(
        _decorationAt(tester, 0).borderRadius,
        const BorderRadius.all(Radius.circular(JeebWaveform.barRadius)),
      );
    });
  });

  group('JeebWaveform ink', () {
    testWidgets('cardMark is accent with the last bar at .4',
        (WidgetTester tester) async {
      late Color accent;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (BuildContext context) {
              accent = context.jeebRoles.accent;
              return const JeebWaveform.cardMark();
            },
          ),
        ),
      );

      for (int i = 0; i < 3; i++) {
        expect(_decorationAt(tester, i).color, accent);
      }
      expect(
        _decorationAt(tester, 3).color,
        accent.withValues(alpha: 0.4),
      );
    });

    testWidgets('onNavy is white .4/.55 with the two middle bars in accent',
        (WidgetTester tester) async {
      late Color accent;
      late Color onPrimary;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (BuildContext context) {
              accent = context.jeebRoles.accent;
              onPrimary = Theme.of(context).colorScheme.onPrimary;
              return const JeebWaveform.onNavy();
            },
          ),
        ),
      );

      expect(_decorationAt(tester, 0).color,
          onPrimary.withValues(alpha: 0.4));
      expect(_decorationAt(tester, 1).color,
          onPrimary.withValues(alpha: 0.55));
      expect(_decorationAt(tester, 2).color, accent);
      expect(_decorationAt(tester, 3).color, accent);
      expect(_decorationAt(tester, 4).color,
          onPrimary.withValues(alpha: 0.55));
    });

    testWidgets('inBubble inks navy on a light surface',
        (WidgetTester tester) async {
      late Color navy;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (BuildContext context) {
              navy = Theme.of(context).colorScheme.primary;
              return const JeebWaveform.inBubble();
            },
          ),
        ),
      );
      expect(_decorationAt(tester, 0).color, navy.withValues(alpha: 0.5));
      expect(_decorationAt(tester, 4).color, navy.withValues(alpha: 0.4));
    });

    testWidgets('inBubble inherits white ink from the navy surface tone',
        (WidgetTester tester) async {
      late Color onPrimary;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (BuildContext context) {
              onPrimary = Theme.of(context).colorScheme.onPrimary;
              return const JeebNavySurfaceCard(
                child: JeebWaveform.inBubble(),
              );
            },
          ),
        ),
      );
      expect(
        _decorationAt(tester, 0).color,
        onPrimary.withValues(alpha: 0.5),
        reason: 'the bubble tone re-inks the mark; no onNavy parameter needed',
      );
    });

    testWidgets('an explicit outgoing flag beats the inherited tone',
        (WidgetTester tester) async {
      late Color navy;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (BuildContext context) {
              navy = Theme.of(context).colorScheme.primary;
              return const JeebNavySurfaceCard(
                child: JeebWaveform.inBubble(outgoing: false),
              );
            },
          ),
        ),
      );
      expect(_decorationAt(tester, 0).color, navy.withValues(alpha: 0.5));
    });
  });

  group('JeebWaveform semantics', () {
    testWidgets('adds no node by default', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const JeebWaveform.cardMark()));
      expect(
        find.descendant(
          of: find.byType(JeebWaveform),
          matching: find.byType(Semantics),
        ),
        findsNothing,
      );
    });

    testWidgets('applies an explicit identifier when asked',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const JeebWaveform.live(
            identifier: 'voice_request_recording_waveform',
            semanticLabel: 'Recording',
          ),
        ),
      );
      expect(
        find.bySemanticsIdentifier('voice_request_recording_waveform'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Recording'), findsOneWidget);
    });
  });

  group('JeebWaveform RTL', () {
    testWidgets('mirrors the bar run so the faded tail stays at the read-end',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const JeebWaveform.cardMark(), direction: TextDirection.ltr),
      );
      final List<Rect> ltr = find
          .descendant(
            of: find.byType(JeebWaveform),
            matching: find.byType(DecoratedBox),
          )
          .evaluate()
          .map((Element e) => tester.getRect(find.byWidget(e.widget)))
          .toList();
      expect(ltr.first.left, lessThan(ltr.last.left));

      await tester.pumpWidget(
        _wrap(const JeebWaveform.cardMark(), direction: TextDirection.rtl),
      );
      final List<Rect> rtl = find
          .descendant(
            of: find.byType(JeebWaveform),
            matching: find.byType(DecoratedBox),
          )
          .evaluate()
          .map((Element e) => tester.getRect(find.byWidget(e.widget)))
          .toList();
      expect(rtl.first.left, greaterThan(rtl.last.left));
    });

    testWidgets('every mode lays out under RTL without overflow',
        (WidgetTester tester) async {
      for (final JeebWaveformMode mode in JeebWaveformMode.values) {
        await tester.pumpWidget(
          _wrap(
            JeebWaveform(mode: mode),
            direction: TextDirection.rtl,
          ),
        );
        expect(tester.takeException(), isNull, reason: '$mode overflowed');
      }
    });

    testWidgets('bar heights ignore the text scaler',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(body: Center(child: JeebWaveform.live())),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(JeebWaveform)).height,
        JeebWaveform.liveHeight,
      );
    });
  });
}
