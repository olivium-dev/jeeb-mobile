import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_radii.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_shadows.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_accent_frame_card.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../../core/widgets/jeeb/jeeb_select_chip.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../photo_attachment/domain/photo_attachment.dart';

/// One capture slot of the KYC identity step, rendered as an outlined row
/// (MIDNIGHT R23): thumb · title + sub-line · trailing affordance.
///
/// Four visual states, in strict precedence **captured > locked > active >
/// pending** (R23 caption: "the current capture step carries the orange rim +
/// glow, the done step shows a green check on calm glass, the locked selfie
/// step dims with a padlock"):
///
///  * **captured** ([photo] non-null) — the real thumbnail, a `#7BD9A4`
///    "Captured ✓" sub-line and a passive accent "Retake" text on rest glass.
///  * **locked** ([isLocked]) — the whole row at 55% with a periwinkle padlock
///    and no capture affordance. Presentation-only; the cubit path stays open
///    (JEBV4-295 / JM-040).
///  * **active** ([isActive]) — the step the user is on: `JeebAccentFrameCard`
///    with the measured orange-tint fill, a 2px accent frame and
///    `KycActiveGlowRing`, plus the solid accent capture pill.
///  * **pending** — the same row on rest glass, its capture pill on glass: the
///    orange spend belongs to the ONE live step (§2.2 budget).
///
/// The trailing affordances are deliberately **passive**: the row has exactly
/// one tap target (this widget's own `Semantics` node, which the host wraps in
/// the frozen `kyc_id_*_upload` / `kyc_selfie_upload` identifier), so nesting a
/// live button inside would create a second target and TalkBack noise.
class KycCaptureTile extends StatelessWidget {
  const KycCaptureTile({
    super.key,
    required this.label,
    required this.photo,
    required this.onTap,
    required this.isProcessing,
    this.hint,
    this.isLocked = false,
    this.isActive = false,
    this.isSelfie = false,
    this.trailingLabel,
    this.tileKey,
    this.captureCtaSemantic,
  });

  /// Card corner radius — board `border-radius: 18px` = [JeebRadii.lg].
  static const double cardRadius = JeebRadii.lg;

  /// Opacity of the locked row — R23 measures the whole row at `.55`.
  static const double lockedOpacity = 0.55;

  /// The accent frame's stroke; the board's active row measures 76 outer for a
  /// 72 content box.
  static const double activeBorderWidth = 2;

  static const double _thumbWidth = 64;
  static const double _thumbHeight = 44;
  static const double _thumbBorderWidth = 1.5;
  static const double _rowGap = 14;
  static const double _titleGap = 2;

  /// Capture-pill padding — the `8/15` inline-action metric, board-measured at
  /// 78×31 for "Capture".
  static const EdgeInsetsGeometry pillPadding =
      EdgeInsetsDirectional.symmetric(horizontal: 15, vertical: 8);

  /// Share of the row the trailing affordance may take before it has to
  /// ellipsize. Never binds at 1× text with the shipped labels; it only stops
  /// a very long label from starving the title column.
  static const double _trailingMaxWidthFactor = 0.42;

  final String label;
  final PhotoAttachment? photo;
  final VoidCallback onTap;
  final bool isProcessing;

  /// Coaching sub-line shown in the pending/active state, and the "unlocks
  /// after your ID" line in the locked state. No sub-line at all when null.
  final String? hint;

  /// Presentation-only lock (see the class doc). Ignored once [photo] exists.
  final bool isLocked;

  /// The step the user is on — the board's orange rim + glow. Ignored once
  /// [photo] exists or while [isLocked].
  final bool isActive;

  /// Selfie slot — swaps the rectangular document thumb for a Ø44 avatar disc.
  final bool isSelfie;

  /// Copy of the passive trailing affordance: the retake text when captured,
  /// the capture pill when pending. Never rendered in the locked state.
  final String? trailingLabel;

  /// Optional key for widget tests so they can target an individual tile
  /// (front, back, selfie) without depending on text content.
  final Key? tileKey;

  /// Screen-reader label for the capture/retake button surface.
  final String? captureCtaSemantic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // The wizard's own test harness pumps a bare MaterialApp, so the extension
    // is absent there — the kit's fallback idiom, never a bang.
    final semantic = theme.extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    final jeebText = context.jeebText;
    final captured = photo;
    final isCaptured = captured != null;
    // captured > locked > active: a captured photo behind a still-locked gate
    // must read as captured, or the row paints a lie.
    final isLockedState = isLocked && !isCaptured;
    final isActiveState = isActive && !isCaptured && !isLockedState;
    final isTappable = !isLockedState && !isProcessing;

