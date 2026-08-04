import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/motion/jeeb_motion.dart';
import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_radii.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_mic_hero.dart';
import '../../../../l10n/app_localizations.dart';
import 'walkthrough_glass.dart';

/// The two placements the board draws this one composition in — R5 (the
/// onboarding tile) and W1 (the walkthrough tile). 03-MOTION-NOTES: "structurally
/// identical (same art, shifted positions). Ship one widget, two placements."
///
/// Vertical values are fractions of the stage band, so the art scales on a short
/// device instead of colliding with the mic; horizontal insets are the board's
/// own dp, which every phone width can honour.
enum WalkthroughVoicePlacement {
  /// Board R5: bubbles at `left:24/top:56` and `right:22/top:170`, mic Ø124 at
  /// `top:310` of the 631dp stage, rings Ø380/Ø260.
  r5(
    voiceStartInset: 24,
    voiceTopFraction: 0.089,
    offerEndInset: 22,
    offerTopFraction: 0.269,
    micCentreFraction: 0.491,
    micSize: 124,
    haloRingDiameter: 132,
    outerRingRadius: 190,
    innerRingRadius: 130,
  ),

  /// Board W1: `left:26/top:60`, `right:24/top:150`, mic Ø120 at `top:300`,
  /// rings Ø370/Ø250.
  w1(
    voiceStartInset: 26,
    voiceTopFraction: 0.095,
    offerEndInset: 24,
    offerTopFraction: 0.238,
    micCentreFraction: 0.475,
    micSize: 120,
    haloRingDiameter: 128,
    outerRingRadius: 185,
    innerRingRadius: 125,
  );

  const WalkthroughVoicePlacement({
    required this.voiceStartInset,
    required this.voiceTopFraction,
    required this.offerEndInset,
    required this.offerTopFraction,
    required this.micCentreFraction,
    required this.micSize,
    required this.haloRingDiameter,
    required this.outerRingRadius,
    required this.innerRingRadius,
  });

  final double voiceStartInset;
  final double voiceTopFraction;
  final double offerEndInset;
  final double offerTopFraction;
  final double micCentreFraction;
  final double micSize;
  final double haloRingDiameter;
  final double outerRingRadius;
  final double innerRingRadius;
}

/// R5 / W1's stage art: two glass bubbles floating around a lit mic.
///
/// Motion (03-MOTION-NOTES R5 + W1, 4 animated elements — everything else is
/// still): the voice bubble floats on `jFloat` 4s, the offer bubble on 4.4s with
/// a **1.2s delay** (the delay is what de-syncs the pair), the mini waveform
/// scales as ONE row on `jWave` 1.3s, and a `jHalo` 2.6s ring pulses as a
/// SIBLING of the mic disc. The disc itself, the bubble contents and the two
/// accent rings do not move.
class WalkthroughVoiceArt extends StatelessWidget {
  const WalkthroughVoiceArt({
    super.key,
    this.placement = WalkthroughVoicePlacement.w1,
  });

  /// Board `jHalo 2.6s ease-out` on both tiles.
  static const Duration haloDuration = Duration(milliseconds: 2600);

  /// Board `jWave 1.3s` on the waveform CONTAINER — the 3 bars are static
  /// children with no stagger (03-MOTION-NOTES rule 1).
  static const Duration waveDuration = Duration(milliseconds: 1300);

  /// Measured `2px solid #FFB27A`.
  static const double haloStroke = 2;

  /// Board `1px rgba(215,59,0,.14)` / `rgba(215,59,0,.24)` — the two static
  /// accent rings behind the mic.
  static const double outerRingAlpha = 0.14;
  static const double innerRingAlpha = 0.24;

  final WalkthroughVoicePlacement placement;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double stage = constraints.maxHeight;
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: CustomPaint(
                painter: _AccentRingsPainter(
                  color: context.jeebRoles.accent,
                  centreFraction: placement.micCentreFraction,
                  outerRadius: placement.outerRingRadius,
                  innerRadius: placement.innerRingRadius,
                ),
              ),
            ),
            PositionedDirectional(
              start: placement.voiceStartInset,
              top: stage * placement.voiceTopFraction,
              child: const JFloat(
                duration: WalkthroughFloat.lead,
                child: _VoiceNoteBubble(),
              ),
            ),
            PositionedDirectional(
              end: placement.offerEndInset,
              top: stage * placement.offerTopFraction,
              child: JFloat(
                duration: WalkthroughFloat.trail,
                delay: WalkthroughFloat.bubbleDelay,
                child: _OfferBubble(placement: placement),
              ),
            ),
            Positioned(
              top: stage * placement.micCentreFraction,
              left: 0,
              right: 0,
              child: FractionalTranslation(
                translation: const Offset(0, -0.5),
                child: Center(child: _MicWithHalo(placement: placement)),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The lit mic. `jHalo` rides a ring SIBLING, never the disc — cheat-sheet
/// rule 2. The primitive's .75 rest scale is what lands the ring on the board's
/// hairline, so the box is the ring diameter divided by that scale.
class _MicWithHalo extends StatelessWidget {
  const _MicWithHalo({required this.placement});

  final WalkthroughVoicePlacement placement;

  @override
  Widget build(BuildContext context) {
    final JeebSemanticColors semantics =
        Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    final double haloBox =
        placement.haloRingDiameter / JeebMotion.haloStartScale;
    return SizedBox.square(
      dimension: haloBox,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          JHalo(
            color: semantics.orangeSoft,
            strokeWidth: WalkthroughVoiceArt.haloStroke,
            duration: WalkthroughVoiceArt.haloDuration,
            child: SizedBox.square(dimension: haloBox),
          ),
          JeebMicHero.decorative(
            size: placement.micSize,
            halo: false,
            glow: JeebMicGlow.hero,
          ),
        ],
      ),
    );
  }
}

