import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

class CaptureMapViewport extends StatelessWidget {
  const CaptureMapViewport({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const _PreviewContent(),
    );
  }
}

class _PreviewContent extends StatelessWidget {
  const _PreviewContent();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(color: scheme.onSurfaceVariant);
    final iconColor =
        scheme.onSurfaceVariant.withValues(alpha: UIConstants.opacityMedium);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // R10: the redesign's icon set is filled, single-colour — no outline
        // variants anywhere on the board.
        Icon(Icons.map, size: Sizes.fiveXLarge, color: iconColor),
        const SizedBox(height: Spacing.small),
        Text(l10n.captureLocationMapPreview, style: style),
      ],
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// Phone width the Capture Location screen is designed against (Figma
/// 56546:2303).
const double _captureMapViewportPhoneWidth = 390;

/// Stand-in for the `Expanded` map area of `CaptureLocationScreen`: the body
/// height of a 390 × 844 phone less the app bar and the "Pin Location" CTA.
const double _captureMapViewportCaptureBodyHeight = 500;

/// The band `_PinPreview` gives it on `AddressDetailFormScreen`:
/// `Sizes.eightXLarge * 2`, restated here so the preview can name the geometry
const double _captureMapViewportFormBandHeight = Sizes.eightXLarge * 2;

/// A square map thumbnail — the shape a saved-address row or a two-up grid
/// would use.
const double _captureMapViewportThumbnailSide = 160;

/// A short strip: the tallest slot the content still fits at 1× text.
const double _captureMapViewportShortStripHeight = Sizes.tenXLarge;

/// Viewport height for the scrolling host, so the collapse in
/// [captureMapViewportUnboundedHeight] is visible against empty space rather
const double _captureMapViewportScrollViewportHeight = 200;

/// Renders [constrained] above a caption naming the constraint under review.
/// The caption is preview scaffolding — see the library doc. It is deliberately
Widget _captureMapViewportMeasured(String caption, Widget constrained) => Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          constrained,
          const SizedBox(height: Spacing.xSmall),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );

/// Production geometry #1: the full-bleed map area of `CaptureLocationScreen`.
/// `_Body` puts the viewport in an `Expanded` above the "Pin Location" CTA and
@JeebPreview(group: 'location', 
  name: 'Capture screen (production, full bleed)',
  size: Size(_captureMapViewportPhoneWidth, 560),
)
Widget captureMapViewportCaptureScreen() => _captureMapViewportMeasured(
      'Capture screen: 390x500 map area',
      const SizedBox(
        width: _captureMapViewportPhoneWidth,
        height: _captureMapViewportCaptureBodyHeight,
        child: CaptureMapViewport(),
      ),
    );

/// Production geometry #2: the 160 pt pin band on `AddressDetailFormScreen`.
/// `_PinPreview` clips the viewport to `OmdsBorderRadius.large` and draws an
@JeebPreview(group: 'location', 
  name: 'Address form band (production, 160pt)',
  size: Size(_captureMapViewportPhoneWidth, 220),
)
Widget captureMapViewportAddressFormBand() => _captureMapViewportMeasured(
      'Address form: 160pt clipped band',
      const SizedBox(
        width: _captureMapViewportPhoneWidth,
        height: _captureMapViewportFormBandHeight,
        child: ClipRRect(
          borderRadius: OmdsBorderRadius.large,
          child: CaptureMapViewport(),
        ),
      ),
    );

/// A 160 pt square thumbnail: narrow enough that the label has to wrap.
/// Not a shipping geometry, but it is the obvious next one — a map thumbnail on
@JeebPreview(group: 'location', name: 'Square thumbnail (160pt)', size: Size(_captureMapViewportPhoneWidth, 220))
Widget captureMapViewportThumbnail() => _captureMapViewportMeasured(
      'Thumbnail: 160x160 square',
      const SizedBox(
        width: _captureMapViewportThumbnailSide,
        height: _captureMapViewportThumbnailSide,
        child: CaptureMapViewport(),
      ),
    );

/// The state that breaks: a 96 pt strip — tall enough at 1× text, not at 200%.
/// The content column is 56 pt of icon + 12 pt of gap + one line of
@JeebPreview(group: 'location', 
  name: 'Short strip 96pt (breaks at 200%)',
  size: Size(_captureMapViewportPhoneWidth, 160),
)
Widget captureMapViewportShortStrip() => _captureMapViewportMeasured(
      'Short strip: 390x96 slot',
      const SizedBox(
        width: _captureMapViewportPhoneWidth,
        height: _captureMapViewportShortStripHeight,
        child: CaptureMapViewport(),
      ),
    );

/// The other state that breaks: unbounded height, i.e. inside a scroll view.
/// [Container] with an `alignment` and no explicit size expands to fill bounded
@JeebPreview(group: 'location', name: 'Unbounded height (collapses)', size: Size(_captureMapViewportPhoneWidth, 260))
Widget captureMapViewportUnboundedHeight() => _captureMapViewportMeasured(
      'Unbounded: inside a scroll view',
      const SizedBox(
        width: _captureMapViewportPhoneWidth,
        height: _captureMapViewportScrollViewportHeight,
        child: SingleChildScrollView(child: CaptureMapViewport()),
      ),
    );
