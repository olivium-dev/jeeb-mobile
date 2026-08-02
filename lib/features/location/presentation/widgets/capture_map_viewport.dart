import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

/// Neutral map-viewport placeholder for the Capture Location screen when no
/// live map widget is injected (dev seam / offline / tests).
///
/// This is intentionally NOT the Figma map raster (that asset is a mock and is
/// never bundled — UI-GUARDRAILS §0). Production injects the `ofl_geo_capture`
/// map via `CaptureLocationScreen.mapBuilder`; this surface only stands in so
/// the navbar + centre pin + CTA chrome can be validated deterministically.
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
        Icon(Icons.map_outlined, size: Sizes.fiveXLarge, color: iconColor),
        const SizedBox(height: Spacing.small),
        Text(l10n.captureLocationMapPreview, style: style),
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
// Render tests: test/previews/location/capture_map_viewport_preview_test.dart
// ===========================================================================
// Widget previews for [CaptureMapViewport] — run with
// `flutter widget-preview start`.
//
// [CaptureMapViewport] takes no parameters. It is a [Container] painted with
// `colorScheme.surfaceContainerHighest` wrapping a centred [Column] of one
// icon and one localized label, so everything it puts on screen is a function
// of exactly three ambient inputs: the [BoxConstraints] its parent hands it,
// the [ColorScheme], and the text scale. There is no cubit, no repository, no
// asset and no map tile — these previews are network-free because there is
// nothing to fetch, not merely because [jeebPreviewHost] guards the wire. (The
// widget exists precisely so the Capture Location chrome can be reviewed
// *without* a live `ofl_geo_capture` map; the Figma map raster is a mock and
// is never bundled — UI-GUARDRAILS §0.)
//
// Its "states" are therefore CONSTRAINT states. The previews below pin the two
// geometries that ship today — the full-bleed map area of
// `CaptureLocationScreen` and the 160 pt band in `_PinPreview` on
// `AddressDetailFormScreen` — plus the three host shapes a next caller is most
// likely to reach for (a square thumbnail, a short strip, a scrolling form),
// none of which the widget survives unaided.
//
// **About the captions.** Every state renders the same single string
// ("Map preview" / "معاينة الخريطة"), because the widget has no content to
// vary — so `find.text` on the widget's own output cannot tell two states
// apart, and a render test could pass while all five previews drew the same
// box. Each preview therefore carries a one-line caption naming the constraint
// under review, used by the test only to address a state. The assertion that
// proves the states really differ is the measured box in
// `test/previews/location/capture_map_viewport_preview_test.dart`.
//
// Three things these previews surface, all in the widget rather than in the
// previews:
//
//  * the content column has no minimum height, no clip and no scroll, so any
//    host shorter than ~108 pt at 200% text overflows with no sign of trouble
//    at 1× — [captureMapViewportShortStrip] and [captureMapViewportThumbnail];
//  * the [Container] shrink-wraps unbounded height, so the same widget stops
//    being a map band the moment it is put in a scroll view —
//    [captureMapViewportUnboundedHeight];
//  * the icon's 60%-opacity ink measures 2.88:1 on its own background in the
//    light scheme, under the 3:1 of WCAG 1.4.11 — see
//    [captureMapViewportCaptureScreen].

/// Phone width the Capture Location screen is designed against (Figma
/// 56546:2303).
const double _captureMapViewportPhoneWidth = 390;

/// Stand-in for the `Expanded` map area of `CaptureLocationScreen`: the body
/// height of a 390 × 844 phone less the app bar and the "Pin Location" CTA.
/// Shortened from the ~600 pt a real device gives it so the state still fits
/// the 800 × 600 surface the render tests pump onto.
const double _captureMapViewportCaptureBodyHeight = 500;

/// The band `_PinPreview` gives it on `AddressDetailFormScreen`:
/// `Sizes.eightXLarge * 2`, restated here so the preview can name the geometry
/// without importing the form.
const double _captureMapViewportFormBandHeight = Sizes.eightXLarge * 2;

/// A square map thumbnail — the shape a saved-address row or a two-up grid
/// would use.
const double _captureMapViewportThumbnailSide = 160;

/// A short strip: the tallest slot the content still fits at 1× text.
const double _captureMapViewportShortStripHeight = Sizes.tenXLarge;

/// Viewport height for the scrolling host, so the collapse in
/// [captureMapViewportUnboundedHeight] is visible against empty space rather
/// than filling the canvas.
const double _captureMapViewportScrollViewportHeight = 200;

