import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_shadows.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../l10n/app_localizations.dart';

/// Fixed centre pin for the Capture Location map (redesign-2026-08 screen 09,
/// HTML tpl 529-533).
///
/// Three stacked marks, centred on each other: a navy callout pill, the red
/// marker glyph, and a soft ground mark under its tip. The marker is anchored
/// so its TIP — not the column's centre — sits at the viewport centre, because
/// the tip is the coordinate the customer is choosing. It is purely visual and
/// never swallows map gestures.
class CaptureLocationPin extends StatelessWidget {
  const CaptureLocationPin({super.key});

  /// Gap between the callout pill and the marker glyph (tpl 531 `margin-top`).
  static const double _calloutGap = 4;

  /// The ground mark's box, which is the only thing rendered BELOW the tip.
  /// Subtracting it from the fractional centring is what re-anchors the tip.
  static const double _groundMarkWidth = 10;
  static const double _groundMarkHeight = 4;

  /// `rgba(0,0,0,.25)` in the design (tpl 531/533), expressed against the
  /// scheme's own shadow ink rather than a raw colour.
  static const double _shadowAlpha = 0.25;

  /// The callout pill's vertical inset — the design's `6px`, which sits
  /// between `Spacing.twoXSmall` and `Spacing.xSmall` and has no token.
  static const double _calloutPadV = 6;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IgnorePointer(
      // Tip-anchoring, resolved from the column's OWN height so the variable
      // callout text cannot push the pin off the coordinate: shift up by half
      // the column (bottom lands on the centre), then back down by the only
      // box that sits below the tip (the ground mark).
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
                label: l10n.captureLocationPinCallout,
                child: _Callout(
                  text: l10n.captureLocationPinCallout,
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
                    _PinGlyph(alpha: _shadowAlpha),
                    _GroundMark(
                      width: _groundMarkWidth,
                      height: _groundMarkHeight,
                      alpha: _shadowAlpha,
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

/// The navy "Pin here" callout above the marker (tpl 530). Centred by the
/// column, so it needs no directional offset and mirrors for free.
class _Callout extends StatelessWidget {
  const _Callout({required this.text, required this.verticalPadding});

  final String text;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: OmdsBorderRadius.pill,
        boxShadow: JeebShadows.ctaNavy,
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.small,
          vertical: verticalPadding,
        ),
        child: Text(
          text,
          style: context.jeebText.bodySmall.copyWith(color: scheme.onPrimary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _PinGlyph extends StatelessWidget {
  const _PinGlyph({required this.alpha});

  /// tpl 531 `drop-shadow(0 6px 10px rgba(0,0,0,.25))`.
  static const double _blur = 10;
  static const double _dy = 6;

  final double alpha;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Icon(
      Icons.location_on,
      size: Sizes.threeXLarge,
      color: scheme.error,
      shadows: [
        Shadow(
          color: scheme.shadow.withValues(alpha: alpha),
          blurRadius: _blur,
          offset: const Offset(0, _dy),
        ),
      ],
    );
  }
}

/// The small soft dash under the tip that reads as the marker's contact
/// shadow (tpl 533).
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
        borderRadius: OmdsBorderRadius.pill,
      ),
    );
  }
}
