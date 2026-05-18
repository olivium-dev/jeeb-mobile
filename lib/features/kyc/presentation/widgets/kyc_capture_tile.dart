import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../photo_attachment/domain/photo_attachment.dart';

/// Square tile used by the ID and selfie steps to preview a captured photo
/// or prompt the user to take one.
///
/// When [photo] is null we render a dashed-border placeholder with the camera
/// icon and a "take photo" affordance; otherwise we render the captured
/// thumbnail with a small retake overlay. Both states forward [onTap] so the
/// host can route to the camera or trigger a retake.
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

  /// Optional key for widget tests so they can target an individual tile
  /// (front, back, selfie) without depending on text content.
  final Key? tileKey;

  /// Screen-reader label for the capture/retake button surface.
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
              // Stub / test payloads aren't real JPEGs; show a neutral
              // placeholder instead of crashing the build. In production the
              // bytes are valid JPEG from the platform camera.
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
        Positioned(
          left: Spacing.small,
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
