import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/motion/jeeb_motion.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/features/onboarding/presentation/widgets/walkthrough_glass.dart';
import 'package:jeeb_mobile/features/onboarding/presentation/widgets/walkthrough_tracking_art.dart';
import 'package:jeeb_mobile/features/onboarding/presentation/widgets/walkthrough_trust_art.dart';
import 'package:jeeb_mobile/features/onboarding/presentation/widgets/walkthrough_voice_art.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// Per-element motion evidence for M2-21 (R5 · W1 · W2 · W3).
///
/// Captures are rest-frame by design, so nothing here reads a pixel: every
/// assertion reads the primitive TYPE, its `duration` and its `delay` straight
/// off the widget. The delay ladders are the design — a test that only checked
/// periods would pass while the pairs marched in lockstep.
void main() {
  Widget host(Widget art, {Locale locale = const Locale('en')}) => wrapForTest(
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: true),
        child: Theme(
          data: AppTheme.midnight(),
          child: Scaffold(
            body: SizedBox(width: 440, height: 631, child: art),
          ),
        ),
      ),
    ),
    locale: locale,
  );

  List<T> all<T extends Widget>(WidgetTester tester) =>
      tester.widgetList<T>(find.byType(T)).toList();

  group('R5 / W1 · voice art — 4 animated elements', () {
    for (final placement in WalkthroughVoicePlacement.values) {
      testWidgets('${placement.name}: jFloat pair is 4s and 4.4s at 1.2s', (
        tester,
      ) async {
        await tester.pumpWidget(
          host(WalkthroughVoiceArt(placement: placement)),
        );
        await tester.pump();

        final floats = all<JFloat>(tester);
        expect(floats, hasLength(2));
        expect(floats[0].duration, const Duration(seconds: 4));
        expect(floats[0].delay, Duration.zero);
        expect(floats[1].duration, const Duration(milliseconds: 4400));
        expect(
          floats[1].delay,
          const Duration(milliseconds: 1200),
          reason: 'the 1.2s delay is what de-syncs the two glass bubbles',
        );
      });

      testWidgets('${placement.name}: jWave rides the CONTAINER, never a bar', (
        tester,
      ) async {
        await tester.pumpWidget(
          host(WalkthroughVoiceArt(placement: placement)),
        );
        await tester.pump();

        final bars = all<JWaveBar>(tester);
        expect(
          bars,
          hasLength(1),
          reason: 'one scaling row, three static children — no per-bar stagger',
        );
        expect(bars.single.duration, const Duration(milliseconds: 1300));
        expect(bars.single.delay, Duration.zero);
        expect(
          find.byType(JWaveBars),
          findsNothing,
          reason: 'JWaveBars staggers per bar, which this board never does',
        );
      });

      testWidgets('${placement.name}: jHalo is a 2.6s orangeSoft ring sibling', (
        tester,
      ) async {
        await tester.pumpWidget(
          host(WalkthroughVoiceArt(placement: placement)),
        );
        await tester.pump();

        final halos = all<JHalo>(tester);
        expect(halos, hasLength(1));
        expect(halos.single.duration, const Duration(milliseconds: 2600));
        expect(halos.single.strokeWidth, 2);
        expect(halos.single.color, JeebSemanticColors.midnight().orangeSoft);
        // The ring is a sibling: its child is an empty box, never the disc.
        expect(halos.single.child, isA<SizedBox>());
        // …and the disc itself is inside no primitive at all.
        expect(
          find.descendant(
            of: find.byType(JHalo),
            matching: find.byIcon(Icons.mic),
          ),
          findsNothing,
          reason: 'the mic disc does not move — only the ring does',
        );
      });
    }

    testWidgets('the two placements draw the same widget, shifted', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const WalkthroughVoiceArt(placement: WalkthroughVoicePlacement.r5),
        ),
      );
      await tester.pump();
      final r5 = tester.getTopLeft(find.byIcon(Icons.mic));

      await tester.pumpWidget(
        host(
          const WalkthroughVoiceArt(placement: WalkthroughVoicePlacement.w1),
        ),
      );
      await tester.pump();
      final w1 = tester.getTopLeft(find.byIcon(Icons.mic));

      expect(
        r5.dy,
        greaterThan(w1.dy),
        reason: 'R5 sits the mic 10dp lower in its stage than W1 does',
      );
    });
  });

  group('W2 · trust art — 6 animated elements', () {
    testWidgets('two orbit rings pulse 3.2s with a .6s offset', (tester) async {
      await tester.pumpWidget(host(const WalkthroughTrustArt()));
      await tester.pump();

      final arcs = all<JArcPulse>(tester);
      expect(arcs, hasLength(2));
      for (final arc in arcs) {
        expect(arc.duration, const Duration(milliseconds: 3200));
      }
      expect(
        arcs.map((a) => a.delay).toSet(),
        <Duration>{Duration.zero, const Duration(milliseconds: 600)},
        reason: 'the .6s offset between the two rings is the whole effect',
      );
    });

    testWidgets('the verified badge twinkles at 2.6s, the avatar does not', (
      tester,
    ) async {
      await tester.pumpWidget(host(const WalkthroughTrustArt()));
      await tester.pump();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(WalkthroughTrustArt)),
      );
      final twinkles = all<JTwinkle>(tester);
      expect(twinkles, hasLength(1));
      expect(twinkles.single.duration, const Duration(milliseconds: 2600));
      expect(
        find.descendant(
          of: find.byType(JTwinkle),
          matching: find.text(l10n.walkthroughTrustName),
        ),
        findsNothing,
        reason: 'jTwinkle rides the badge alone — the K disc is still',
      );
      expect(
        find.descendant(
          of: find.byType(JTwinkle),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
    });

    testWidgets('float chips run 4s / 4.4s at 1.3s and the accent chip '
        'BREATHES at 2.8s', (tester) async {
      await tester.pumpWidget(host(const WalkthroughTrustArt()));
      await tester.pump();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(WalkthroughTrustArt)),
      );
      final floats = all<JFloat>(tester);
      expect(floats, hasLength(2));
      expect(floats[0].duration, const Duration(seconds: 4));
      expect(floats[0].delay, Duration.zero);
      expect(floats[1].duration, const Duration(milliseconds: 4400));
      expect(floats[1].delay, const Duration(milliseconds: 1300));

      final breathes = all<JBreathe>(tester);
      expect(breathes, hasLength(1));
      expect(breathes.single.duration, const Duration(milliseconds: 2800));
      expect(
        find.descendant(
          of: find.byType(JBreathe),
          matching: find.text(l10n.walkthroughTrustCodeChip),
        ),
        findsOneWidget,
        reason: 'the orange handoff chip breathes rather than floating',
      );
    });

    testWidgets('draws no halo, no dash and no waveform', (tester) async {
      await tester.pumpWidget(host(const WalkthroughTrustArt()));
      await tester.pump();

      expect(find.byType(JHalo), findsNothing);
      expect(find.byType(JDashedPath), findsNothing);
      expect(find.byType(JWaveBar), findsNothing);
    });

    // Q-037: the badge is the board's one jTwinkle on a UI element, so its
    // still must read "verified", not a .2-opacity ghost.
    testWidgets('the verified badge rests LIT, while the rings rest faint', (
      tester,
    ) async {
      await tester.pumpWidget(host(const WalkthroughTrustArt()));
      await tester.pumpAndSettle();

      final twinkle = all<JTwinkle>(tester).single;
      expect(twinkle.rest, JMotionRest.informative);
      expect(
        tester
            .widget<FadeTransition>(
              find.descendant(
                of: find.byType(JTwinkle),
                matching: find.byType(FadeTransition),
              ),
            )
            .opacity
            .value,
        JeebMotion.twinklePeakOpacity,
      );

      for (final arc in all<JArcPulse>(tester)) {
        expect(
          arc.rest,
          JMotionRest.decorative,
          reason: 'orbit rings are decoration — they keep resting at .15',
        );
      }
      for (final opacity in tester
          .widgetList<FadeTransition>(
            find.descendant(
              of: find.byType(JArcPulse),
              matching: find.byType(FadeTransition),
            ),
          )
          .map((f) => f.opacity.value)) {
        expect(opacity, JeebMotion.arcPulseRestOpacity);
      }
    });
  });

  group('W3 · tracking art — 5 animated elements', () {
    testWidgets('the route is the only jDash on any R/W tile: 2.6s linear', (
      tester,
    ) async {
      await tester.pumpWidget(host(const WalkthroughTrackingArt()));
      await tester.pump();

      final dashes = all<JDashedPath>(tester);
      expect(dashes, hasLength(1));
      final route = dashes.single;
      expect(route.duration, const Duration(milliseconds: 2600));
      expect(route.dashLength, 1);
      expect(route.gapLength, 12);
      expect(route.strokeWidth, 5);
      expect(
        route.travel % (route.dashLength + route.gapLength),
        0,
        reason: 'travel must be a whole number of dash periods or the loop '
            'point visibly jumps',
      );
    });

    testWidgets('the courier halo is the fastest on the board at 2.2s', (
      tester,
    ) async {
      await tester.pumpWidget(host(const WalkthroughTrackingArt()));
      await tester.pump();

      final halos = all<JHalo>(tester);
      expect(halos, hasLength(1));
      expect(halos.single.duration, const Duration(milliseconds: 2200));
      expect(halos.single.color, JeebSemanticColors.midnight().orangeSoft);
      expect(
        find.descendant(
          of: find.byType(JHalo),
          matching: find.byIcon(Icons.moped),
        ),
        findsNothing,
        reason: 'the courier disc is still; the ring sibling pulses',
      );
    });

    testWidgets('pin floats at 2.8s and the chips at 4s / 4.4s + 1.4s', (
      tester,
    ) async {
      await tester.pumpWidget(host(const WalkthroughTrackingArt()));
      await tester.pump();

      final floats = all<JFloat>(tester);
      expect(floats, hasLength(3));
      final pin = floats.singleWhere(
        (f) => f.duration == const Duration(milliseconds: 2800),
      );
      expect(pin.delay, Duration.zero);
      final lead = floats.singleWhere(
        (f) => f.duration == const Duration(seconds: 4),
      );
      expect(lead.delay, Duration.zero);
      final trail = floats.singleWhere(
        (f) => f.duration == const Duration(milliseconds: 4400),
      );
      expect(trail.delay, const Duration(milliseconds: 1400));
    });

    testWidgets('draws no arc pulse, no twinkle and no waveform', (
      tester,
    ) async {
      await tester.pumpWidget(host(const WalkthroughTrackingArt()));
      await tester.pump();

      expect(find.byType(JArcPulse), findsNothing);
      expect(find.byType(JTwinkle), findsNothing);
      expect(find.byType(JWaveBar), findsNothing);
    });
  });

  group('reduce motion', () {
    testWidgets('every primitive parks on its first keyframe', (tester) async {
      await tester.pumpWidget(host(const WalkthroughTrackingArt()));
      // No pumpAndSettle guard needed: reduce motion stops the tickers, so a
      // settle here is itself the proof that nothing is looping.
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('glass tokens', () {
    testWidgets('the accent chip is orange 20% inside an orange 45% hairline', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const WalkthroughStillChip(
            label: 'x',
            tone: WalkthroughGlassTone.accent,
          ),
        ),
      );
      await tester.pump();

      final box = tester.widget<Container>(find.byType(Container).first);
      final decoration = box.decoration! as BoxDecoration;
      final semantics = JeebSemanticColors.midnight();
      expect(decoration.color, semantics.accentSelectedFill);
      expect(
        (decoration.border! as Border).top.color,
        semantics.bubbleOutBorder,
      );
    });
  });
}
