import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../photo_attachment/domain/photo_attachment.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import 'dart:convert';
import 'dart:typed_data';
import '../../../../core/previews/jeeb_preview.dart';

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
// ============================== JEEB PREVIEWS ==============================
// ===========================================================================

/// One tile at the width `KycIdentityStep` gives it (390 dp phone minus the
const Size _kycCaptureTileBox =
    Size(390, KycCaptureTile.tileHeight + 2 * Spacing.large);

/// Exact ARB copy (`kycIdFrontLabel`, `kycIdBackLabel`, `kycSelfieStepTitle`)
/// and the capture/retake semantics the step pairs with each — so a preview
const String _kycCaptureTileFrontLabel = 'Front side';
const String _kycCaptureTileBackLabel = 'Back side';
const String _kycCaptureTileSelfieLabel = 'Take a selfie';

/// `kycSelfieStepTitle` in Arabic. See the section note: the tile cannot
/// localize a caller-supplied label, so this is the only way the matrix's AR
const String _kycCaptureTileSelfieLabelArabic = 'التقط صورة شخصية';

/// A real 48x30 PNG, so the canvas shows an actual decoded thumbnail under
/// `BoxFit.cover` rather than the tile's error fallback. Kept deliberately tiny
final Uint8List _kycCaptureTileDecodablePng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAADAAAAAeCAIAAADlxgqWAAAAdElEQVR42u3WsQnA'
  'MAxE0ZszrVfIFKk9g+dMDAbjoJRGn3Cgzi5eJX0d5Qznqi2c3f+F0jxPQmkCUK7m'
  'DUrXLCCCZoIgmgHiaDoIpfkEJW5LoTQBKP2SCKVZQJArK5RmgFAFIveQe8g95B5y'
  'D7mH3EM/76EbIulRiR4s8zcAAAAASUVORK5CYII=',
);

/// The payload `StubPhotoPickerService` hands the cubit: a solid 0xC0 fill, not
/// a JPEG. Truncated to 4 KB here because the fill pattern is the whole point,
final Uint8List _kycCaptureTileStubCameraBytes = Uint8List(4 * 1024)
  ..fillRange(0, 4 * 1024, 0xC0);

PhotoAttachment _kycCaptureTileAttachment(String id, Uint8List bytes) =>
    PhotoAttachment(
      id: id,
      bytes: bytes,
      originalSizeBytes: 1 * 1024 * 1024,
      source: PhotoSource.camera,
    );

/// Mounts one tile the way `KycIdentityStep` mounts it.
Widget _kycCaptureTileHosted({
  required String label,
  PhotoAttachment? photo,
  bool isProcessing = false,
  String? captureCtaSemantic,
}) {
  return TickerMode(
    enabled: false,
    child: Padding(
      padding: const EdgeInsets.all(Spacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          KycCaptureTile(
            label: label,
            photo: photo,
            isProcessing: isProcessing,
            captureCtaSemantic: captureCtaSemantic,
            onTap: () {},
          ),
        ],
      ),
    ),
  );
}

/// First run: nothing captured yet, so the tile is the dashed-feel placeholder
@JeebPreview(group: 'kyc', name: 'Empty · ID front', size: _kycCaptureTileBox)
Widget kycCaptureTileEmpty() => _kycCaptureTileHosted(
      label: _kycCaptureTileFrontLabel,
      captureCtaSemantic: 'Take photo',
    );

/// Captured: the thumbnail fills the tile under `BoxFit.cover` and the label
@JeebPreview(
  group: 'kyc',
  name: 'Captured · ID back',
  size: _kycCaptureTileBox,
)
Widget kycCaptureTileCaptured() => _kycCaptureTileHosted(
      label: _kycCaptureTileBackLabel,
      photo: _kycCaptureTileAttachment(
        'kyc-id-back',
        _kycCaptureTileDecodablePng,
      ),
      captureCtaSemantic: 'Retake',
    );

/// The same captured branch with bytes that are NOT a decodable image.
@JeebPreview(
  group: 'kyc',
  name: 'Captured · undecodable bytes',
  size: _kycCaptureTileBox,
)
Widget kycCaptureTileUndecodableBytes() => _kycCaptureTileHosted(
      label: _kycCaptureTileSelfieLabel,
      photo: _kycCaptureTileAttachment(
        'kyc-selfie',
        _kycCaptureTileStubCameraBytes,
      ),
      captureCtaSemantic: 'Retake selfie',
    );

/// A first capture in flight: `state.capturing == KycCaptureSlot.idFront`.
@JeebPreview(
  group: 'kyc',
  name: 'Capturing · first capture',
  size: _kycCaptureTileBox,
)
Widget kycCaptureTileCapturing() => _kycCaptureTileHosted(
      label: _kycCaptureTileFrontLabel,
      isProcessing: true,
      captureCtaSemantic: 'Take photo',
    );

/// A retake in flight over a photo that is already on file.
@JeebPreview(
  group: 'kyc',
  name: 'Retake in flight · photo hidden',
  size: _kycCaptureTileBox,
)
Widget kycCaptureTileRetakeInFlight() => _kycCaptureTileHosted(
      label: _kycCaptureTileBackLabel,
      photo: _kycCaptureTileAttachment(
        'kyc-id-back',
        _kycCaptureTileDecodablePng,
      ),
      isProcessing: true,
      captureCtaSemantic: 'Retake',
    );

/// The captured tile carrying its real Arabic label (`kycSelfieStepTitle` =
@JeebPreview(
  group: 'kyc',
  name: 'Captured · Arabic label',
  size: _kycCaptureTileBox,
)
Widget kycCaptureTileArabicLabel() => _kycCaptureTileHosted(
      label: _kycCaptureTileSelfieLabelArabic,
      photo: _kycCaptureTileAttachment(
        'kyc-selfie',
        _kycCaptureTileDecodablePng,
      ),
      captureCtaSemantic: 'إعادة التقاط الصورة الشخصية',
    );
