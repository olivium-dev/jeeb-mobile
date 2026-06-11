import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

/// Fixed centre pin for the Capture Location map (Figma 56546:2303).
///
/// The marker is anchored so its TIP sits at the viewport centre (the
/// coordinate the user is choosing), which means the glyph is shifted up by
/// half its own height. It is purely visual — the parent wraps it in
/// [IgnorePointer]-equivalent layering so it never swallows map gestures.
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
          // Lift the glyph so the tip — not the centre — marks the point.
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
