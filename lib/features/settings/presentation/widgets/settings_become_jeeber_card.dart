import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_radii.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_accent_frame_card.dart';
import '../../../../l10n/app_localizations.dart';

/// The orange-framed growth card (MIDNIGHT R22 `tpl 1362`).
///
/// The tile's caption calls it "the page's one lit frame": 2px accent stroke,
/// an `accentTint` fill and a `0 0 24px` orange bloom around the frame. No role
/// gate — today's screen offers this to everyone and the board keeps it.
class SettingsBecomeJeeberCard extends StatelessWidget {
  const SettingsBecomeJeeberCard({super.key});

  /// Ø38 accent disc + 19px glyph (board `tpl 1363`).
  static const double discDiameter = 38;
  static const double discGlyphSize = 19;

  /// Gap between disc, text block and the CTA word (board `gap:12`).
  static const double gap = 12;

  /// `0 0 24px rgba(215,59,0,.18)` — the frame's bloom (board `tpl 1362`).
  static const double glowBlur = 24;
  static const double glowAlpha = 0.18;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final roles = context.jeebRoles;
    final semantics = Theme.of(context).extension<JeebSemanticColors>()!;

    return _FrameGlow(
      radius: JeebRadii.lg,
      color: roles.accent.withValues(alpha: glowAlpha),
      blur: glowBlur,
      child: JeebAccentFrameCard(
        key: const Key('settings-row-become-jeeber'),
        identifier: 'settings-row-become-jeeber',
        fill: JeebAccentFrameFill.accentTint,
        onTap: () => context.pushNamed('kyc-status'),
        child: Row(
          children: [
            Container(
              width: discDiameter,
              height: discDiameter,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: roles.accent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delivery_dining,
                size: discGlyphSize,
                color: roles.onAccent,
              ),
            ),
            const SizedBox(width: gap),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.becomeJeeberCardTitle,
                    style: context.jeebText.body.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    l10n.settingsBecomeJeeberSubtitle,
                    style: context.jeebText.bodySmall.copyWith(
                      fontWeight: FontWeight.w500,
                      color: semantics.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: gap),
            Text(
              l10n.settingsBecomeJeeberCta,
              style: context.jeebText.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
                color: roles.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A CSS-shaped outset glow: blurred rounded rect, clipped away from the card's
/// own footprint so a translucent fill is not tinted by its own halo.
class _FrameGlow extends StatelessWidget {
  const _FrameGlow({
    required this.child,
    required this.radius,
    required this.color,
    required this.blur,
  });

  final Widget child;
  final double radius;
  final Color color;
  final double blur;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FrameGlowPainter(radius: radius, color: color, blur: blur),
      child: child,
    );
  }
}

class _FrameGlowPainter extends CustomPainter {
  const _FrameGlowPainter({
    required this.radius,
    required this.color,
    required this.blur,
  });

  final double radius;
  final Color color;
  final double blur;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final Rect bounds = Offset.zero & size;
    final RRect frame = RRect.fromRectAndRadius(
      bounds,
      Radius.circular(radius),
    );
    // Even-odd: the halo is everything the frame does NOT cover, so a
    // translucent card is never tinted by its own bloom (CSS outset clipping).
    final Path outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(bounds.inflate(blur * 2))
      ..addRRect(frame);
    canvas
      ..save()
      ..clipPath(outside)
      ..drawRRect(
        frame,
        Paint()
          ..color = color
          // CSS blur-radius is 2σ; the bloom reads twice as wide otherwise.
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur / 2),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_FrameGlowPainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.color != color ||
      oldDelegate.blur != blur;
}
