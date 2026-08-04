import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/motion/jeeb_motion_primitives.dart';
import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_radii.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_shadows.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_avatar.dart';
import '../../../../l10n/app_localizations.dart';
import 'walkthrough_glass.dart';

/// W2's stage art: a Jeeber identity card with the trust mechanics floating
/// around it.
///
/// Motion (03-MOTION-NOTES W2, 6 animated elements): two orbit rings on
/// `jArcPulse` 3.2s with a **.6s offset between them** — that offset is the
/// whole effect; the verified badge on `jTwinkle` 2.6s (a UI badge, not a star);
/// the two trust chips on the 4s / 4.4s + 1.3s float ladder; and the orange
/// handoff chip BREATHING at 2.8s rather than floating. The card itself, the
/// avatar, the rating star and every run of copy are still.
class WalkthroughTrustArt extends StatelessWidget {
  const WalkthroughTrustArt({super.key});

  /// Board `jArcPulse 3.2s` on both rings; only the outer one carries a delay.
  static const Duration ringDuration = Duration(milliseconds: 3200);
  static const Duration outerRingDelay = Duration(milliseconds: 600);

  /// Board `jTwinkle 2.6s` on the verified badge.
  static const Duration badgeDuration = Duration(milliseconds: 2600);

  /// Board `jBreathe 2.8s` on the accent chip.
  static const Duration accentChipDuration = Duration(milliseconds: 2800);

  /// Ring geometry, board `Ø370` / `Ø250` centred at `top:290` of the 631dp
  /// stage; strokes `rgba(255,255,255,.07)` and `.12`.
  static const double ringCentreFraction = 0.460;
  static const double outerRingRadius = 185;
  static const double innerRingRadius = 125;

  /// Card centre `top:250`; chips `top:96` / `top:128`; accent chip `top:392`.
  static const double cardCentreFraction = 0.396;
  static const double idChipTopFraction = 0.152;
  static const double ratedChipTopFraction = 0.203;
  static const double codeChipTopFraction = 0.621;

