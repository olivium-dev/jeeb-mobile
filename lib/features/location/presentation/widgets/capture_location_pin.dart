import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/motion/jeeb_motion_primitives.dart';
import '../../../../core/theme/jeeb_radii.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_shadows.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/capture_pin_purpose.dart';

/// Fixed centre pin for the Capture Location map (MIDNIGHT R11).
///
/// Three stacked marks, centred on each other: a glass callout pill, the
/// danger-red marker glyph inside its own halo, and a soft ground mark under
/// its tip. The marker is anchored so its TIP — not the column's centre — sits
/// at the viewport centre, because the tip is the coordinate the customer is
/// choosing. It is purely visual and never swallows map gestures.
///
/// Motion (03-MOTION-NOTES R11, the tile's only two moving elements): the
/// marker floats on `jFloat` at 2.6s and the ground mark breathes on the SAME
/// 2.6s period with no delay, so the shadow fades exactly as the pin lifts.
/// The callout does not move.
class CaptureLocationPin extends StatelessWidget {
  const CaptureLocationPin({
    super.key,
    this.purpose = CapturePinPurpose.dropOff,
  });

  /// What the pin is choosing — drives the callout copy. The screen is shared
  /// by the pickup leg and the saved-address pick, which both used to read
  /// "Drop-off here".
  final CapturePinPurpose purpose;

  /// R11: `jFloat`/`jBreathe` both run at 2.6s here — much faster than the 4s
  /// card-art float.
  static const Duration pinPeriod = Duration(milliseconds: 2600);

  /// Gap between the callout pill and the marker glyph.
  static const double _calloutGap = 4;

  /// The board's 42px marker svg renders a ~35px glyph.
  static const double _glyphSize = 35;

  /// The ground mark's box, which is the only thing rendered BELOW the tip.
  /// Subtracting it from the fractional centring is what re-anchors the tip.
  static const double _groundMarkWidth = 12;
  static const double _groundMarkHeight = 5;

  /// `rgba(0,0,0,.35)` (R11 ground mark).
  static const double _shadowAlpha = 0.35;

  /// The callout pill's vertical inset — the design's `6px`, which sits
  /// between `Spacing.twoXSmall` and `Spacing.xSmall` and has no token.
  static const double _calloutPadV = 6;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final callout = purpose.callout(l10n);
    return IgnorePointer(
      // Tip-anchoring, resolved from the column's OWN height so the variable
      // callout text cannot push the pin off the coordinate.
      child: Transform.translate(
        offset: const Offset(0, _groundMarkHeight),
        child: FractionalTranslation(
          translation: const Offset(0, -0.5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // A SIBLING semantics node, never nested inside the pin's node —
              // a nested one would be swallowed by `capture_location_pin`.
              Semantics(
                identifier: 'capture_location_pin_callout',
                image: true,
                label: callout,
                child: _Callout(
                  text: callout,
                  verticalPadding: _calloutPadV,
                ),
              ),
              const SizedBox(height: _calloutGap),
              Semantics(
                identifier: 'capture_location_pin',
                image: true,
                label: l10n.captureLocationPinSemantic,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    JFloat(
                      duration: pinPeriod,
                      child: _PinGlyph(size: _glyphSize),
                    ),
                    JBreathe(
                      duration: pinPeriod,
                      child: _GroundMark(
                        width: _groundMarkWidth,
                        height: _groundMarkHeight,
                        alpha: _shadowAlpha,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "Drop-off here" callout above the marker — a glass pill on the map, per
/// the R11 motion notes' own naming. Centred by the column, so it mirrors free.
class _Callout extends StatelessWidget {
  const _Callout({required this.text, required this.verticalPadding});

  final String text;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glass = Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: glass.glassFillEmphasis,
        borderRadius: BorderRadius.circular(JeebRadii.pill),
        border: Border.all(color: glass.glassBorderVivid),
        boxShadow: JeebShadows.overlay,
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.small,
          vertical: verticalPadding,
        ),
        child: Text(
          text,
          style: context.jeebText.bodySmall.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _PinGlyph extends StatelessWidget {
  const _PinGlyph({required this.size});

  /// R11 `drop-shadow(0 0 16px rgba(255,82,82,.5))` — the glow IS the pin's
  /// shadow on this board; the old black drop shadow is a light-theme remnant.
  static const double _glowBlur = 16;
  static const double _glowAlpha = 0.5;

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Icon(
      Icons.location_on,
      size: size,
      color: scheme.error,
      shadows: [
        Shadow(
          color: scheme.error.withValues(alpha: _glowAlpha),
          blurRadius: _glowBlur,
        ),
      ],
    );
  }
}

/// The small soft dash under the tip that reads as the marker's contact shadow.
class _GroundMark extends StatelessWidget {
  const _GroundMark({
    required this.width,
    required this.height,
    required this.alpha,
  });

  final double width;
  final double height;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.shadow.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(JeebRadii.pill),
      ),
    );
  }
}