    final subLine = _subLine(context, semantic, jeebText, isCaptured);
    final trailing = _trailing(
      context,
      semantic,
      jeebText,
      isCaptured,
      isLockedState,
      isActiveState,
    );
    // The trailing affordance is laid out at its natural width, which is what
    // the board draws — but it is CAPPED, because an unbounded one would eat
    // the row at 200% text or with a long Arabic label and crush the title
    // into a one-glyph-per-line column.
    final row = LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          _thumb(context, colorScheme, semantic, captured),
          const SizedBox(width: _rowGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: jeebText.cardTitle.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                ?subLine,
              ],
            ),
          ),
          if (trailing != null)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth * _trailingMaxWidthFactor,
              ),
              // scaleDown, not a hard clip: the kit pill is a shrink-wrapped
              // Row that would overflow if squeezed. Below the cap it renders
              // at 1.0 — pixel-identical to the board.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerEnd,
                child: trailing,
              ),
            ),
        ],
      ),
    );

    // A locked row has no InkWell of its own, so without an opaque layer taps
    // would fall straight through the card to the scroll view and the row
    // would not even be a hit target for a11y focus. It absorbs its own taps
    // and does nothing with them — which is what "locked" means.
    final body = isLockedState
        ? GestureDetector(behavior: HitTestBehavior.opaque, child: row)
        : row;

    Widget card = isActiveState
        ? Stack(
            // The glow stands proud of the card on all four sides.
            clipBehavior: Clip.none,
            children: [
              const Positioned.fill(
                child: KycActiveGlowRing(radius: cardRadius),
              ),
              JeebAccentFrameCard(
                radius: cardRadius,
                borderWidth: activeBorderWidth,
                fill: JeebAccentFrameFill.accentTint,
                onTap: isTappable ? onTap : null,
                child: body,
              ),
            ],
          )
        : JeebOutlinedCard(
            radius: cardRadius,
            onTap: isTappable ? onTap : null,
            child: body,
          );
    if (isLockedState) {
      // The board dims the whole row div, outline included — so the fade sits
      // OUTSIDE the card, not around its child.
      card = Opacity(opacity: lockedOpacity, child: card);
    }

    return Semantics(
      key: tileKey,
      button: true,
      enabled: isTappable,
      label: captureCtaSemantic ?? label,
      child: card,
    );
  }

  Widget? _subLine(
    BuildContext context,
    JeebSemanticColors semantic,
    JeebTextStyles jeebText,
    bool isCaptured,
  ) {
    if (isCaptured) {
      // R23 measures `#7BD9A4` (onSuccessContainer), not the `#3BB273` solid —
      // the soft rung is the one that clears AA on navy.
      final success = context.jeebRoles.onSuccessContainer;
      // TODO(midnight): the board's "looks sharp ✓" verdict needs a
      // capture-quality signal PhotoAttachment does not carry — omitted here
      // rather than faked.
      return Padding(
        padding: const EdgeInsetsDirectional.only(top: _titleGap),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Text before icon in one Row: reading order survives mirroring.
            Text(
              AppLocalizations.of(context).kycCaptureCaptured,
              style: jeebText.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: success,
              ),
            ),
            const SizedBox(width: Spacing.twoXSmall),
            Icon(Icons.check_rounded, size: Sizes.medium, color: success),
          ],
        ),
      );
    }
    final line = hint;
    if (line == null) return null;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: _titleGap),
      child: Text(
        line,
        // The live coaching line measures `inkSoft`; only the dimmed locked row
        // drops to `mutedText`.
        style: jeebText.bodySmall.copyWith(
          fontWeight: FontWeight.w500,
          color: isLocked ? semantic.mutedText : semantic.inkSoft,
        ),
      ),
    );
  }

  Widget? _trailing(
    BuildContext context,
    JeebSemanticColors semantic,
    JeebTextStyles jeebText,
    bool isCaptured,
    bool isLockedState,
    bool isActiveState,
  ) {
    if (isProcessing) {
      // Row-trailing wait: §2.7 has no sub-compact form and the kit is frozen,
      // so this is the sanctioned inline mark — muted ink, never `primary`.
      return Padding(
        padding: const EdgeInsetsDirectional.only(start: Spacing.small),
        child: SizedBox(
          width: Sizes.large,
          height: Sizes.large,
          child: CircularProgressIndicator(
            strokeWidth: UIConstants.strokeWidthNormal,
            color: semantic.mutedText,
          ),
        ),
      );
    }
    if (isLockedState) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(start: Spacing.small),
        child: Icon(
          Icons.lock_rounded,
          size: Sizes.medium,
          color: semantic.mutedText,
        ),
      );
    }
    final text = trailingLabel;
    if (text == null) return null;
    if (isCaptured) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(start: Spacing.small),
        child: Text(
          text,
          style: jeebText.bodySmall.copyWith(
            fontWeight: FontWeight.w700,
            color: context.jeebRoles.accent,
          ),
        ),
      );
    }
    // Orange budget: the solid accent pill belongs to the ONE live step. A row
    // that is merely un-captured keeps the same geometry on rest glass.
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: Spacing.small),
      child: isActiveState
          ? _CapturePill(label: text)
          : JeebSelectChip(role: JeebChipRole.inlineAction, label: text),
    );
  }

  Widget _thumb(
    BuildContext context,
    ColorScheme colorScheme,
    JeebSemanticColors semantic,
    PhotoAttachment? captured,
  ) {
    if (captured != null) {
      return SizedBox(
        width: _thumbWidth,
        height: _thumbHeight,
        child: ClipRRect(
          borderRadius: OmdsBorderRadius.xSmall,
          child: Image.memory(
            captured.bytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            // Stub / test payloads aren't real JPEGs; fall back to the board's
            // white-14% ID slab instead of crashing the build. In production
            // the bytes are valid JPEG from the platform camera.
            errorBuilder: (_, _, _) => Container(
              decoration: BoxDecoration(
                color: semantic.glassFillPressed,
                borderRadius: OmdsBorderRadius.xSmall,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.badge_rounded,
                size: Sizes.large,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ),
      );
    }
    if (isSelfie) {
      return Container(
        width: _thumbHeight,
        height: _thumbHeight,
        decoration: BoxDecoration(
          color: semantic.glassFillEmphasis,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.person_rounded,
          size: Sizes.large,
          color: semantic.mutedText,
        ),
      );
    }
    // The board's drop zone has NO fill — the dashed stroke carries the shape.
    return SizedBox(
      width: _thumbWidth,
      height: _thumbHeight,
      child: CustomPaint(
        painter: KycDashedBorderPainter(
          color: semantic.glassBorderVivid,
          radius: Spacing.xSmall,
          strokeWidth: _thumbBorderWidth,
        ),
        child: Align(
          child: Icon(
            Icons.photo_camera_rounded,
            size: Sizes.large,
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// The live row's halo, drawn OUTSIDE the card only.
///
/// A plain `boxShadow` behind a translucent card paints under it too and
/// double-tints the fill (measured orange 27.7% where the board draws 10.0%);
/// CSS clips an outer `box-shadow` to the outside of the border box, and
/// `ClipPath` cannot help because its clip layer is bounded by the widget.
class KycActiveGlowRing extends StatelessWidget {
  const KycActiveGlowRing({
    super.key,
    required this.radius,
    this.shadows = JeebShadows.glowRest,
  });

  final double radius;
  final List<BoxShadow> shadows;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _GlowRingPainter(radius, shadows));
}

class _GlowRingPainter extends CustomPainter {
  const _GlowRingPainter(this.radius, this.shadows);

  /// Reach of the widest glow in [JeebShadows] — the cut-out must not crop it.
  static const double _reach = 60;

  final double radius;
  final List<BoxShadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas.save();
    canvas.clipPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(rrect.outerRect.inflate(_reach)),
        Path()..addRRect(rrect),
      ),
    );
    for (final shadow in shadows) {
      canvas.drawRRect(
        rrect.shift(shadow.offset).inflate(shadow.spreadRadius),
        shadow.toPaint(),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlowRingPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.shadows != shadows;
}

/// The board's capture affordance: a solid accent pill with `onAccent` copy and
/// the small orange lift. Visual only — the row is the single tap target, so it
/// carries no gesture and no identifier.
class _CapturePill extends StatelessWidget {
  const _CapturePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final roles = context.jeebRoles;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: roles.accent,
        borderRadius: BorderRadius.circular(JeebRadii.pill),
        boxShadow: JeebShadows.ctaOrangeSmall,
      ),
      child: Padding(
        padding: KycCaptureTile.pillPadding,
        child: Text(
          label,
          style: context.jeebText.bodySmall.copyWith(
            fontWeight: FontWeight.w700,
            color: roles.onAccent,
          ),
        ),
      ),
    );
  }
}

/// Dashed rounded-rectangle stroke for the pending capture thumb
/// (board `1.5px dashed`, measured white ~21% = `glassBorderVivid`). Sanctioned
/// bespoke — the kit ships no dashed border and Flutter's `Border` cannot draw
/// one.
class KycDashedBorderPainter extends CustomPainter {
  const KycDashedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    this.dashLength = 4,
    this.gapLength = 3,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    // Inset by half the stroke so the dash sits inside the box (border-box).
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      math.max(size.width - strokeWidth, 0),
      math.max(size.height - strokeWidth, 0),
    );
    final outline = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;
    for (final metric in outline.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(KycDashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dashLength != dashLength ||
      oldDelegate.gapLength != gapLength;
}
