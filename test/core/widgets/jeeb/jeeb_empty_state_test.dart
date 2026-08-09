import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/motion/jeeb_motion.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_midnight_palette.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';

/// Gates for MIDNIGHT M1-3 (master plan §2.7 + study-notes ruling 1).
///
/// FAIL-WITHOUT: E1's route-dot ring and its four medallions are STATIC
/// (`03-MOTION-NOTES.md` §E1) — the §2.7 prose that says they orbit is what the
/// board contradicts, so a returning `jDash`/`jFloat` here is a regression.
void main() {
  Widget wrap(
    Widget child, {
    bool disableAnimations = false,
    TextDirection direction = TextDirection.ltr,
    ThemeData? theme,
  }) {
    return MaterialApp(
      theme: theme ?? AppTheme.midnight(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: SingleChildScrollView(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Finder inState(Type type) =>
      find.descendant(of: find.byType(JeebEmptyState), matching: find.byType(type));

  List<Duration> durationsOf<T extends Widget>(
    WidgetTester tester,
    Duration Function(T) read,
  ) => tester.widgetList<T>(inState(T)).map(read).toList();

  const JeebEmptyState e1 = JeebEmptyState(
    headline: 'What do you need?',
    body: 'No pending requests — say it, and offers from nearby Jeebers '
        'arrive in minutes.',
  );

  group('JeebEmptyState · Midnight tokens', () {
    testWidgets('headline is ink h1, body is mutedText body', (tester) async {
      await tester.pumpWidget(wrap(e1, disableAnimations: true));
      await tester.pumpAndSettle();

      final TextStyle headline = tester
          .widget<Text>(find.text('What do you need?'))
          .style!;
      expect(headline.color, JeebMidnight.ink);
      expect(headline.fontSize, 26);
      expect(headline.fontWeight, FontWeight.w700);
      expect(headline.letterSpacing, -0.6);

      final TextStyle body = tester
          .widget<Text>(find.textContaining('No pending requests'))
          .style!;
      expect(body.color, JeebMidnight.inkMuted);
      expect(body.fontSize, 14.5);
      expect(body.fontWeight, FontWeight.w500);
    });

    testWidgets('medallion discs are glass, subjects are DRAWN not stock',
        (tester) async {
      await tester.pumpWidget(wrap(e1, disableAnimations: true));
      await tester.pumpAndSettle();

      final Iterable<DecoratedBox> discs = tester
          .widgetList<DecoratedBox>(inState(DecoratedBox))
          .where(
            (DecoratedBox box) =>
                (box.decoration as BoxDecoration).color ==
                JeebMidnight.glassFillEmphasis,
          );
      expect(discs.length, JeebEmptyState.defaultMedallions.length);
      final BoxDecoration disc = discs.first.decoration as BoxDecoration;
      expect(disc.shape, BoxShape.circle);
      expect(disc.border!.top.color, JeebMidnight.glassBorderStrong);
      expect(disc.border!.top.width, 1);

      // Wave-A / the E1 caption: "no stock art". The four defaults carry drawn
      // subjects, so no Material glyph may appear inside the illustration.
      expect(
        JeebEmptyState.defaultMedallions
            .map((JeebEmptyMedallion m) => m.art)
            .toList(),
        <JeebEmptyMedallionArt>[
          JeebEmptyMedallionArt.medicine,
          JeebEmptyMedallionArt.groceries,
          JeebEmptyMedallionArt.document,
          JeebEmptyMedallionArt.gift,
        ],
      );
      expect(
        JeebEmptyState.defaultMedallions
            .every((JeebEmptyMedallion m) => m.icon == null),
        isTrue,
      );
      expect(inState(Icon), findsNothing);
    });

    testWidgets('block padding is E1\'s measured 36 gutter', (tester) async {
      await tester.pumpWidget(wrap(e1, disableAnimations: true));
      await tester.pumpAndSettle();

      expect(
        JeebEmptyState.defaultPadding,
        const EdgeInsets.symmetric(horizontal: 36),
      );
      final Padding padding = tester.widget<Padding>(inState(Padding).first);
      expect(padding.padding, const EdgeInsets.symmetric(horizontal: 36));
    });

    testWidgets('compact halves the illustration and tightens the block',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const JeebEmptyState.compact(
            headline: 'No saved addresses',
            body: 'Pin one and it lands here.',
          ),
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        JeebEmptyState.compactIllustrationSize,
        JeebEmptyState.defaultIllustrationSize / 2,
      );
      expect(
        tester.widget<Padding>(inState(Padding).first).padding,
        JeebEmptyState.compactPadding,
      );
      // h2 (20), not the full-page h1 (26).
      final TextStyle headline =
          tester.widget<Text>(find.text('No saved addresses')).style!;
      expect(headline.fontSize, 20);

      // The illustration is the block's only FittedBox.
      expect(
        tester.getSize(inState(FittedBox).first).width,
        JeebEmptyState.compactIllustrationSize,
      );
    });

    testWidgets('survives a theme with no Jeeb extensions', (tester) async {
      await tester.pumpWidget(
        wrap(e1, disableAnimations: true, theme: ThemeData.light()),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(JeebEmptyState), findsOneWidget);
    });
  });

  group('JeebEmptyState · E1 motion is board-measured', () {
    testWidgets('ring and medallions do not move; centre and stars do',
        (tester) async {
      await tester.pumpWidget(wrap(e1));
      await tester.pump();

      // The ring is dotted but STILL, and nothing floats.
      expect(inState(JDashedPath), findsNothing);
      expect(inState(JFloat), findsNothing);
      expect(inState(JHalo), findsNothing);
      expect(inState(JArcPulse), findsNothing);

      expect(
        durationsOf<JBreathe>(tester, (JBreathe w) => w.duration),
        <Duration>[const Duration(milliseconds: 3200)],
      );
      expect(
        durationsOf<JWaveBar>(tester, (JWaveBar w) => w.duration),
        <Duration>[const Duration(milliseconds: 1400)],
      );
      expect(
        durationsOf<JTwinkle>(tester, (JTwinkle w) => w.duration),
        <Duration>[
          const Duration(milliseconds: 2400),
          const Duration(milliseconds: 2800),
          const Duration(seconds: 3),
          const Duration(milliseconds: 2200),
          const Duration(milliseconds: 2600),
        ],
      );
      expect(
        durationsOf<JTwinkle>(tester, (JTwinkle w) => w.delay),
        <Duration>[
          Duration.zero,
          const Duration(milliseconds: 700),
          const Duration(milliseconds: 1300),
          const Duration(milliseconds: 1700),
          const Duration(milliseconds: 400),
        ],
      );
    });

    testWidgets('the illustration keeps the 300x280 board viewBox',
        (tester) async {
      await tester.pumpWidget(wrap(e1, disableAnimations: true));
      await tester.pumpAndSettle();

      final Size size = tester.getSize(inState(FittedBox).first);
      // 360 harness minus the 36 gutter on both sides, still 300:280.
      expect(size.width, 288);
      expect(size.height, closeTo(288 * 280 / 300, 0.01));
    });

    testWidgets('never grows past the board width', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(child: SizedBox(width: 500, child: e1)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSize(inState(FittedBox).first).width,
        JeebEmptyState.defaultIllustrationSize,
      );
    });

    testWidgets('narrow constraints shrink the illustration, never overflow',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.midnight(),
          home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(child: SizedBox(width: 240, child: e1)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // 240 minus the 36 gutter on both sides.
      expect(tester.getSize(inState(FittedBox).first).width, 168);
    });
  });

  group('JeebEmptyState · variants', () {
    testWidgets('pocket floats the mic over a breathing ground glow',
        (tester) async {
      await tester.pumpWidget(
        wrap(const JeebEmptyState(
          headline: 'Your pocket\'s empty — for now',
          variant: JeebEmptyStateVariant.pocket,
        )),
      );
      await tester.pump();

      expect(
        durationsOf<JFloat>(tester, (JFloat w) => w.duration),
        <Duration>[const Duration(milliseconds: 3400)],
      );
      expect(
        durationsOf<JBreathe>(tester, (JBreathe w) => w.duration),
        <Duration>[const Duration(milliseconds: 3200)],
      );
      expect(inState(JTwinkle), findsNWidgets(4));
      expect(inState(JDashedPath), findsNothing);
    });

    testWidgets('balcony dashes its route at 2.4s and waves in the bubble',
        (tester) async {
      await tester.pumpWidget(
        wrap(const JeebEmptyState(
          headline: 'Shout it off the balcony',
          variant: JeebEmptyStateVariant.balcony,
        )),
      );
      await tester.pump();

      final JDashedPath route = tester.widget<JDashedPath>(
        inState(JDashedPath).first,
      );
      expect(route.duration, const Duration(milliseconds: 2400));
      expect(route.dashLength, 1);
      expect(route.gapLength, 9);
      // A period that does not divide the travel visibly jumps at the loop.
      expect(route.travel.abs() % (route.dashLength + route.gapLength), 0);

      expect(
        durationsOf<JFloat>(tester, (JFloat w) => w.duration),
        <Duration>[const Duration(milliseconds: 3600)],
      );
      expect(
        durationsOf<JWaveBar>(tester, (JWaveBar w) => w.duration),
        <Duration>[const Duration(milliseconds: 1300)],
      );
      expect(
        durationsOf<JBreathe>(tester, (JBreathe w) => w.duration),
        <Duration>[
          const Duration(milliseconds: 3400),
          const Duration(milliseconds: 1800),
        ],
      );
      expect(inState(JTwinkle), findsNothing);
    });

    testWidgets('beacon fans six arcs on the 0/.4/.8 ladder, twice',
        (tester) async {
      await tester.pumpWidget(
        wrap(const JeebEmptyState(
          headline: 'Say it — they come',
          variant: JeebEmptyStateVariant.beacon,
        )),
      );
      await tester.pump();

      expect(
        durationsOf<JArcPulse>(tester, (JArcPulse w) => w.duration),
        List<Duration>.filled(6, const Duration(milliseconds: 2400)),
      );
      expect(
        durationsOf<JArcPulse>(tester, (JArcPulse w) => w.delay),
        <Duration>[
          Duration.zero,
          const Duration(milliseconds: 400),
          const Duration(milliseconds: 800),
          Duration.zero,
          const Duration(milliseconds: 400),
          const Duration(milliseconds: 800),
        ],
      );

      final JHalo halo = tester.widget<JHalo>(inState(JHalo).first);
      expect(halo.duration, const Duration(milliseconds: 2600));
      expect(halo.color, JeebMidnight.orangeSoft);

      expect(
        tester.widget<JDashedPath>(inState(JDashedPath).first).duration,
        const Duration(seconds: 2),
      );
      expect(
        durationsOf<JBreathe>(tester, (JBreathe w) => w.delay),
        <Duration>[Duration.zero, const Duration(milliseconds: 800)],
      );
      expect(inState(JTwinkle), findsNWidgets(3));
    });
  });

  group('JeebEmptyState · E2 radar', () {
    const JeebEmptyState radar = JeebEmptyState(
      headline: 'Broadcasting to 12 Jeebers…',
      body: 'First offers usually land within 4 minutes.',
      variant: JeebEmptyStateVariant.radar,
    );

    List<BoxDecoration> discsOf(WidgetTester tester) => tester
        .widgetList<DecoratedBox>(inState(DecoratedBox))
        .map((DecoratedBox box) => box.decoration as BoxDecoration)
        .where((BoxDecoration d) => d.color != null)
        .toList();

    testWidgets('the ring ladder walks OUTWARD-to-INWARD on one 3s period',
        (tester) async {
      await tester.pumpWidget(wrap(radar));
      await tester.pump();

      expect(
        durationsOf<JArcPulse>(tester, (JArcPulse w) => w.duration),
        List<Duration>.filled(3, const Duration(seconds: 3)),
      );
      // 1 / .5 / 0 — reversing this ladder makes the pulse travel outward,
      // which is the opposite reading (motion notes §E2).
      expect(
        durationsOf<JArcPulse>(tester, (JArcPulse w) => w.delay),
        <Duration>[
          const Duration(seconds: 1),
          const Duration(milliseconds: 500),
          Duration.zero,
        ],
      );
    });

    testWidgets('glow shares the 3s period; the three discs ride 2.6s at 0/.8/1.6',
        (tester) async {
      await tester.pumpWidget(wrap(radar));
      await tester.pump();

      expect(
        durationsOf<JBreathe>(tester, (JBreathe w) => w.duration),
        <Duration>[
          const Duration(seconds: 3),
          const Duration(milliseconds: 2600),
          const Duration(milliseconds: 2600),
          const Duration(milliseconds: 2600),
        ],
      );
      expect(
        durationsOf<JBreathe>(tester, (JBreathe w) => w.delay),
        <Duration>[
          Duration.zero,
          Duration.zero,
          const Duration(milliseconds: 800),
          const Duration(milliseconds: 1600),
        ],
      );
    });

    testWidgets('the core, its bloom and the satellite dot do NOT move',
        (tester) async {
      await tester.pumpWidget(wrap(radar));
      await tester.pump();

      // 7 animated elements exactly: 3 rings + glow + 3 discs. The satellite
      // is a dot, not a twinkle, and the orange core is still.
      expect(inState(JArcPulse), findsNWidgets(3));
      expect(inState(JBreathe), findsNWidgets(4));
      expect(inState(JTwinkle), findsNothing);
      expect(inState(JFloat), findsNothing);
      expect(inState(JHalo), findsNothing);
      expect(inState(JDashedPath), findsNothing);
      expect(inState(JWaveBar), findsNothing);
    });

    testWidgets('the radar board is the square 300x300 div', (tester) async {
      await tester.pumpWidget(wrap(radar, disableAnimations: true));
      await tester.pumpAndSettle();

      final Size size = tester.getSize(inState(FittedBox).first);
      expect(size.width, 288);
      expect(size.height, closeTo(288, 0.01));
    });

    testWidgets('defaults to K/N/R discs whose glass steps down together',
        (tester) async {
      await tester.pumpWidget(wrap(radar, disableAnimations: true));
      await tester.pumpAndSettle();

      expect(
        JeebEmptyState.radarMedallions
            .map((JeebEmptyMedallion m) => m.initial)
            .toList(),
        <String>['K', 'N', 'R'],
      );
      for (final String letter in <String>['K', 'N', 'R']) {
        expect(find.text(letter), findsOneWidget);
      }
      // Fill, border and ink step down together — one jeeber nearer than the
      // next; break the pairing and the discs stop reading as distance.
      final List<BoxDecoration> discs = discsOf(tester);
      expect(discs.length, 3);
      expect(
        discs.map((BoxDecoration d) => d.color!.a).toList(),
        <Matcher>[closeTo(0.12, 0.005), closeTo(0.09, 0.005), closeTo(0.06, 0.005)],
      );
      expect(
        discs.map((BoxDecoration d) => d.border!.top.color.a).toList(),
        <Matcher>[closeTo(0.25, 0.005), closeTo(0.18, 0.005), closeTo(0.12, 0.005)],
      );
      expect(
        <String>['K', 'N', 'R']
            .map((String l) => tester.widget<Text>(find.text(l)).style!.color!.a)
            .toList(),
        <Matcher>[closeTo(1, 0.005), closeTo(0.7, 0.005), closeTo(0.45, 0.005)],
      );
      expect(discs.every((BoxDecoration d) => d.shape == BoxShape.circle), isTrue);
      // Decorative: three stray letters must not be announced.
      expect(find.bySemanticsLabel('K'), findsNothing);
    });

    testWidgets('a consumer may pass real names and a custom centre',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const JeebEmptyState(
            headline: 'Broadcasting',
            variant: JeebEmptyStateVariant.radar,
            center: Placeholder(key: ValueKey<String>('core')),
            medallions: <JeebEmptyMedallion>[
              JeebEmptyMedallion.letter('Nour', semanticLabel: 'Nour'),
              JeebEmptyMedallion.letter('rami'),
              JeebEmptyMedallion.letter('  '),
              JeebEmptyMedallion.letter('Zeina'),
            ],
          ),
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();

      // Same derivation as the avatar kit, and capped at the three anchors.
      expect(find.text('N'), findsOneWidget);
      expect(find.text('R'), findsOneWidget);
      expect(find.text('?'), findsOneWidget);
      expect(find.text('Z'), findsNothing);
      expect(find.bySemanticsLabel('Nour'), findsOneWidget);
      // Ø58 core, replaced but still centred.
      expect(find.byKey(const ValueKey<String>('core')), findsOneWidget);
      expect(tester.getSize(find.byType(Placeholder)).width, closeTo(58, 0.01));
    });

    testWidgets('error danger-tints the radar centre', (tester) async {
      await tester.pumpWidget(
        wrap(
          const JeebEmptyState(
            headline: 'Something went wrong',
            variant: JeebEmptyStateVariant.radar,
            status: JeebEmptyStateStatus.error,
          ),
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();

      final DecoratedBox glow =
          tester.widget<DecoratedBox>(inState(DecoratedBox).first);
      final RadialGradient gradient =
          (glow.decoration as BoxDecoration).gradient! as RadialGradient;
      expect(gradient.colors.first.withValues(alpha: 1), JeebMidnight.danger);
      expect(gradient.stops, <double>[0, 0.7]);
    });
  });

  group('JeebEmptyState · E3 street', () {
    const JeebEmptyState street = JeebEmptyState(
      headline: 'Quiet street right now',
      body: 'No requests nearby — you\'re online.',
      variant: JeebEmptyStateVariant.street,
    );

    testWidgets('bulb and cone breathe as ONE 3.6s element', (tester) async {
      await tester.pumpWidget(wrap(street));
      await tester.pump();

      // Two board nodes, one composed widget: splitting them lets the cone
      // drift out of phase with its own bulb.
      expect(
        durationsOf<JBreathe>(tester, (JBreathe w) => w.duration),
        <Duration>[const Duration(milliseconds: 3600)],
      );
      expect(
        durationsOf<JBreathe>(tester, (JBreathe w) => w.delay),
        <Duration>[Duration.zero],
      );
    });

    testWidgets('two listening arcs ripple outward at 2.2s, 0 / .45s',
        (tester) async {
      await tester.pumpWidget(wrap(street));
      await tester.pump();

      expect(
        durationsOf<JArcPulse>(tester, (JArcPulse w) => w.duration),
        List<Duration>.filled(2, const Duration(milliseconds: 2200)),
      );
      expect(
        durationsOf<JArcPulse>(tester, (JArcPulse w) => w.delay),
        <Duration>[Duration.zero, const Duration(milliseconds: 450)],
      );
    });

    testWidgets('THIS tile\'s sparkles are static — no E1/E4 twinkle ladder',
        (tester) async {
      await tester.pumpWidget(wrap(street));
      await tester.pump();

      expect(inState(JTwinkle), findsNothing);
      expect(inState(JFloat), findsNothing);
      expect(inState(JHalo), findsNothing);
      expect(inState(JWaveBar), findsNothing);
      // Not `balcony`: E3 draws neither a request bubble nor a jDash route.
      expect(inState(JDashedPath), findsNothing);
    });

    testWidgets('keeps E3\'s 300x260 SVG viewBox', (tester) async {
      await tester.pumpWidget(wrap(street, disableAnimations: true));
      await tester.pumpAndSettle();

      final Size size = tester.getSize(inState(FittedBox).first);
      expect(size.width, 288);
      expect(size.height, closeTo(288 * 260 / 300, 0.01));
    });
  });

  group('JeebEmptyState · E4 parcel', () {
    const JeebEmptyState parcel = JeebEmptyState(
      headline: 'No orders yet',
      body: 'Your first errand is one voice note away.',
      variant: JeebEmptyStateVariant.parcel,
    );

    /// The illustration's static layers, in `_parcelLayers` order:
    /// 0 orbit ring · 1 box · 2 mic.
    RenderObject layer(WidgetTester tester, int index) =>
        tester.renderObject(inState(CustomPaint).at(index));

    testWidgets('animates exactly 4 elements — glow + the sparkle ladder',
        (tester) async {
      await tester.pumpWidget(wrap(parcel));
      await tester.pump();

      expect(
        durationsOf<JBreathe>(tester, (JBreathe w) => w.duration),
        <Duration>[const Duration(milliseconds: 3200)],
      );
      expect(
        durationsOf<JBreathe>(tester, (JBreathe w) => w.delay),
        <Duration>[Duration.zero],
      );
      expect(inState(JTwinkle), findsNWidgets(3));

      // The 250px orbit ring does NOT pulse, and E4 draws no waveform ears,
      // no float, no halo and no route — those are E1/pocket/balcony.
      expect(inState(JArcPulse), findsNothing);
      expect(inState(JWaveBar), findsNothing);
      expect(inState(JFloat), findsNothing);
      expect(inState(JHalo), findsNothing);
      expect(inState(JDashedPath), findsNothing);
    });

    testWidgets('rides E1\'s three-sparkle ladder verbatim', (tester) async {
      await tester.pumpWidget(wrap(parcel));
      await tester.pump();
      final List<Duration> parcelPeriods =
          durationsOf<JTwinkle>(tester, (JTwinkle w) => w.duration);
      final List<Duration> parcelDelays =
          durationsOf<JTwinkle>(tester, (JTwinkle w) => w.delay);

      await tester.pumpWidget(wrap(e1));
      await tester.pump();
      // E1's first three ARE the ladder; its 4th and 5th are the extra star
      // dots E4 does not draw.
      expect(
        parcelPeriods,
        durationsOf<JTwinkle>(tester, (JTwinkle w) => w.duration).sublist(0, 3),
      );
      expect(
        parcelDelays,
        durationsOf<JTwinkle>(tester, (JTwinkle w) => w.delay).sublist(0, 3),
      );
      expect(parcelPeriods, <Duration>[
        const Duration(milliseconds: 2400),
        const Duration(milliseconds: 2800),
        const Duration(seconds: 3),
      ]);
      expect(parcelDelays, <Duration>[
        Duration.zero,
        const Duration(milliseconds: 700),
        const Duration(milliseconds: 1300),
      ]);
    });

    testWidgets('keeps E4\'s 270x250 board box', (tester) async {
      await tester.pumpWidget(wrap(parcel, disableAnimations: true));
      await tester.pumpAndSettle();

      final Size size = tester.getSize(inState(FittedBox).first);
      expect(size.width, 288);
      expect(size.height, closeTo(288 * 250 / 270, 0.01));
    });

    testWidgets('the 250px orbit ring is a 1px white-7% hairline',
        (tester) async {
      await tester.pumpWidget(wrap(parcel, disableAnimations: true));
      await tester.pumpAndSettle();

      expect(
        layer(tester, 0),
        paints
          ..circle(
            x: 135,
            y: 125,
            radius: 125,
            color: JeebMidnight.ink.withValues(alpha: 0.07),
            strokeWidth: 1,
            style: PaintingStyle.stroke,
          ),
      );
    });

    testWidgets('the box is emphasis glass under a lid tipped off it',
        (tester) async {
      await tester.pumpWidget(wrap(parcel, disableAnimations: true));
      await tester.pumpAndSettle();

      expect(
        layer(tester, 1),
        paints
          ..rrect(
            rrect: RRect.fromRectAndRadius(
              const Rect.fromLTWH(70, 95, 130, 78),
              const Radius.circular(14),
            ),
            color: JeebMidnight.glassFillEmphasis,
          )
          ..rrect(color: JeebMidnight.glassBorderVivid)
          // The lid is drawn under its own -4° rotation, so the open box reads
          // as open rather than as a second rectangle.
          ..rotate(angle: -4 * math.pi / 180)
          ..rrect(
            rrect: RRect.fromRectAndRadius(
              const Rect.fromLTWH(60, 77, 150, 26),
              const Radius.circular(8),
            ),
            color: JeebMidnight.ink.withValues(alpha: 0.16),
          ),
      );
    });

    testWidgets('the mic glows orange inside the box', (tester) async {
      await tester.pumpWidget(wrap(parcel, disableAnimations: true));
      await tester.pumpAndSettle();

      expect(
        layer(tester, 2),
        paints
          // Ø34 disc + its `0 0 0 6px` bloom, centred on the box mouth.
          ..circle(
            x: 135,
            y: 130,
            radius: 20,
            color: JeebMidnight.orange.withValues(alpha: 0.2),
            strokeWidth: 6,
            style: PaintingStyle.stroke,
          )
          ..circle(
            x: 135,
            y: 130,
            radius: 17,
            color: JeebMidnight.orange,
            style: PaintingStyle.fill,
          ),
      );
    });

    testWidgets('the three sparkles are round dots: one orange, two white',
        (tester) async {
      await tester.pumpWidget(wrap(parcel, disableAnimations: true));
      await tester.pumpAndSettle();

      final List<BoxDecoration> dots = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: inState(JTwinkle),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((DecoratedBox box) => box.decoration as BoxDecoration)
          .toList();
      expect(dots.length, 3);
      // Round, not the 4-point star E1 draws for its ladder.
      expect(dots.every((BoxDecoration d) => d.shape == BoxShape.circle), isTrue);
      expect(dots.map((BoxDecoration d) => d.color).toList(), <Color>[
        JeebMidnight.orange,
        JeebMidnight.ink.withValues(alpha: 0.4),
        JeebMidnight.ink.withValues(alpha: 0.3),
      ]);
      // Board diameters 5 / 6 / 5, in the illustration's own units.
      final List<double> widths = tester
          .widgetList<JTwinkle>(inState(JTwinkle))
          .map((JTwinkle w) => tester.getSize(find.byWidget(w)).width)
          .toList();
      expect(widths, <double>[5, 6, 5]);
    });

    testWidgets('error danger-tints the glow and the mic', (tester) async {
      await tester.pumpWidget(
        wrap(
          const JeebEmptyState(
            headline: 'Something went wrong',
            variant: JeebEmptyStateVariant.parcel,
            status: JeebEmptyStateStatus.error,
          ),
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();

      final DecoratedBox glow =
          tester.widget<DecoratedBox>(inState(DecoratedBox).first);
      final RadialGradient gradient =
          (glow.decoration as BoxDecoration).gradient! as RadialGradient;
      expect(gradient.colors.first, JeebMidnight.danger.withValues(alpha: 0.22));
      expect(gradient.stops, <double>[0, 0.7]);
      expect(
        layer(tester, 2),
        paints
          ..circle(style: PaintingStyle.stroke)
          ..circle(radius: 17, color: JeebMidnight.danger),
      );
    });

    testWidgets('a custom centre replaces the Ø34 mic, the box stays',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const JeebEmptyState(
            headline: 'No orders yet',
            variant: JeebEmptyStateVariant.parcel,
            center: Placeholder(key: ValueKey<String>('parcel-centre')),
          ),
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('parcel-centre')), findsOneWidget);
      expect(tester.getSize(find.byType(Placeholder)).width, closeTo(34, 0.01));
      // Ring and box survive; only the mic layer is gone.
      expect(layer(tester, 0), paints..circle(x: 135, y: 125, radius: 125));
      expect(
        layer(tester, 1),
        paints..rrect(color: JeebMidnight.glassFillEmphasis),
      );
      expect(
        layer(tester, 2),
        isNot(paints..circle(radius: 17, color: JeebMidnight.orange)),
      );
    });
  });

  group('JeebEmptyState · medallion letters', () {
    test('medallionsFor only re-points the radar', () {
      expect(
        JeebEmptyState.medallionsFor(JeebEmptyStateVariant.radar),
        JeebEmptyState.radarMedallions,
      );
      for (final JeebEmptyStateVariant variant
          in JeebEmptyStateVariant.values.where(
        (JeebEmptyStateVariant v) => v != JeebEmptyStateVariant.radar,
      )) {
        expect(
          JeebEmptyState.medallionsFor(variant),
          JeebEmptyState.defaultMedallions,
          reason: '$variant',
        );
      }
    });

    test('a letter medallion carries no icon and no art', () {
      const JeebEmptyMedallion letter = JeebEmptyMedallion.letter('K');
      expect(letter.icon, isNull);
      expect(letter.art, isNull);
      expect(letter.initial, 'K');
      expect(
        const JeebEmptyMedallion(icon: Icons.pets).initial,
        isNull,
      );
      expect(
        const JeebEmptyMedallion.art(JeebEmptyMedallionArt.gift).initial,
        isNull,
      );
    });

    test('equality reads the letter', () {
      final JeebEmptyMedallion built =
          JeebEmptyMedallion.letter(String.fromCharCode(75));
      expect(built, const JeebEmptyMedallion.letter('K'));
      expect(built.hashCode, const JeebEmptyMedallion.letter('K').hashCode);
      expect(built, isNot(const JeebEmptyMedallion.letter('N')));
      expect(built, isNot(const JeebEmptyMedallion(icon: Icons.pets)));
    });

    testWidgets('E1 medallions accept a letter too, at the Ø54 disc size',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const JeebEmptyState(
            headline: 'Nothing here',
            medallions: <JeebEmptyMedallion>[
              JeebEmptyMedallion.letter('K', tint: JeebMidnight.orangeSoft),
            ],
          ),
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();

      final TextStyle style = tester.widget<Text>(find.text('K')).style!;
      expect(style.fontSize, closeTo(54 * 0.36, 0.01));
      expect(style.fontWeight, FontWeight.w800);
      expect(style.color, JeebMidnight.orangeSoft);
      expect(inState(Icon), findsNothing);
    });
  });

  group('JeebEmptyState · states', () {
    testWidgets('loading breathes a skeleton and withholds the CTA',
        (tester) async {
      await tester.pumpWidget(
        wrap(const JeebEmptyState(
          headline: 'Loading',
          status: JeebEmptyStateStatus.loading,
          action: Text('Retry'),
        )),
      );
      await tester.pump();

      expect(inState(JBreathe), findsOneWidget);
      expect(inState(JTwinkle), findsNothing);
      expect(inState(JWaveBar), findsNothing);
      expect(find.text('Retry'), findsNothing);
      // Skeleton draws its own discs — no icon medallions.
      expect(inState(Icon), findsNothing);
      expect(find.text('Loading'), findsOneWidget);
    });

    testWidgets('error keeps the composition and shows the CTA',
        (tester) async {
      await tester.pumpWidget(
        wrap(const JeebEmptyState(
          headline: 'Something went wrong',
          status: JeebEmptyStateStatus.error,
          action: Text('Retry'),
        )),
      );
      await tester.pump();

      expect(find.text('Retry'), findsOneWidget);
      expect(inState(JTwinkle), findsNWidgets(5));
      expect(inState(JWaveBar), findsOneWidget);
    });

    testWidgets('error tints the centre danger, empty tints it orange',
        (tester) async {
      Color glowOf(WidgetTester tester) {
        final DecoratedBox glow = tester.widget<DecoratedBox>(
          inState(DecoratedBox).first,
        );
        final RadialGradient gradient =
            (glow.decoration as BoxDecoration).gradient! as RadialGradient;
        return gradient.colors.first;
      }

      await tester.pumpWidget(wrap(e1, disableAnimations: true));
      await tester.pumpAndSettle();
      expect(glowOf(tester).withValues(alpha: 1), JeebMidnight.orange);

      await tester.pumpWidget(
        wrap(
          const JeebEmptyState(
            headline: 'Something went wrong',
            status: JeebEmptyStateStatus.error,
          ),
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(glowOf(tester).withValues(alpha: 1), JeebMidnight.danger);
    });

    testWidgets('error swaps the soft accent too, so nothing stays orange',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const JeebEmptyState(
            headline: 'Something went wrong',
            variant: JeebEmptyStateVariant.beacon,
            status: JeebEmptyStateStatus.error,
          ),
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<JHalo>(inState(JHalo).first).color,
        JeebMidnight.dangerSoft,
      );
    });
  });

  group('JeebEmptyState · composition API', () {
    testWidgets('medallions are configurable and capped at the four anchors',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const JeebEmptyState(
            headline: 'Nothing here',
            medallions: <JeebEmptyMedallion>[
              JeebEmptyMedallion(
                icon: Icons.local_pharmacy,
                semanticLabel: 'medicine',
              ),
              JeebEmptyMedallion(icon: Icons.restaurant),
              JeebEmptyMedallion(icon: Icons.description),
              JeebEmptyMedallion(
                icon: Icons.redeem,
                tint: JeebMidnight.orangeSoft,
              ),
              JeebEmptyMedallion(icon: Icons.pets),
            ],
          ),
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(inState(Icon), findsNWidgets(4));
      expect(find.byIcon(Icons.pets), findsNothing);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.redeem)).color,
        JeebMidnight.orangeSoft,
      );
      expect(find.bySemanticsLabel('medicine'), findsOneWidget);
    });

    testWidgets('a custom centre replaces the mic, the halo stays',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const JeebEmptyState(
            headline: 'Nothing here',
            center: Placeholder(key: ValueKey<String>('custom-centre')),
          ),
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('custom-centre')), findsOneWidget);
      expect(tester.getSize(find.byType(Placeholder)).width, closeTo(94, 0.01));
      expect(inState(JBreathe), findsOneWidget);
      expect(inState(JWaveBar), findsOneWidget);
    });

    testWidgets('identifiers slot onto block, headline and body',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const JeebEmptyState(
            headline: 'What do you need?',
            body: 'Say it.',
            identifier: 'client_home_empty',
            headlineIdentifier: 'client_home_empty_headline',
            bodyIdentifier: 'client_home_empty_body',
            semanticLabel: 'No pending requests',
          ),
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsIdentifier('client_home_empty'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('client_home_empty_headline'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('client_home_empty_body'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('No pending requests'), findsOneWidget);
    });
  });

  group('JeebEmptyState · the skeleton follows ITS OWN variant', () {
    /// The loading tree draws exactly one vector: the skeleton.
    RenderObject skeleton(WidgetTester tester) =>
        tester.renderObject(inState(CustomPaint));

    Future<void> pumpLoading(
      WidgetTester tester,
      JeebEmptyStateVariant variant, {
      List<JeebEmptyMedallion>? medallions,
    }) async {
      await tester.pumpWidget(
        wrap(
          JeebEmptyState(
            headline: 'Loading',
            variant: variant,
            status: JeebEmptyStateStatus.loading,
            medallions: medallions,
          ),
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();
    }

    Color ink(double alpha) => JeebMidnight.ink.withValues(alpha: alpha);

    const Map<JeebEmptyStateVariant, Size> boards =
        <JeebEmptyStateVariant, Size>{
          JeebEmptyStateVariant.e1: Size(300, 280),
          JeebEmptyStateVariant.radar: Size(300, 300),
          JeebEmptyStateVariant.street: Size(300, 260),
          JeebEmptyStateVariant.parcel: Size(270, 250),
          JeebEmptyStateVariant.pocket: Size(300, 270),
          JeebEmptyStateVariant.balcony: Size(300, 270),
          JeebEmptyStateVariant.beacon: Size(300, 270),
        };

    for (final MapEntry<JeebEmptyStateVariant, Size> board in boards.entries) {
      testWidgets(
          '${board.key} LOADS its own ${board.value.width.toInt()}x'
          '${board.value.height.toInt()} board, never a borrowed one',
          (tester) async {
        await pumpLoading(tester, board.key);
        final Size loading = tester.getSize(inState(FittedBox).first);

        await tester.pumpWidget(
          wrap(
            JeebEmptyState(headline: 'Empty', variant: board.key),
            disableAnimations: true,
          ),
        );
        await tester.pumpAndSettle();

        // A skeleton on the wrong board morphs into a different shape the
        // moment the data lands.
        expect(loading.width, 288);
        expect(
          loading.height,
          closeTo(288 * board.value.height / board.value.width, 0.01),
        );
        expect(loading, tester.getSize(inState(FittedBox).first));
      });
    }

    testWidgets('E1 keeps the halo, the dot ring, its Ø94 centre and 4 discs',
        (tester) async {
      await pumpLoading(tester, JeebEmptyStateVariant.e1);

      expect(
        skeleton(tester),
        paints
          ..circle(
            x: 150,
            y: 140,
            radius: 132,
            color: ink(0.07),
            strokeWidth: 1.5,
            style: PaintingStyle.stroke,
          )
          ..path(color: ink(0.16), strokeWidth: 1.5)
          ..circle(
            x: 150,
            y: 140,
            radius: 47,
            color: JeebMidnight.glassFillEmphasis,
            style: PaintingStyle.fill,
          )
          ..circle(
            x: 150,
            y: 140,
            radius: 47,
            color: JeebMidnight.glassBorderStrong,
            strokeWidth: 1,
          )
          ..circle(x: 64, y: 76, radius: 27, color: JeebMidnight.glassFill)
          ..circle(x: 64, y: 76, radius: 27, color: JeebMidnight.glassBorder)
          ..circle(x: 236, y: 82, radius: 27, color: JeebMidnight.glassFill)
          ..circle(x: 236, y: 82, radius: 27, color: JeebMidnight.glassBorder)
          ..circle(x: 60, y: 204, radius: 27, color: JeebMidnight.glassFill)
          ..circle(x: 60, y: 204, radius: 27, color: JeebMidnight.glassBorder)
          ..circle(x: 238, y: 198, radius: 27, color: JeebMidnight.glassFill)
          ..circle(x: 238, y: 198, radius: 27, color: JeebMidnight.glassBorder),
      );
      // 1 halo + 2 centre + 2×4 discs; the dot ring is a path.
      expect(skeleton(tester), paintsExactlyCountTimes(#drawCircle, 11));
    });

    testWidgets('the radar loads a RADAR: 3 rings, a Ø58 core, THREE discs',
        (tester) async {
      await pumpLoading(tester, JeebEmptyStateVariant.radar);

      expect(
        skeleton(tester),
        paints
          ..circle(
            x: 150,
            y: 150,
            radius: 149.5,
            color: ink(0.12),
            strokeWidth: 1,
          )
          ..circle(x: 150, y: 150, radius: 107.5, color: ink(0.20))
          ..circle(x: 150, y: 150, radius: 65.5, color: ink(0.32))
          ..circle(
            x: 150,
            y: 150,
            radius: 29,
            color: JeebMidnight.glassFillEmphasis,
          )
          ..circle(
            x: 150,
            y: 150,
            radius: 29,
            color: JeebMidnight.glassBorderStrong,
          )
          ..circle(x: 56, y: 92, radius: 18, color: JeebMidnight.glassFill)
          ..circle(x: 56, y: 92, radius: 18, color: JeebMidnight.glassBorder)
          ..circle(x: 238, y: 138, radius: 18, color: JeebMidnight.glassFill)
          ..circle(x: 238, y: 138, radius: 18, color: JeebMidnight.glassBorder)
          ..circle(x: 92, y: 230, radius: 18, color: JeebMidnight.glassFill)
          ..circle(x: 92, y: 230, radius: 18, color: JeebMidnight.glassBorder),
      );
      // 3 rings + 2 core + 2×3 discs, and NOT a fourth medallion.
      expect(skeleton(tester), paintsExactlyCountTimes(#drawCircle, 11));
      // E1's halo, its Ø94 centre and its dotted ring belong to E1 alone.
      expect(skeleton(tester), isNot(paints..circle(radius: 132)));
      expect(skeleton(tester), isNot(paints..circle(radius: 47)));
      expect(skeleton(tester), isNot(paints..circle(radius: 27)));
      expect(skeleton(tester), isNot(paints..path()));
    });

    testWidgets('street and parcel invent NO discs', (tester) async {
      await pumpLoading(tester, JeebEmptyStateVariant.street);
      expect(
        skeleton(tester),
        paints
          ..circle(
            x: 150,
            y: 128,
            radius: 122,
            color: ink(0.07),
            strokeWidth: 1.5,
          )
          ..circle(
            x: 149,
            y: 150,
            radius: 47,
            color: JeebMidnight.glassFillEmphasis,
          )
          ..circle(
            x: 149,
            y: 150,
            radius: 47,
            color: JeebMidnight.glassBorderStrong,
          ),
      );
      // One ring + the centre pair. Four medallions would be eight more.
      expect(skeleton(tester), paintsExactlyCountTimes(#drawCircle, 3));
      expect(skeleton(tester), isNot(paints..circle(color: JeebMidnight.glassFill)));

      await pumpLoading(tester, JeebEmptyStateVariant.parcel);
      expect(
        skeleton(tester),
        paints
          ..circle(
            x: 135,
            y: 125,
            radius: 125,
            color: ink(0.07),
            strokeWidth: 1,
          )
          ..circle(
            x: 135,
            y: 130,
            radius: 17,
            color: JeebMidnight.glassFillEmphasis,
          )
          ..circle(
            x: 135,
            y: 130,
            radius: 17,
            color: JeebMidnight.glassBorderStrong,
          ),
      );
      expect(skeleton(tester), paintsExactlyCountTimes(#drawCircle, 3));
      expect(skeleton(tester), isNot(paints..circle(color: JeebMidnight.glassFill)));
    });

    testWidgets('pocket, balcony and beacon each load their own centre size',
        (tester) async {
      await pumpLoading(tester, JeebEmptyStateVariant.pocket);
      expect(
        skeleton(tester),
        paints
          ..circle(x: 150, y: 135, radius: 120, color: ink(0.07))
          ..path(color: ink(0.13), strokeWidth: 1.5)
          ..circle(
            x: 150,
            y: 86,
            radius: 24,
            color: JeebMidnight.glassFillEmphasis,
          ),
      );
      expect(skeleton(tester), paintsExactlyCountTimes(#drawCircle, 3));

      await pumpLoading(tester, JeebEmptyStateVariant.balcony);
      expect(
        skeleton(tester),
        paints
          ..circle(
            x: 173,
            y: 117,
            radius: 25,
            color: JeebMidnight.glassFillEmphasis,
          )
          ..circle(
            x: 173,
            y: 117,
            radius: 25,
            color: JeebMidnight.glassBorderStrong,
          ),
      );
      // Sample B draws no still ring, so its skeleton must not borrow one.
      expect(skeleton(tester), paintsExactlyCountTimes(#drawCircle, 2));

      await pumpLoading(tester, JeebEmptyStateVariant.beacon);
      expect(
        skeleton(tester),
        paints
          ..circle(
            x: 150,
            y: 112,
            radius: 36,
            color: JeebMidnight.glassFillEmphasis,
          )
          ..circle(
            x: 150,
            y: 112,
            radius: 36,
            color: JeebMidnight.glassBorderStrong,
          ),
      );
      expect(skeleton(tester), paintsExactlyCountTimes(#drawCircle, 2));
    });

    testWidgets('a skeleton carries no colour identity beyond the glass rungs',
        (tester) async {
      for (final JeebEmptyStateVariant variant
          in JeebEmptyStateVariant.values) {
        await pumpLoading(tester, variant);
        // Every stroke and fill is ink or white at some alpha — an accent at
        // ANY alpha (E2's rings, E4's mic, the amber lamp) is identity.
        expect(
          skeleton(tester),
          paints
            ..everything((Symbol method, List<dynamic> arguments) {
              for (final Object? argument in arguments) {
                if (argument is! Paint) {
                  continue;
                }
                final int opaque =
                    argument.color.withValues(alpha: 1).toARGB32();
                if (opaque != JeebMidnight.ink.toARGB32() &&
                    opaque != 0xFFFFFFFF) {
                  return false;
                }
              }
              return true;
            }),
          reason: '$variant',
        );
        for (final Color hue in const <Color>[
          JeebMidnight.orange,
          JeebMidnight.orangeBright,
          JeebMidnight.orangeSoft,
          JeebMidnight.amber,
          JeebMidnight.danger,
          JeebMidnight.inkMuted,
        ]) {
          expect(
            skeleton(tester),
            isNot(paints..circle(color: hue)),
            reason: '$variant · $hue',
          );
        }
        // Still one breathing layer, and none of the lit tile's motion.
        expect(inState(JBreathe), findsOneWidget);
        expect(inState(JTwinkle), findsNothing);
        expect(inState(JArcPulse), findsNothing);
        expect(inState(JFloat), findsNothing);
        expect(inState(JHalo), findsNothing);
        expect(inState(JDashedPath), findsNothing);
        expect(inState(JWaveBar), findsNothing);
      }
    });

    testWidgets('the disc count follows the CALLER, capped at the anchors',
        (tester) async {
      // The wallet composes E1 with no medallions at all: loading four discs
      // it never draws is the shape-change lanes reported.
      await pumpLoading(
        tester,
        JeebEmptyStateVariant.e1,
        medallions: const <JeebEmptyMedallion>[],
      );
      expect(skeleton(tester), paintsExactlyCountTimes(#drawCircle, 3));
      expect(skeleton(tester), isNot(paints..circle(color: JeebMidnight.glassFill)));

      await pumpLoading(
        tester,
        JeebEmptyStateVariant.e1,
        medallions: const <JeebEmptyMedallion>[
          JeebEmptyMedallion.art(JeebEmptyMedallionArt.gift),
          JeebEmptyMedallion.art(JeebEmptyMedallionArt.medicine),
        ],
      );
      // 1 halo + 2 centre + 2×2 discs, and the anchors keep their order.
      expect(skeleton(tester), paintsExactlyCountTimes(#drawCircle, 7));
      expect(
        skeleton(tester),
        paints
          ..circle(radius: 132)
          ..circle(radius: 47)
          ..circle(radius: 47)
          ..circle(x: 64, y: 76, radius: 27)
          ..circle(x: 64, y: 76, radius: 27)
          ..circle(x: 236, y: 82, radius: 27),
      );

      // Five letters on a three-anchor radar still load three.
      await pumpLoading(
        tester,
        JeebEmptyStateVariant.radar,
        medallions: const <JeebEmptyMedallion>[
          JeebEmptyMedallion.letter('K'),
          JeebEmptyMedallion.letter('N'),
          JeebEmptyMedallion.letter('R'),
          JeebEmptyMedallion.letter('Z'),
          JeebEmptyMedallion.letter('A'),
        ],
      );
      expect(skeleton(tester), paintsExactlyCountTimes(#drawCircle, 11));
    });
  });

  group('JeebEmptyState · the centre slot', () {
    testWidgets('pocket honours a custom centre at Ø48, and it still floats',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const JeebEmptyState(
            headline: 'Nothing here',
            variant: JeebEmptyStateVariant.pocket,
            center: Placeholder(key: ValueKey<String>('pocket-centre')),
          ),
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('pocket-centre')), findsOneWidget);
      expect(tester.getSize(find.byType(Placeholder)).width, closeTo(48, 0.01));
      expect(
        find.descendant(
          of: inState(JFloat),
          matching: find.byType(Placeholder),
        ),
        findsOneWidget,
      );
      // The drawn orange mic is GONE — a read-only surface must not sprout one.
      for (final RenderObject layer
          in tester.renderObjectList(inState(CustomPaint))) {
        expect(
          layer,
          isNot(
            paints..circle(x: 150, y: 86, radius: 24, color: JeebMidnight.orange),
          ),
        );
      }
    });

    testWidgets('beacon honours a custom centre at Ø72; halo and arcs stay',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          const JeebEmptyState(
            headline: 'Say it — they come',
            variant: JeebEmptyStateVariant.beacon,
            center: Placeholder(key: ValueKey<String>('beacon-centre')),
          ),
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('beacon-centre')), findsOneWidget);
      expect(tester.getSize(find.byType(Placeholder)).width, closeTo(72, 0.01));
      expect(inState(JHalo), findsOneWidget);
      expect(inState(JArcPulse), findsNWidgets(6));
      for (final RenderObject layer
          in tester.renderObjectList(inState(CustomPaint))) {
        expect(
          layer,
          isNot(paints..circle(x: 150, y: 112, radius: 36)),
        );
      }
    });

    testWidgets('the drawn mic survives when no centre is passed',
        (tester) async {
      for (final (JeebEmptyStateVariant variant, double x, double y, double r)
          in const <(JeebEmptyStateVariant, double, double, double)>[
        (JeebEmptyStateVariant.pocket, 150, 86, 24),
        (JeebEmptyStateVariant.beacon, 150, 112, 36),
      ]) {
        await tester.pumpWidget(
          wrap(
            JeebEmptyState(headline: 'Empty', variant: variant),
            disableAnimations: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.renderObjectList(inState(CustomPaint)),
          anyElement(paints..circle(x: x, y: y, radius: r)),
          reason: '$variant',
        );
      }
    });

    testWidgets('street and balcony have no centre subject to replace',
        (tester) async {
      for (final JeebEmptyStateVariant variant in <JeebEmptyStateVariant>[
        JeebEmptyStateVariant.street,
        JeebEmptyStateVariant.balcony,
      ]) {
        await tester.pumpWidget(
          wrap(
            JeebEmptyState(
              headline: 'Empty',
              variant: variant,
              center: const Placeholder(),
            ),
            disableAnimations: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(Placeholder), findsNothing, reason: '$variant');
      }
    });
  });

  group('JeebEmptyState · reduce motion', () {
    for (final JeebEmptyStateVariant variant in JeebEmptyStateVariant.values) {
      testWidgets('$variant settles under reduce motion', (tester) async {
        await tester.pumpWidget(
          wrap(
            JeebEmptyState(headline: 'Empty', variant: variant),
            disableAnimations: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Empty'), findsOneWidget);
      });
    }

    testWidgets('loading settles under reduce motion', (tester) async {
      await tester.pumpWidget(
        wrap(
          const JeebEmptyState(
            headline: 'Empty',
            status: JeebEmptyStateStatus.loading,
          ),
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('RTL does not mirror the illustration', (tester) async {
      await tester.pumpWidget(
        wrap(e1, disableAnimations: true, direction: TextDirection.rtl),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Medallion 0 is the top-START anchor and 1 the top-END one; the
      // illustration is absolutely placed, so RTL must not swap them.
      final Finder discs = find.byWidgetPredicate(
        (Widget w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color ==
                JeebMidnight.glassFillEmphasis,
      );
      expect(tester.getCenter(discs.at(0)).dx,
          lessThan(tester.getCenter(discs.at(1)).dx));
    });
  });

  group('JeebEmptyState · D9 danger badge + D4 text-scale', () {
    testWidgets('the error status carries a SHAPE, not only a hue', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const JeebEmptyState(
            headline: 'Something went wrong',
            status: JeebEmptyStateStatus.error,
          ),
          disableAnimations: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('jeeb-empty-error-badge')), findsOneWidget);
      expect(find.byIcon(Icons.priority_high), findsOneWidget);
    });

    for (final status in const <JeebEmptyStateStatus>[
      JeebEmptyStateStatus.empty,
      JeebEmptyStateStatus.loading,
    ]) {
      testWidgets('the badge stays off the ${status.name} status', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrap(
            JeebEmptyState(headline: 'Nothing here', status: status),
            disableAnimations: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('jeeb-empty-error-badge')), findsNothing);
      });
    }

    testWidgets('scaled text reclaims illustration width, floored at 1.6x', (
      tester,
    ) async {
      Future<double> widthAt(double scale) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.midnight(),
            home: MediaQuery(
              data: MediaQueryData(
                disableAnimations: true,
                textScaler: TextScaler.linear(scale),
              ),
              child: const Directionality(
                textDirection: TextDirection.ltr,
                child: Scaffold(
                  body: SizedBox(
                    width: 360,
                    child: SingleChildScrollView(
                      child: JeebEmptyState(
                        headline: 'Nothing yet',
                        illustrationSize: 240,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return tester.getSize(find.byType(FittedBox).first).width;
      }

      expect(await widthAt(1.0), closeTo(240, 0.5));
      expect(await widthAt(2.0), closeTo(150, 0.5));
    });
  });
}