/// Renders [constrained] above a caption naming the constraint under review.
///
/// The caption is preview scaffolding — see the library doc. It is deliberately
/// tiny and single-purpose so the 200%-text rendering of the matrix still shows
/// the viewport rather than a wall of label.
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
///
/// `_Body` puts the viewport in an `Expanded` above the "Pin Location" CTA and
/// layers a fixed centre pin on top of it, so on a real phone this surface is
/// ~390 × 600. This is the rendering a designer signs off, and the one where
/// the placeholder has the most room to look deliberate rather than broken.
///
/// Nothing mirrors between the EN and AR renderings — the layout is a centred
/// column and the only string is localized — so what the matrix is really for
/// here is the colour pair, and this is the state with the most of it on
/// screen:
///
///  * The icon is inked with `onSurfaceVariant` at
///    `UIConstants.opacityMedium` (0.60) over `surfaceContainerHighest`. In the
///    LIGHT scheme that composites to #938080 on #E5E1E5 and measures 2.88:1,
///    against the 3:1 WCAG 1.4.11 asks of a graphical object — and the 56 pt
///    icon, not the 14 pt label, is what carries "this is a map" at a glance.
///    The label itself is fine at 7.23:1. Fading a role to convey hierarchy is
///    what costs the icon its contrast, the same failure mode the theme's own
///    `_jeebOrangeContainer` comment records. The dark scheme is the one that
///    passes here (3.67:1), which is why this reads as a light-mode bug rather
///    than a dark-mode one.
///  * `surfaceContainerHighest` sits 1.29:1 from `surface` in light and 1.50:1
///    in dark, so the placeholder barely separates from the Scaffold behind it.
///    Harmless full-bleed (nothing else is on screen), which is exactly why the
///    address-form band below draws its own `outlineVariant` hairline. All
///    three numbers are asserted in the render test.
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
///
/// `_PinPreview` clips the viewport to `OmdsBorderRadius.large` and draws an
/// `outlineVariant` hairline over it, so the placeholder reads as a form field
/// rather than as a full-screen map. Reproduced here (rather than by importing
/// the form) so this stays a preview of the viewport: if the form's band height
/// or radius changes, this preview is wrong and the size assertion in the test
/// says so.
///
/// This is the state to check at 200% text, and the good news of the set: the
/// content grows from 88 pt to 108 pt and the band still holds it with 52 pt to
/// spare. The render test pins that, so a future designer trimming the band —
/// or an OMDS bump moving `Sizes.eightXLarge` — fails here instead of on a
/// user's phone.
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
///
/// Not a shipping geometry, but it is the obvious next one — a map thumbnail on
/// a saved-address row, or a two-up grid of pinned locations. Worth a preview
/// because width is the input nothing else here varies: the label is a plain
/// [Text] with no `maxLines` and no `TextOverflow`, so width is what decides
/// how tall the content is, and the widget never accounts for that.
///
/// One line at 1× (156.8 pt of label inside 160 pt, with the wide test font),
/// three lines at 200% — and 56 + 12 + 120 = 188 pt of content in a 160 pt box
/// **overflows by 28 pt, in Arabic as well as English**. Same square, same
/// widget, no warning at 1×. A caller sizing a thumbnail off the 1× rendering
/// ships an overflow stripe to every user who has enlarged their type.
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
///
/// The content column is 56 pt of icon + 12 pt of gap + one line of
/// `bodyMedium`, ~88 pt, so it fits a 96 pt slot with 8 pt to spare and looks
/// perfectly healthy in the EN light rendering. The icon is a fixed
/// `Sizes.fiveXLarge` and does not scale, but the label does: at the 200%
/// ceiling the label alone doubles to 40 pt, the column needs 108 pt, and it
/// **overflows by 12 pt**. Nothing clips it and `mainAxisSize:
/// MainAxisSize.min` cannot save it — the widget has no minimum height of its
/// own and no scroll, so the overflow lands on whatever the caller put
/// underneath.
///
/// This is the rendering the matrix exists for: **EN 200% text** shows the
/// overflow stripe here while EN light shows nothing wrong. The render test
/// pins both halves — it fits at 1×, it overflows at 2× — so the day someone
/// gives the widget a minimum height or a `FittedBox`, this preview is where it
/// gets checked.
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
///
/// [Container] with an `alignment` and no explicit size expands to fill bounded
/// constraints but SHRINK-WRAPS unbounded ones, so a viewport dropped into a
/// `ListView` or a `SingleChildScrollView` — the shape of every form screen in
/// this app, including the one that already hosts it — collapses from a map
/// band to an 88 pt strip of tinted background hugging its own icon, inside a
/// 200 pt viewport. There is no exception and no overflow stripe; it just
/// silently stops being a map.
///
/// `AddressDetailFormScreen` only avoids this because `_PinPreview` wraps it in
/// a `SizedBox(height: Sizes.eightXLarge * 2)`. Any caller that forgets that
/// [SizedBox] gets this, and nothing in the widget's API hints that the height
/// is the caller's problem.
@JeebPreview(group: 'location', name: 'Unbounded height (collapses)', size: Size(_captureMapViewportPhoneWidth, 260))
Widget captureMapViewportUnboundedHeight() => _captureMapViewportMeasured(
      'Unbounded: inside a scroll view',
      const SizedBox(
        width: _captureMapViewportPhoneWidth,
        height: _captureMapViewportScrollViewportHeight,
        child: SingleChildScrollView(child: CaptureMapViewport()),
      ),
    );
