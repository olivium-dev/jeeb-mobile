import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

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
