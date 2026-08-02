import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
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
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/location/capture_location_pin_preview_test.dart
// ===========================================================================
// Widget previews for [CaptureLocationPin] — run with
// `flutter widget-preview start`.
//
// [CaptureLocationPin] takes no parameters and holds no state. It is one
// [Icon] (`Icons.location_on` at `Sizes.threeXLarge` = 40 pt, inked
// `colorScheme.error` with one `colorScheme.shadow` drop shadow) pushed up by
// `Transform.translate(Offset(0, -Sizes.large))` = 20 pt, wrapped in
// [Semantics] and [IgnorePointer]. There is no cubit, no repository, no asset
// and no map tile, so these previews are network-free because there is nothing
// to fetch — not merely because [jeebPreviewHost] guards the wire.
//
// Its "states" are therefore HOST states: the pin is always the same 40 pt
// glyph, and what varies is the box the caller centres it in. Both shipping
// callers are reproduced below (`CaptureLocationScreen._MapStack` and
// `AddressDetailFormScreen._PinPreview`), plus the geometry that decides
// whether the widget is correct at all — where the tip lands relative to the
// point the user is choosing — plus the two hosts a next caller reaches for
// and the widget does not survive.
//
// **About the captions.** The pin renders no text of its own (its only string
// is a [Semantics] label), so `find.text` on the widget's output cannot tell
// two states apart and a render test could pass while all five previews drew
// the same 40 pt icon. Each preview therefore carries a one-line caption
// naming the host under review, used by the test only to address a state. The
// assertions that prove the states really differ are the measured boxes in
// `test/previews/location/capture_location_pin_preview_test.dart`.
//
// What these previews expose, all of it in the widget rather than in the
// previews:
//
//  * **The tip does not sit on the chosen point.** The -20 pt lift puts the
//    icon's 40 pt BOX bottom on the map centre, and the widget's own doc reads
//    that as "the tip". The Material `location_on` path bottoms out at y=22 of
//    a 24-unit grid, so at 40 pt the drawn spike stops ~3.3 pt short of the box
//    edge and the pin marks a point ~3 pt NORTH of the coordinate the CTA
//    returns — [captureLocationPinAnchorCrosshair] draws the target so the gap
//    is visible.
//  * **It needs 40 pt of host above its anchor and nothing enforces it.**
//    Painting starts 40 pt above the anchor (20 pt of box + 20 pt of lift),
//    and a centred pin puts the anchor at half the host's height — so any
//    clipped host under 80 pt loses part of the pin's head, silently, with no
//    overflow stripe. See [captureLocationPinCompactBand].
//  * **It paints outside its own layout box with no clip.** The box is 40 pt
//    and the glyph occupies the 20 pt above it, so a caller who does not put
//    it in a [Stack] gets silent overdraw on its neighbour and no overflow
//    stripe to notice it by — [captureLocationPinInlineOverdraw].
//  * **The drop shadow is `colorScheme.shadow` in both schemes** — i.e. black,
//    which M3 does not tone for dark. It is the only thing lifting a saturated
//    pin off a busy map tile, and it composites 2.59:1 against the light map
//    fill but 1.31:1 against the dark one: on the night map it does roughly
//    nothing. Compare the `EN light` and `AR RTL dark` renderings of
//    [captureLocationPinCaptureScreen]. The pin's own ink is fine in both
//    (5.66:1 light, 7.28:1 dark, against the placeholder fill) — it is the
//    separation, not the colour, that is missing. All four numbers are
//    asserted in the render test.

/// Phone width the Capture Location screen is designed against (Figma
/// 56546:2303).
const double _captureLocationPinPhoneWidth = 390;

/// Stand-in for the `Expanded` map area of `CaptureLocationScreen`: the body of
/// a 390 x 844 phone less the app bar and the "Pin Location" CTA. Shortened
/// from the ~600 pt a real device gives it so the state still fits the 800 x 600
/// surface the render tests pump onto.
const double _captureLocationPinCaptureBodyHeight = 500;

