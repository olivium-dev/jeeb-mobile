import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../photo_attachment/domain/photo_attachment.dart';

class KycCaptureTile extends StatelessWidget {
  const KycCaptureTile({
    super.key,
    required this.label,
    required this.photo,
    required this.onTap,
    required this.isProcessing,
    this.tileKey,
    this.captureCtaSemantic,
  });

  static const double tileHeight = 140;

  final String label;
  final PhotoAttachment? photo;
  final VoidCallback onTap;
  final bool isProcessing;

  final Key? tileKey;

  final String? captureCtaSemantic;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasPhoto = photo != null;
    return Semantics(
      key: tileKey,
      button: true,
      enabled: !isProcessing,
      label: captureCtaSemantic ?? label,
      child: InkWell(
        onTap: isProcessing ? null : onTap,
        borderRadius: OmdsBorderRadius.small,
        child: Container(
          height: tileHeight,
          decoration: BoxDecoration(
            color: hasPhoto
                ? colorScheme.surfaceContainerHighest
                : colorScheme.surfaceContainerLow,
            borderRadius: OmdsBorderRadius.small,
            border: Border.all(
              color: hasPhoto
                  ? colorScheme.outline
                  : colorScheme.outlineVariant,
              width: hasPhoto ? 1 : 1.5,
            ),
          ),
          child: isProcessing
              ? const Center(child: OmdsLoadingState())
              : hasPhoto
                  ? _PreviewBody(label: label, photo: photo!)
                  : _PlaceholderBody(label: label),
        ),
      ),
    );
  }
}

class _PlaceholderBody extends StatelessWidget {
  const _PlaceholderBody({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.photo_camera_outlined,
          color: colorScheme.primary,
          size: Sizes.twoXLarge,
        ),
        const SizedBox(height: Spacing.xSmall),
        Text(
          label,
          style: textTheme.labelLarge?.copyWith(color: colorScheme.primary),
        ),
      ],
    );
  }
}

class _PreviewBody extends StatelessWidget {
  const _PreviewBody({required this.label, required this.photo});

  final String label;
  final PhotoAttachment photo;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: OmdsBorderRadius.small,
            child: Image.memory(
              photo.bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => Container(
                color: colorScheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: Icon(
                  Icons.image_outlined,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        PositionedDirectional(
          start: Spacing.small,
          bottom: Spacing.small,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.small,
              vertical: Sizes.threeXSmall,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.85),
              borderRadius: OmdsBorderRadius.pill,
            ),
            child: Text(
              label,
              style: textTheme.labelSmall,
            ),
          ),
        ),
      ],
    );
  }
}