  /// Board `left:22` / `right:20` on the two trust chips.
  static const double idChipStartInset = 22;
  static const double ratedChipEndInset = 20;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final JeebSemanticColors semantics =
        Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double stage = constraints.maxHeight;
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            // The .6s offset between the two rings IS the effect — the outer
            // ring swells behind the inner one.
            Positioned.fill(
              child: JArcPulse(
                duration: ringDuration,
                delay: outerRingDelay,
                child: _OrbitRing(
                  colour: semantics.glassFill,
                  radius: outerRingRadius,
                  centreFraction: ringCentreFraction,
                ),
              ),
            ),
            Positioned.fill(
              child: JArcPulse(
                duration: ringDuration,
                child: _OrbitRing(
                  colour: semantics.glassBorder,
                  radius: innerRingRadius,
                  centreFraction: ringCentreFraction,
                ),
              ),
            ),
            Positioned(
              top: stage * cardCentreFraction,
              left: 0,
              right: 0,
              child: const FractionalTranslation(
                translation: Offset(0, -0.5),
                child: Center(child: _JeeberIdentityCard()),
              ),
            ),
            PositionedDirectional(
              start: idChipStartInset,
              top: stage * idChipTopFraction,
              child: WalkthroughFloatChip(
                label: l10n.walkthroughTrustIdChip,
                tone: WalkthroughGlassTone.glass,
                duration: WalkthroughFloat.lead,
                leading: Icons.shield_outlined,
              ),
            ),
            PositionedDirectional(
              end: ratedChipEndInset,
              top: stage * ratedChipTopFraction,
              child: WalkthroughFloatChip(
                label: l10n.walkthroughTrustRatedChip,
                tone: WalkthroughGlassTone.glass,
                duration: WalkthroughFloat.trail,
                delay: WalkthroughFloat.trustChipDelay,
              ),
            ),
            Positioned(
              top: stage * codeChipTopFraction,
              left: 0,
              right: 0,
              child: Center(
                child: JBreathe(
                  duration: accentChipDuration,
                  child: WalkthroughStillChip(
                    label: l10n.walkthroughTrustCodeChip,
                    tone: WalkthroughGlassTone.accent,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One concentric orbit ring. Painted rather than positioned so a ring wider
/// than the device cannot throw a layout overflow.
class _OrbitRing extends StatelessWidget {
  const _OrbitRing({
    required this.colour,
    required this.radius,
    required this.centreFraction,
  });

  final Color colour;
  final double radius;
  final double centreFraction;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _OrbitRingPainter(
      colour: colour,
      radius: radius,
      centreFraction: centreFraction,
    ),
  );
}

class _OrbitRingPainter extends CustomPainter {
  const _OrbitRingPainter({
    required this.colour,
    required this.radius,
    required this.centreFraction,
  });

  final Color colour;
  final double radius;
  final double centreFraction;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(size.width / 2, size.height * centreFraction),
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = UIConstants.dividerWidth
        ..color = colour,
    );
  }

  @override
  bool shouldRepaint(_OrbitRingPainter oldDelegate) =>
      oldDelegate.colour != colour ||
      oldDelegate.radius != radius ||
      oldDelegate.centreFraction != centreFraction;
}

/// The identity card: avatar + name, then the three trust facts.
///
/// Decorative sample data — nothing here is wired to a real Jeeber, and the
/// whole subtree is excluded from semantics by the slide's own label.
class _JeeberIdentityCard extends StatelessWidget {
  const _JeeberIdentityCard();

  /// Board `width:270`, `padding:20`, `border-radius:24` (ties between the
  /// ladder's `xl` 22 and `sheet` 26 — the lower rung wins, §5 ±2 tolerance).
  static const double cardWidth = 270;

  /// Board Ø58 avatar with a white initial on white-16% glass.
  static const double avatarDiameter = 58;

  /// Board `gap:14` between the three stat columns.
  static const double statGap = 14;

  /// Board Ø22 badge, `3px solid #10175E`, 11px white check.
  static const double badgeDiameter = 22;
  static const double badgeRing = 3;
  static const double badgeGlyph = 11;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final JeebSemanticColors semantics =
        Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    return SizedBox(
      width: cardWidth,
      child: Container(
        padding: const EdgeInsets.all(Spacing.large),
        decoration: BoxDecoration(
          color: semantics.glassFillEmphasis,
          border: Border.all(color: semantics.glassBorderVivid),
          borderRadius: BorderRadius.circular(JeebRadii.xl),
          boxShadow: JeebShadows.floatNav,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _IdentityHeadRow(),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: Spacing.small,
              ),
              child: Divider(
                height: UIConstants.dividerWidth,
                thickness: UIConstants.dividerWidth,
                color: semantics.glassBorder,
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: statGap,
              children: <Widget>[
                Flexible(
                  child: _TrustStat(
                    value: l10n.walkthroughTrustRatingValue,
                    valueInk: semantics.amber,
                    label: l10n.walkthroughTrustRatingsLabel,
                  ),
                ),
                Flexible(
                  child: _TrustStat(
                    value: l10n.walkthroughTrustDeliveriesValue,
                    valueInk: scheme.onSurface,
                    label: l10n.walkthroughTrustDeliveriesLabel,
                  ),
                ),
                Flexible(
                  child: _TrustStat(
                    value: l10n.walkthroughTrustIdCheckValue,
                    valueInk: context.jeebRoles.onSuccessContainer,
                    label: l10n.deliveryManProfileVerifiedBadgeLabel,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar + name. The verified badge is a SIBLING of the disc so `jTwinkle` can
/// ride it alone — the avatar underneath does not move.
class _IdentityHeadRow extends StatelessWidget {
  const _IdentityHeadRow();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      spacing: Spacing.small,
      children: <Widget>[
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            JeebAvatar(
              initial: l10n.walkthroughTrustName,
              diameter: _JeeberIdentityCard.avatarDiameter,
              fill: JeebAvatarFill.glass,
            ),
            const PositionedDirectional(
              end: -_JeeberIdentityCard.badgeRing,
              bottom: -_JeeberIdentityCard.badgeRing,
              child: _VerifiedBadge(),
            ),
          ],
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.walkthroughTrustName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.jeebText.titleProminent.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              Text(
                l10n.walkthroughTrustRoleLine,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.jeebText.bodySmall.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The `jTwinkle` corner badge — 03-MOTION-NOTES' one instance of the primitive
/// on a UI badge rather than a star.
class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final JeebRoles roles = context.jeebRoles;
    return JTwinkle(
      duration: WalkthroughTrustArt.badgeDuration,
      child: Container(
        width: _JeeberIdentityCard.badgeDiameter,
        height: _JeeberIdentityCard.badgeDiameter,
        decoration: BoxDecoration(
          color: roles.accent,
          shape: BoxShape.circle,
          border: Border.all(
            color: scheme.surfaceContainerHigh,
            width: _JeeberIdentityCard.badgeRing,
          ),
        ),
        child: Icon(
          Icons.check,
          size: _JeeberIdentityCard.badgeGlyph,
          color: roles.onAccent,
        ),
      ),
    );
  }
}

/// One of the card's three facts: an emphatic value over a muted label.
class _TrustStat extends StatelessWidget {
  const _TrustStat({
    required this.value,
    required this.valueInk,
    required this.label,
  });

  final String value;
  final Color valueInk;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          maxLines: 1,
          style: context.jeebText.cardTitle.copyWith(
            fontWeight: FontWeight.w800,
            color: valueInk,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.jeebText.label.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