/// The band `_PinPreview` gives the map on `AddressDetailFormScreen`:
/// `Sizes.eightXLarge * 2`, restated here so the preview can name the geometry
/// without importing the form.
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
///
/// The caption is preview scaffolding — see the library doc. It is deliberately
/// tiny and single-purpose so the 200%-text rendering of the matrix still shows
/// the pin rather than a wall of label.
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
///
/// The map fills the body and the pin is layered on top of it by a [Center],
/// never moving — the map pans underneath. Reproduced with [CaptureMapViewport]
/// rather than a live `ofl_geo_capture` map because the Figma map raster is a
/// mock and is never bundled (UI-GUARDRAILS §0); the pin's geometry does not
/// depend on what is under it.
///
/// This is the rendering a designer signs off, and the one to read against its
/// own **AR RTL dark** variant. Two things to look for there:
///
///  * Nothing mirrors, and nothing should: the only offset is vertical, so the
///    pin must land on the same pixel in Arabic. The render test pins that.
///  * The drop shadow is `colorScheme.shadow` (black) at
///    `UIConstants.opacityLow` in BOTH schemes. On the light map it is the halo
///    that keeps a red pin readable over map ink; in the dark scheme it is
///    black on a dark surface and contributes nothing, exactly where a
///    saturated pin over a night map needs it most.
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
///
/// The crosshair is preview scaffolding drawn at the EXACT centre of the host —
/// the coordinate `CaptureLocationScreen` returns when the CTA is tapped. The
/// pin is supposed to mark that point with its tip, and its own doc says the
/// glyph is "shifted up by half its own height" to do so.
///
/// Half of `Sizes.threeXLarge` (40) is `Sizes.large` (20), so the arithmetic is
/// self-consistent and puts the icon's BOX bottom exactly on the crosshair —
/// which the render test pins. What the picture shows is that the box bottom is
/// not the tip: the Material `location_on` path bottoms out at y=22 of a
/// 24-unit grid, so the drawn spike ends ~3.3 pt above the box edge and hangs
/// that far NORTH of the target. Small on screen, not zero on the ground, and
/// invisible in every rendering that does not draw the target.
///
/// Worth the matrix. The icon is a fixed 40 pt with the framework default
/// `applyTextScaling: false`, so the **EN 200% text** rendering must show the
/// pin in exactly the same place — the day an [IconTheme] turns text scaling on
/// for icons, the glyph doubles while the lift stays 20 pt and the anchor walks
/// off the target.
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
///
/// The form clips the band to `OmdsBorderRadius.large`, which is what makes the
/// host height load-bearing for this widget: the anchor sits at half the band
/// (80 pt) and the pin paints 40 pt above it, so the head clears the clip with
/// 40 pt to spare. Eighty pt is the smallest centred band that shows a whole
/// pin, and nothing in either widget records that. Halve this band — or let an
/// OMDS bump move `Sizes.eightXLarge` — and the head goes with it; the render
/// test pins the 40 pt margin so that lands here instead of on a user's phone.
///
/// The form's `outlineVariant` hairline is omitted: it sits over the band edge
/// and does not touch the pin.
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
///
/// A compact map thumbnail on a saved-address row is the obvious next caller,
/// and it gets a decapitated pin: the anchor is at 24 pt, painting starts 40 pt
/// above it, so 16 pt of the glyph is outside the [ClipRRect] and simply gone.
/// What is left is the spike — which reads as a smudge, not as a marker.
///
/// Nothing warns. This is not a [RenderFlex] overflow (the pin's own layout box
/// is 40 pt and fits inside 48), it is paint outside the box meeting a clip, so
/// there is no stripe, no exception and no debug output — only a wrong picture.
/// The render test measures the missing 16 pt.
///
/// The tile under it is a flat fill rather than [CaptureMapViewport]: the
/// placeholder's own content column is 88 pt at 1x text and overflows a 48 pt
/// band on its own, which is its defect and is already previewed next door in
/// `capture_map_viewport_preview.dart`. Borrowing it here would put a red
/// overflow stripe over the state under review.
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
///
/// Both shipping callers wrap it in `Center` inside a `Stack(fit: expand)`, so
/// the 20 pt it paints above its own layout box lands on the map. Put it in a
/// [Column] — a form field, a list row, anything laid out in flow — and that
/// 20 pt lands on whatever is above it instead. Here the glyph's head sits
/// inside the row above and paints over its label.
///
/// The widget cannot detect this and the framework will not report it: the
/// layout box is a well-behaved 40 x 40, so no [RenderFlex] overflows and no
/// assertion fires. It is a silent picture bug, and the only reason it has not
/// shipped is that both callers happen to compose it correctly.
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
