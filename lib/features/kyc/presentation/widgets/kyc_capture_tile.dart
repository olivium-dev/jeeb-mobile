import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../../core/widgets/jeeb/jeeb_select_chip.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../photo_attachment/domain/photo_attachment.dart';

/// One capture slot of the KYC identity step, rendered as an outlined row
/// (redesign-2026-08 screen 22): thumb · title + sub-line · trailing
/// affordance. It replaced a 140px square tile — three of those were the
/// screen's largest density offender.
///
/// Three visual states, in strict precedence **captured > locked > pending**:
///
///  * **captured** ([photo] non-null) — the real thumbnail, a success-inked
///    "Captured ✓" sub-line and a passive "Retake" text.
///  * **locked** ([isLocked]) — the whole row at 55% with no trailing; used by
///    the selfie row until both ID sides exist. The lock is presentation-only;
///    the cubit path stays open (JEBV4-295 / JM-040).
///  * **pending** — a dashed placeholder thumb, the [hint] coaching line and a
///    passive navy "Take photo" pill.
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
    this.isSelfie = false,
    this.trailingLabel,
    this.tileKey,
    this.captureCtaSemantic,
  });

  /// Card corner radius — `22 tpl 1308` (`border-radius: 18px`).
  static const double cardRadius = 18;

  /// Opacity of the locked row — `22 tpl 1324` (`opacity: .55`).
  static const double lockedOpacity = 0.55;

  static const double _thumbWidth = 64;
  static const double _thumbHeight = 44;
  static const double _thumbBorderWidth = 1.5;
  static const double _rowGap = 14;
  static const double _titleGap = 2;

  /// Share of the row the trailing affordance may take before it has to
  /// ellipsize. Never binds at 1× text with the shipped labels; it only stops
  /// a very long label from starving the title column.
  static const double _trailingMaxWidthFactor = 0.42;

  final String label;
  final PhotoAttachment? photo;
  final VoidCallback onTap;
  final bool isProcessing;

  /// Coaching sub-line shown in the pending state, and the "unlocks after your
  /// ID" line in the locked state. No sub-line at all when null.
  final String? hint;

  /// Presentation-only lock (see the class doc). Ignored once [photo] exists.
  final bool isLocked;

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
        JeebSemanticColors.light();
    final jeebText = context.jeebText;
    final captured = photo;
    final isCaptured = captured != null;
    // captured > locked > pending: a captured photo behind a still-locked gate
    // must read as captured, or the row paints a lie.
    final isLockedState = isLocked && !isCaptured;
    final isTappable = !isLockedState && !isProcessing;

    final subLine = _subLine(context, semantic, jeebText, isCaptured);
    final trailing = _trailing(context, jeebText, isCaptured, isLockedState);
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
                    color: colorScheme.primary,
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

    Widget card = JeebOutlinedCard(
      radius: cardRadius,
      onTap: isTappable ? onTap : null,
      // A locked row has no InkWell of its own, so without an opaque layer
      // taps would fall straight through the card to the scroll view and the
      // row would not even be a hit target for a11y focus. It absorbs its own
      // taps and does nothing with them — which is what "locked" means.
      child: isLockedState
          ? GestureDetector(behavior: HitTestBehavior.opaque, child: row)
          : row,
    );
    if (isLockedState) {
      // `tpl 1324` dims the whole row div, outline included — so the fade sits
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
      final success = context.jeebRoles.success;
      // TODO(redesign-24): the board's "looks sharp ✓" verdict needs a
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
        // w500: the coaching line is the quietest thing in the row (`tpl 1322`).
        style: jeebText.bodySmall.copyWith(
          fontWeight: FontWeight.w500,
          color: semantic.mutedText,
        ),
      ),
    );
  }

  Widget? _trailing(
    BuildContext context,
    JeebTextStyles jeebText,
    bool isCaptured,
    bool isLockedState,
  ) {
    if (isProcessing) {
      return const Padding(
        padding: EdgeInsetsDirectional.only(start: Spacing.small),
        child: OmdsLoadingState(size: Sizes.large, padding: EdgeInsets.zero),
      );
    }
    if (isLockedState) return null;
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
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: Spacing.small),
      child: JeebSelectChip(
        role: JeebChipRole.inlineAction,
        label: text,
        selected: true,
        // No identifier and no onTap: the pill is a visual, the row is the
        // single tap target (see the class doc).
      ),
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
            // navy ID slab instead of crashing the build. In production the
            // bytes are valid JPEG from the platform camera.
            errorBuilder: (_, _, _) => Container(
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: OmdsBorderRadius.xSmall,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.badge_rounded,
                size: Sizes.large,
                color: colorScheme.onPrimary,
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
          color: colorScheme.surfaceContainerHigh,
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
    return SizedBox(
      width: _thumbWidth,
      height: _thumbHeight,
      child: CustomPaint(
        painter: KycDashedBorderPainter(
          color: colorScheme.outline,
          radius: Spacing.xSmall,
          strokeWidth: _thumbBorderWidth,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: OmdsBorderRadius.xSmall,
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.photo_camera_rounded,
            size: Sizes.large,
            color: semantic.mutedText,
          ),
        ),
      ),
    );
  }
}

/// Dashed rounded-rectangle stroke for the pending capture thumb
/// (`22 tpl 1317`: `1.5px dashed`). Sanctioned bespoke — the Wave-1 kit ships
/// no dashed border and Flutter's `Border` cannot draw one.
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
