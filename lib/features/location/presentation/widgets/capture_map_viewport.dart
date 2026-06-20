import 'package:flutter/material.dart';

import '../../../../core/widgets/jeeb_map_preview_canvas.dart';

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
    return const JeebMapPreviewCanvas();
  }
}
