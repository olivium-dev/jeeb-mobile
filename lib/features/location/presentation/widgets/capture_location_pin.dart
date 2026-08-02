import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

import '../../../../core/previews/jeeb_preview.dart';
import 'capture_map_viewport.dart';

class CaptureLocationPin extends StatelessWidget {
  const CaptureLocationPin({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IgnorePointer(
      child: Semantics(
        identifier: 'capture_location_pin',
        image: true,
        label: l10n.captureLocationPinSemantic,
        child: Transform.translate(
          offset: const Offset(0, -Sizes.large),
          child: const _PinGlyph(),
        ),
      ),
    );
  }
}

class _PinGlyph extends StatelessWidget {
  const _PinGlyph();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Icon(
      Icons.location_on,
      size: Sizes.threeXLarge,
      color: scheme.error,
      shadows: [
        Shadow(
          color: scheme.shadow.withValues(alpha: UIConstants.opacityLow),
          blurRadius: Spacing.xSmall,
          offset: const Offset(0, Sizes.threeXSmall),
        ),
      ],
    );
  }
}
// ============================== JEEB PREVIEWS ==============================

const double _captureLocationPinPhoneWidth = 390;

/// Stand-in for the `Expanded` map area of `CaptureLocationScreen`: the body of
/// a 390 x 844 phone less the app bar and the "Pin Location" CTA. Shortened
const double _captureLocationPinCaptureBodyHeight = 500;

/// The band `_PinPreview` gives the map on `AddressDetailFormScreen`:
/// `Sizes.eightXLarge * 2`, restated here so the preview can name the geometry
const double _captureLocationPinFormBandHeight = Sizes.eightXLarge * 2;

/// A compact map band — the shape a saved-address row or a two-up grid would
/// use. Deliberately under the 80 pt a centred pin needs to show its head.
const double _captureLocationPinCompactBandHeight = Sizes.fourXLarge;

/// Host for the anchor study: tall enough to see the whole glyph and the target
/// it is supposed to mark, short enough that the crosshair is not lost.
const double _captureLocationPinAnchorBandHeight = 200;

/// Height of the neighbour rows in [captureLocationPinInlineOverdraw].
const double _captureLocationPinNeighbourRowHeight = Sizes.fourXLarge;

/// Half-length of each crosshair arm.
const double _captureLocationPinCrosshairArm = Sizes.twoXLarge;

/// One logical pixel — the crosshair's stroke. An odd-width line centred in an
/// even-height box still straddles the exact centre, which is the point.
const double _captureLocationPinHairline = 1;

/// Anchors the centred host of each state, so the render test can measure the
/// pin against the box that owns it rather than against the canvas.
const Key captureLocationPinHostKey = Key('preview_pin_host');

/// Anchors the neighbour row the pin overdraws, so the test can measure the
/// collision rather than infer it.
const Key captureLocationPinRowAboveKey = Key('preview_pin_row_above');

/// Renders [scene] above a caption naming the host under review.
/// The caption is preview scaffolding — see the library doc. It is deliberately
Widget _captureLocationPinMeasured(String caption, Widget scene) => Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          scene,
          const SizedBox(height: Spacing.xSmall),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );

/// Production composition #1: `CaptureLocationScreen._MapStack`.
/// The map fills the body and the pin is layered on top of it by a [Center],
@JeebPreview(
  group: 'location',
  name: 'Capture screen (production, full bleed)',
  size: Size(_captureLocationPinPhoneWidth, 560),
  matrix: true,
)
Widget captureLocationPinCaptureScreen() => _captureLocationPinMeasured(
      'Capture screen: pin centred on a 390x500 map area',
      const SizedBox(
        key: captureLocationPinHostKey,
        width: _captureLocationPinPhoneWidth,
        height: _captureLocationPinCaptureBodyHeight,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            CaptureMapViewport(),
            Center(child: CaptureLocationPin()),
          ],
        ),
      ),
    );

/// The geometry that decides whether the widget is correct: where the tip lands
/// relative to the point the user is choosing.
@JeebPreview(
  group: 'location',
  name: 'Anchor: tip vs the chosen point',
  size: Size(_captureLocationPinPhoneWidth, 260),
  matrix: true,
)
Widget captureLocationPinAnchorCrosshair() => _captureLocationPinMeasured(
      'Anchor study: crosshair marks the returned coordinate',
      const SizedBox(
        key: captureLocationPinHostKey,
        width: _captureLocationPinPhoneWidth,
        height: _captureLocationPinAnchorBandHeight,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            CaptureMapViewport(),
            Center(child: _CaptureLocationPinTargetCrosshair()),
            Center(child: CaptureLocationPin()),
          ],
        ),
      ),
    );

