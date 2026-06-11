import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

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
