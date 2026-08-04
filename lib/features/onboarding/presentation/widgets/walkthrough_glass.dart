import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/motion/jeeb_motion_primitives.dart';
import '../../../../core/theme/jeeb_radii.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';

/// Tones the walkthrough art draws its floating surfaces in.
enum WalkthroughGlassTone {
  /// Board `rgba(255,255,255,.1)` + `1px rgba(255,255,255,.18)` — the voice
  /// bubble, the offer bubble, the trust chips, W3's ETA chip.
  glass,

  /// Board `rgba(215,59,0,.2)` + `1px rgba(215,59,0,.45)` — W2's handoff-code
  /// chip and W3's cash chip. The only tinted surfaces on these four tiles.
  accent,
}

/// The float periods every walkthrough tile pairs its floating art on.
/// 03-MOTION-NOTES: 4s on the first element, 4.4s on the second, and a delay on
/// the second that is what de-syncs the pair — never drop it.
abstract final class WalkthroughFloat {
  /// R5/W1 bubble A · W2 chip A · W3 chip A.
  static const Duration lead = Duration(seconds: 4);

  /// R5/W1 bubble B · W2 chip B · W3 chip B.
  static const Duration trail = Duration(milliseconds: 4400);

  /// R5/W1's second glass bubble.
  static const Duration bubbleDelay = Duration(milliseconds: 1200);

  /// W2's second trust chip.
  static const Duration trustChipDelay = Duration(milliseconds: 1300);

  /// W3's second map chip.
  static const Duration mapChipDelay = Duration(milliseconds: 1400);
}

/// Pre-baked translucency, never a real `BackdropFilter`: §4 budgets the screen
/// to ≤2 and the docked sheet spends the only one these tiles earn.
({Color fill, Color border}) walkthroughGlassInk(
  BuildContext context,
  WalkthroughGlassTone tone,
) {
  final JeebSemanticColors semantics =
      Theme.of(context).extension<JeebSemanticColors>() ??
      JeebSemanticColors.midnight();
  return switch (tone) {
    WalkthroughGlassTone.glass => (
      fill: semantics.glassFillEmphasis,
      border: semantics.glassBorderStrong,
    ),
    WalkthroughGlassTone.accent => (
      fill: semantics.accentSelectedFill,
      border: semantics.bubbleOutBorder,
    ),
  };
}

/// A chat-style bubble on the field: glass, with the tail on one corner.
///
/// R5/W1 draw the pair with mirrored tails — `16 16 16 4` on the start-anchored
/// voice note, `16 16 4 16` on the end-anchored offer.
class WalkthroughGlassBubble extends StatelessWidget {
  const WalkthroughGlassBubble({
    super.key,
    required this.child,
    required this.tailAtStart,
    this.maxWidth,
  });

  /// Board padding `10px 14px`.
  static const EdgeInsetsGeometry bubblePadding =
      EdgeInsetsDirectional.symmetric(
        horizontal: 14,
        vertical: 10,
      );

  /// Board `border-radius: 16px` on the three full corners.
  static const double corner = 16;

  /// The clipped tail corner (board `4px`).
  static const double tailCorner = 4;

  final Widget child;

  /// True puts the tail on the bottom-START corner (the voice note).
  final bool tailAtStart;

  /// R5/W1's voice bubble caps at 200; the offer bubble is intrinsic.
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final ({Color fill, Color border}) ink = walkthroughGlassInk(
      context,
      WalkthroughGlassTone.glass,
    );
    const Radius full = Radius.circular(corner);
    const Radius tail = Radius.circular(tailCorner);
    final Widget bubble = Container(
      constraints: maxWidth == null
          ? null
          : BoxConstraints(maxWidth: maxWidth!),
      padding: bubblePadding,
      decoration: BoxDecoration(
        color: ink.fill,
        border: Border.all(color: ink.border),
        borderRadius: BorderRadiusDirectional.only(
          topStart: full,
          topEnd: full,
          bottomStart: tailAtStart ? tail : full,
          bottomEnd: tailAtStart ? full : tail,
        ),
      ),
      child: child,
    );
    return bubble;
  }
}

/// One floating pill on the walkthrough art — W2's trust chips and W3's map
/// chips, both tones.
///
/// The chip owns its own `jFloat`; callers pass the tile's exact period and
/// delay, because the ladder IS the design.
class WalkthroughFloatChip extends StatelessWidget {
  const WalkthroughFloatChip({
    super.key,
    required this.label,
    required this.tone,
    required this.duration,
    this.delay = Duration.zero,
    this.leading,
  });

  /// Board padding: `8px 13px` on W2, `9px 15px` on W3 — one token pair for
  /// both, since `Spacing` has no 13/15.
  static const EdgeInsetsGeometry chipPadding = EdgeInsetsDirectional.symmetric(
    horizontal: Spacing.medium,
    vertical: Spacing.xSmall,
  );

  final String label;
  final WalkthroughGlassTone tone;
  final Duration duration;
  final Duration delay;

  /// The `🛡` mark W2's ID chip carries, drawn rather than baked into the run.
  final IconData? leading;

  @override
  Widget build(BuildContext context) {
    return JFloat(
      duration: duration,
      delay: delay,
      child: WalkthroughStillChip(label: label, tone: tone, leading: leading),
    );
  }
}

/// The chip body without any motion — W2's accent chip breathes instead of
/// floating, so the paint has to be separable from the primitive.
class WalkthroughStillChip extends StatelessWidget {
  const WalkthroughStillChip({
    super.key,
    required this.label,
    required this.tone,
    this.leading,
  });

  /// Board `12–12.5px / w700 / #fff`.
  static const double leadingGlyphSize = 13;

  final String label;
  final WalkthroughGlassTone tone;
  final IconData? leading;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final ({Color fill, Color border}) ink = walkthroughGlassInk(context, tone);
    final TextStyle style = context.jeebText.bodySmall.copyWith(
      fontWeight: FontWeight.w700,
      color: scheme.onSurface,
    );
    return Container(
      padding: WalkthroughFloatChip.chipPadding,
      decoration: BoxDecoration(
        color: ink.fill,
        border: Border.all(color: ink.border),
        borderRadius: BorderRadius.circular(JeebRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (leading != null) ...<Widget>[
            Icon(leading, size: leadingGlyphSize, color: scheme.onSurface),
            const SizedBox(width: Spacing.twoXSmall),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}
