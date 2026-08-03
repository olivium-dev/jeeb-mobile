import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_mic_hero.dart';

Widget _wrap(Widget child, {TextDirection direction = TextDirection.ltr}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Directionality(
      textDirection: direction,
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

/// The disc's own decoration — the only circular [DecoratedBox] with a solid
/// fill in the subtree (the halo is a gradient).
BoxDecoration _discDecoration(WidgetTester tester) {
  return tester
      .widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(JeebMicHero),
          matching: find.byType(DecoratedBox),
        ),
      )
      .map((DecoratedBox box) => box.decoration as BoxDecoration)
      .firstWhere((BoxDecoration d) => d.color != null);
}

Finder _buttonSemantics() {
  return find.descendant(
    of: find.byType(JeebMicHero),
    matching: find.byWidgetPredicate(
      (Widget w) => w is Semantics && w.properties.button == true,
    ),
  );
}

void main() {
  group('JeebMicHero disc', () {
    testWidgets('Ø56 paints the accent fill and the measured compact glow',
        (WidgetTester tester) async {
      late Color accent;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (BuildContext context) {
              accent = context.jeebRoles.accent;
              return const JeebMicHero(size: JeebMicHero.sizeCompact);
            },
          ),
        ),
      );

      final BoxDecoration disc = _discDecoration(tester);
      expect(disc.color, accent);
      expect(disc.shape, BoxShape.circle);

      // 0 0 0 6 rgba(215,59,0,.22) + 0 10 22 rgba(215,59,0,.45) — 04 tpl 169.
      final List<BoxShadow> glow = disc.boxShadow!;
      expect(glow.length, 2);
      expect(glow[0].spreadRadius, 6);
      expect(glow[0].blurRadius, 0);
      expect(glow[0].color, accent.withValues(alpha: 0.22));
      expect(glow[1].offset, const Offset(0, 10));
      expect(glow[1].blurRadius, 22);
      expect(glow[1].color, accent.withValues(alpha: 0.45));

      expect(tester.getSize(find.byType(JeebMicHero)),
          const Size(JeebMicHero.sizeCompact, JeebMicHero.sizeCompact));
    });

    testWidgets('Ø118 takes the large glow and the Ø128 hero takes its own',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const JeebMicHero.decorative(size: JeebMicHero.sizeLarge)),
      );
      List<BoxShadow> glow = _discDecoration(tester).boxShadow!;
      expect(glow[0].spreadRadius, 10);
      expect(glow[1].offset, const Offset(0, 18));
      expect(glow[1].blurRadius, 40);

      await tester.pumpWidget(_wrap(const JeebMicHero()));
      glow = _discDecoration(tester).boxShadow!;
      expect(glow[0].spreadRadius, 9);
      expect(glow[1].offset, const Offset(0, 16));
      expect(glow[1].blurRadius, 34);
    });

    testWidgets('an explicit glow beats the size-matched one',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const JeebMicHero(
            size: JeebMicHero.sizeHero,
            glow: JeebMicGlow.compact,
          ),
        ),
      );
      expect(_discDecoration(tester).boxShadow![0].spreadRadius, 6);
    });

    testWidgets('the glyph uses the measured pairing for each diameter',
        (WidgetTester tester) async {
      await tester
          .pumpWidget(_wrap(const JeebMicHero(size: JeebMicHero.sizeCompact)));
      expect(tester.widget<Icon>(find.byIcon(Icons.mic)).size, 28);

      await tester.pumpWidget(_wrap(const JeebMicHero()));
      expect(tester.widget<Icon>(find.byIcon(Icons.mic)).size, 56);

      await tester
          .pumpWidget(_wrap(const JeebMicHero(size: 90, glyphSize: 11)));
      expect(tester.widget<Icon>(find.byIcon(Icons.mic)).size, 11);
    });
  });

  group('JeebMicHero halo and arc', () {
    testWidgets('extentFor matches the laid-out square',
        (WidgetTester tester) async {
      expect(
        JeebMicHero.extentFor(size: JeebMicHero.sizeCompact),
        JeebMicHero.sizeCompact,
      );
      // r64 disc + 10 gap + half of a 5 stroke = 76.5 → Ø153 (05 tpl 274).
      expect(
        JeebMicHero.extentFor(size: JeebMicHero.sizeHero, arc: true),
        153,
      );
      // Ø184 halo (05 tpl 273) always wins over the arc.
      expect(
        JeebMicHero.extentFor(
            size: JeebMicHero.sizeHero, halo: true, arc: true),
        184,
      );

      await tester.pumpWidget(
        _wrap(const JeebMicHero(progress: 0.5, isRecording: true)),
      );
      expect(tester.getSize(find.byType(JeebMicHero)), const Size(184, 184));
    });

    testWidgets('the halo follows isRecording and can be forced',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const JeebMicHero()));
      expect(tester.getSize(find.byType(JeebMicHero)).width,
          JeebMicHero.sizeHero);

      await tester.pumpWidget(_wrap(const JeebMicHero(isRecording: true)));
      expect(tester.getSize(find.byType(JeebMicHero)).width, 184);

      await tester.pumpWidget(
        _wrap(const JeebMicHero(isRecording: true, halo: false)),
      );
      expect(tester.getSize(find.byType(JeebMicHero)).width,
          JeebMicHero.sizeHero);
    });

    testWidgets('no progress means no arc at all', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const JeebMicHero()));
      expect(
        find.descendant(
          of: find.byType(JeebMicHero),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
    });

    testWidgets('progress draws the arc and clamps out of range',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const JeebMicHero(progress: 7 / 60)));
      final Finder arc = find.descendant(
        of: find.byType(JeebMicHero),
        matching: find.byType(CustomPaint),
      );
      expect(arc, findsOneWidget);
      expect(tester.widget<CustomPaint>(arc).size, const Size(153, 153));

      await tester.pumpWidget(_wrap(const JeebMicHero(progress: 4)));
      expect(tester.takeException(), isNull);
      expect(arc, findsOneWidget);
    });
  });

  group('JeebMicHero hold-to-talk', () {
    testWidgets('press start fires on touch-down, not after a long-press delay',
        (WidgetTester tester) async {
      final List<String> log = <String>[];
      await tester.pumpWidget(
        _wrap(
          JeebMicHero(
            onPressStart: () => log.add('start'),
            onPressEnd: () => log.add('end'),
          ),
        ),
      );

      final TestGesture gesture =
          await tester.startGesture(tester.getCenter(find.byIcon(Icons.mic)));
      await tester.pump();
      expect(log, <String>['start']);

      await gesture.up();
      await tester.pump();
      expect(log, <String>['start', 'end']);
    });

    testWidgets('a slide toward the start edge cancels instead of ending (LTR)',
        (WidgetTester tester) async {
      final List<String> log = <String>[];
      await tester.pumpWidget(
        _wrap(
          JeebMicHero(
            onPressStart: () => log.add('start'),
            onPressEnd: () => log.add('end'),
            onSlideCancel: () => log.add('cancel'),
          ),
        ),
      );

      final TestGesture gesture =
          await tester.startGesture(tester.getCenter(find.byIcon(Icons.mic)));
      await gesture.moveBy(const Offset(-80, 0));
      await gesture.up();
      await tester.pump();
      expect(log, <String>['start', 'cancel']);
    });

    testWidgets('the cancel direction flips under RTL',
        (WidgetTester tester) async {
      final List<String> log = <String>[];
      Widget hero() => JeebMicHero(
            onPressStart: () => log.add('start'),
            onPressEnd: () => log.add('end'),
            onSlideCancel: () => log.add('cancel'),
          );

      await tester.pumpWidget(_wrap(hero(), direction: TextDirection.rtl));
      TestGesture gesture =
          await tester.startGesture(tester.getCenter(find.byIcon(Icons.mic)));
      await gesture.moveBy(const Offset(80, 0));
      await gesture.up();
      await tester.pump();
      expect(log, <String>['start', 'cancel'],
          reason: 'in RTL the cluster start is the right edge');

      log.clear();
      gesture =
          await tester.startGesture(tester.getCenter(find.byIcon(Icons.mic)));
      await gesture.moveBy(const Offset(-80, 0));
      await gesture.up();
      await tester.pump();
      expect(log, <String>['start', 'end'],
          reason: 'dragging away from the start edge must still send');
    });

    testWidgets('travel under the threshold still sends',
        (WidgetTester tester) async {
      final List<String> log = <String>[];
      await tester.pumpWidget(
        _wrap(
          JeebMicHero(
            onPressStart: () => log.add('start'),
            onPressEnd: () => log.add('end'),
            onSlideCancel: () => log.add('cancel'),
          ),
        ),
      );

      final TestGesture gesture =
          await tester.startGesture(tester.getCenter(find.byIcon(Icons.mic)));
      await gesture.moveBy(
        const Offset(-(JeebMicHero.slideCancelThreshold - 1), 0),
      );
      await gesture.up();
      await tester.pump();
      expect(log, <String>['start', 'end']);
    });

    testWidgets('without onSlideCancel a long drag still sends',
        (WidgetTester tester) async {
      final List<String> log = <String>[];
      await tester.pumpWidget(
        _wrap(
          JeebMicHero(
            onPressStart: () => log.add('start'),
            onPressEnd: () => log.add('end'),
          ),
        ),
      );

      final TestGesture gesture =
          await tester.startGesture(tester.getCenter(find.byIcon(Icons.mic)));
      await gesture.moveBy(const Offset(-200, 0));
      await gesture.up();
      await tester.pump();
      expect(log, <String>['start', 'end']);
    });

    testWidgets('the whole disc is a hit target, not just the glyph',
        (WidgetTester tester) async {
      int starts = 0;
      await tester.pumpWidget(
        _wrap(
          JeebMicHero(
            size: JeebMicHero.sizeHero,
            onPressStart: () => starts++,
          ),
        ),
      );
      // 50px off centre is well outside the 56px glyph but inside the Ø128 disc.
      final Offset edge =
          tester.getCenter(find.byType(JeebMicHero)) + const Offset(50, 0);
      final TestGesture gesture = await tester.startGesture(edge);
      await gesture.up();
      await tester.pump();
      expect(starts, 1);
    });

    testWidgets('onTap and onLongPress are the discrete callbacks 04 needs',
        (WidgetTester tester) async {
      int taps = 0;
      int longPresses = 0;
      await tester.pumpWidget(
        _wrap(
          JeebMicHero(
            size: JeebMicHero.sizeCompact,
            onTap: () => taps++,
            onLongPress: () => longPresses++,
          ),
        ),
      );

      await tester.tap(find.byType(JeebMicHero));
      await tester.pump();
      expect(taps, 1);

      await tester.longPress(find.byType(JeebMicHero));
      await tester.pump();
      expect(longPresses, 1);
    });
  });

  group('JeebMicHero semantics', () {
    testWidgets('applies an explicit identifier and a button node',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          JeebMicHero(
            identifier: 'voice_request_mic_button',
            semanticLabel: 'Hold to record',
            onPressStart: () {},
            onPressEnd: () {},
          ),
        ),
      );
      expect(find.bySemanticsIdentifier('voice_request_mic_button'),
          findsOneWidget);
      expect(find.bySemanticsLabel('Hold to record'), findsOneWidget);
      expect(_buttonSemantics(), findsOneWidget);
    });

    testWidgets('the decorative mic has no node and no gesture layer',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const JeebMicHero.decorative(size: JeebMicHero.sizeLarge)),
      );
      expect(_buttonSemantics(), findsNothing);
      expect(
        find.descendant(
          of: find.byType(JeebMicHero),
          matching: find.byType(Listener),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(JeebMicHero),
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
      );
    });
  });

  group('JeebMicHero RTL', () {
    testWidgets('lays out identically under RTL — the décor is concentric',
        (WidgetTester tester) async {
      const Widget hero = JeebMicHero(progress: 0.25, isRecording: true);

      await tester.pumpWidget(_wrap(hero));
      final Rect ltrDisc = tester.getRect(find.byIcon(Icons.mic));
      final Rect ltrBox = tester.getRect(find.byType(JeebMicHero));

      await tester.pumpWidget(_wrap(hero, direction: TextDirection.rtl));
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byIcon(Icons.mic)), ltrDisc);
      expect(tester.getRect(find.byType(JeebMicHero)), ltrBox);
    });

    testWidgets('survives a 2x text scaler without resizing',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: Center(child: JeebMicHero(size: JeebMicHero.sizeCompact)),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(JeebMicHero)),
          const Size(JeebMicHero.sizeCompact, JeebMicHero.sizeCompact));
    });
  });
}