/// Bubble A — the recorded ask, transcribed in Lebanese Arabic.
class _VoiceNoteBubble extends StatelessWidget {
  const _VoiceNoteBubble();

  /// Board `max-width: 200px`.
  static const double maxWidth = 200;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return WalkthroughGlassBubble(
      tailAtStart: true,
      maxWidth: maxWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const _MiniWaveform(),
              const SizedBox(width: Spacing.xSmall),
              Text(
                l10n.onboardingPreviewVoiceDuration,
                // The one standalone digit-leading run here: without an explicit
                // direction `0:04` reorders under RTL.
                textDirection: TextDirection.ltr,
                style: context.jeebText.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.twoXSmall),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              l10n.onboardingPreviewVoiceTranscript,
              style: context.jeebText.body.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three static accent bars whose ROW scales as one — `jWave` is applied to the
/// container, never per bar (03-MOTION-NOTES rule 1; there is no per-bar stagger
/// anywhere on the board).
class _MiniWaveform extends StatelessWidget {
  const _MiniWaveform();

  /// Board: `height:14` container, bars `w3` at `h 7/13/9`, `gap:2`, `r9`.
  static const double containerHeight = 14;
  static const double barWidth = 3;
  static const double barGap = 2;
  static const List<double> barHeights = <double>[7, 13, 9];

  @override
  Widget build(BuildContext context) {
    final Color accent = context.jeebRoles.accent;
    return SizedBox(
      height: containerHeight,
      child: JWaveBar(
        duration: WalkthroughVoiceArt.waveDuration,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: barGap,
          children: <Widget>[
            for (final double height in barHeights)
              Container(
                width: barWidth,
                height: height,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(JeebRadii.sm),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bubble B — the marketplace reply. R5 quotes a price; W1 names the errand and
/// carries the Flash chip. Same surface, same motion, different run.
class _OfferBubble extends StatelessWidget {
  const _OfferBubble({required this.placement});

  final WalkthroughVoicePlacement placement;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextStyle title = context.jeebText.bodySmall.copyWith(
      fontWeight: FontWeight.w600,
      color: scheme.onSurface,
    );
    return WalkthroughGlassBubble(
      tailAtStart: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: switch (placement) {
          WalkthroughVoicePlacement.r5 => <Widget>[
            Text(l10n.onboardingPreviewOfferQuoteShort, style: title),
            const SizedBox(height: Sizes.threeXSmall),
            Text(
              // The ★ inherits this ink on purpose — a rating star is never
              // tinted amber inside these bubbles.
              l10n.onboardingPreviewOfferMeta,
              style: context.jeebText.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          WalkthroughVoicePlacement.w1 => <Widget>[
            Text(l10n.onboardingPreviewRequestTitle, style: title),
            const SizedBox(height: Spacing.twoXSmall),
            const _FlashChip(),
          ],
        },
      ),
    );
  }
}

/// W1's `⚡ Flash` pill: white 12% on the bubble's own glass, not the navy tier
/// chip — the board draws it translucent inside a translucent surface.
class _FlashChip extends StatelessWidget {
  const _FlashChip();

  /// Board `padding:3px 9px`.
  static const EdgeInsetsGeometry padding = EdgeInsetsDirectional.symmetric(
    horizontal: 9,
    vertical: 3,
  );

  static const double glyphSize = 11;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final JeebSemanticColors semantics =
        Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: semantics.glassFillPressed,
        borderRadius: BorderRadius.circular(JeebRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.bolt, size: glyphSize, color: scheme.onSurface),
          const SizedBox(width: Sizes.threeXSmall),
          Text(
            l10n.tierFlashTitle,
            style: context.jeebText.label.copyWith(color: scheme.onSurface),
          ),
        ],
      ),
    );
  }
}

/// The two faint accent rings behind the mic.
///
/// A painter rather than positioned circles: a Ø380 box inside a narrower stage
/// would need `UnconstrainedBox`, which throws debug overflow in widget tests.
/// STILL on both tiles — R5/W1 animate four elements and these are not among
/// them (W2 is where the rings pulse).
class _AccentRingsPainter extends CustomPainter {
  const _AccentRingsPainter({
    required this.color,
    required this.centreFraction,
    required this.outerRadius,
    required this.innerRadius,
  });

  final Color color;
  final double centreFraction;
  final double outerRadius;
  final double innerRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = Offset(size.width / 2, size.height * centreFraction);
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = UIConstants.dividerWidth;
    canvas.drawCircle(
      centre,
      outerRadius,
      stroke
        ..color = color.withValues(alpha: WalkthroughVoiceArt.outerRingAlpha),
    );
    canvas.drawCircle(
      centre,
      innerRadius,
      stroke
        ..color = color.withValues(alpha: WalkthroughVoiceArt.innerRingAlpha),
    );
  }

  @override
  bool shouldRepaint(_AccentRingsPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.centreFraction != centreFraction ||
      oldDelegate.outerRadius != outerRadius ||
      oldDelegate.innerRadius != innerRadius;
}
