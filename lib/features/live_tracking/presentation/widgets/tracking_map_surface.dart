import 'package:flutter/material.dart';

import '../../../../core/widgets/jeeb_map_preview_canvas.dart';
import '../../../../l10n/app_localizations.dart';

/// Full-bleed map surface for the order-tracking screen (Figma 56560:1772).
///
/// The Figma frame shows a live map raster with the route polyline, the
/// destination spotlight pin and the courier heading puck. Those are map-SDK
/// overlay annotations — the raster itself is a Figma mock and is never
/// bundled (UI-GUARDRAILS §0). Production injects the live map (gateway
/// tracking SSE feed → `ofl_geo_capture` map layer); this themed surface
/// stands in so the navbar + bottom status panel chrome can be validated
/// deterministically on the dev seam / in tests, mirroring
/// `CaptureMapViewport`.
class TrackingMapSurface extends StatelessWidget {
  const TrackingMapSurface({super.key});

  static const Key rootKey = Key('tracking_map');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'tracking_map',
      image: true,
      label: l10n.trackingMapSemanticLabel,
      child: const SizedBox.expand(
        key: rootKey,
        child: JeebMapPreviewCanvas(showRoute: true, showCenterMarker: true),
      ),
    );
  }
}