/// Production composition #2: the 160 pt pin band on
/// `AddressDetailFormScreen._PinPreview` (`hasPin: true`).
@JeebPreview(
  group: 'location',
  name: 'Address form band (production, 160pt)',
  size: Size(_captureLocationPinPhoneWidth, 220),
)
Widget captureLocationPinAddressFormBand() => _captureLocationPinMeasured(
      'Address form: 160pt clipped band',
      const SizedBox(
        key: captureLocationPinHostKey,
        width: _captureLocationPinPhoneWidth,
        height: _captureLocationPinFormBandHeight,
        child: ClipRRect(
          borderRadius: OmdsBorderRadius.large,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              CaptureMapViewport(),
              Center(child: CaptureLocationPin()),
            ],
          ),
        ),
      ),
    );

/// The state that breaks: the same clipped band at 48 pt.
/// A compact map thumbnail on a saved-address row is the obvious next caller,
@JeebPreview(
  group: 'location',
  name: 'Compact 48pt band (head clipped)',
  size: Size(_captureLocationPinPhoneWidth, 120),
)
Widget captureLocationPinCompactBand() => _captureLocationPinMeasured(
      'Compact band: 390x48 clipped thumbnail',
      const SizedBox(
        key: captureLocationPinHostKey,
        width: _captureLocationPinPhoneWidth,
        height: _captureLocationPinCompactBandHeight,
        child: ClipRRect(
          borderRadius: OmdsBorderRadius.large,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _CaptureLocationPinMapTileFill(),
              Center(child: CaptureLocationPin()),
            ],
          ),
        ),
      ),
    );

/// The other state that breaks: the pin as an ordinary child, not a [Stack]
/// overlay.
@JeebPreview(
  group: 'location',
  name: 'Inline in a Column (overdraws its neighbour)',
  size: Size(_captureLocationPinPhoneWidth, 220),
)
Widget captureLocationPinInlineOverdraw() => _captureLocationPinMeasured(
      'Inline column: pin paints 20pt above its own box',
      const SizedBox(
        width: _captureLocationPinPhoneWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _CaptureLocationPinNeighbourRow(label: 'Row above the pin', anchorKey: captureLocationPinRowAboveKey),
            CaptureLocationPin(),
            _CaptureLocationPinNeighbourRow(label: 'Row below the pin'),
          ],
        ),
      ),
    );

/// Preview scaffolding: the flat map fill [CaptureMapViewport] paints under its
/// own content, without that content.
class _CaptureLocationPinMapTileFill extends StatelessWidget {
  const _CaptureLocationPinMapTileFill();

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      );
}

/// Preview scaffolding: a crosshair on the exact centre of its host, standing
/// for the coordinate the Capture Location CTA returns.
class _CaptureLocationPinTargetCrosshair extends StatelessWidget {
  const _CaptureLocationPinTargetCrosshair();

  @override
  Widget build(BuildContext context) {
    final Color ink = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: _captureLocationPinCrosshairArm * 2,
      height: _captureLocationPinCrosshairArm * 2,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          SizedBox(
            width: _captureLocationPinCrosshairArm * 2,
            height: _captureLocationPinHairline,
            child: ColoredBox(color: ink),
          ),
          SizedBox(
            width: _captureLocationPinHairline,
            height: _captureLocationPinCrosshairArm * 2,
            child: ColoredBox(color: ink),
          ),
        ],
      ),
    );
  }
}

/// Preview scaffolding: a filled row standing in for whatever a flow layout
/// puts next to the pin.
class _CaptureLocationPinNeighbourRow extends StatelessWidget {
  const _CaptureLocationPinNeighbourRow({required this.label, this.anchorKey});

  final String label;
  final Key? anchorKey;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      key: anchorKey,
      height: _captureLocationPinNeighbourRowHeight,
      alignment: Alignment.center,
      color: scheme.surfaceContainerHigh,
      child: Text(label, style: TextStyle(color: scheme.onSurface)),
    );
  }
}
