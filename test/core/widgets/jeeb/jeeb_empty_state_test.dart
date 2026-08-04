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
}
