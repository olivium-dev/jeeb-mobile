import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../photo_attachment/domain/photo_attachment.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import 'dart:convert';
import 'dart:typed_data';
import '../../../../previews/harness/jeeb_preview.dart';

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
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/kyc/kyc_capture_tile_preview_test.dart
// ===========================================================================
//
// The tile is the only capture affordance in the KYC wizard: `KycIdentityStep`
// mounts three of them (ID front, ID back, selfie), full width inside the
// step's `EdgeInsets.all(Spacing.large)` padding. Every preview below is
// wrapped in that same padding so the canvas shows the width the wizard
// actually gives it — the tile's own height is fixed at
// `KycCaptureTile.tileHeight`, so width is the only free dimension and it is
// the one that decides whether the label fits.
//
// **Network-free by construction.** The tile has no cubit, no repository and no
// gateway — it takes a `PhotoAttachment` and a callback. The only byte payloads
// here are a 173-byte PNG literal and the stub picker's fill pattern, both
// inline. Nothing can reach Dio, so `jeebPreviewHost`'s guard is a net that
// never has to catch anything.
//
// **Why the ticker is off.** The `isProcessing` branch renders
// `OmdsLoadingState`, an indeterminate `CircularProgressIndicator` that never
// stops scheduling frames; the render tests' `pumpAndSettle` would hang on it.
// A still preview wants a still spinner anyway.
//
// **What to look at.** Three things these previews were written to make
// visible, all pinned in `test/previews/kyc/kyc_capture_tile_preview_test.dart`:
//
// 1. `isProcessing` is checked BEFORE `hasPhoto`, so a retake over an existing
//    photo (`kycCaptureTileRetakeInFlight`) blanks the thumbnail the user
//    already captured and shows the same bare spinner as a first capture
//    (`kycCaptureTileCapturing`). Only the 1 dp vs 1.5 dp border tells them
//    apart.
// 2. Both processing states drop the tile's only visible text. The `Semantics`
//    label survives, so a screen reader is fine; a sighted user loses which of
//    the three tiles they are looking at.
// 3. `label` is a plain `String` supplied by the caller, so the AR RTL
//    rendering of this matrix shows ENGLISH label text for every state except
//    `kycCaptureTileArabicLabel`, which passes the real ARB value. That one is
//    the only rendering here that exercises Arabic glyphs in the tile.

/// One tile at the width `KycIdentityStep` gives it (390 dp phone minus the
/// step's 20 dp padding either side), and just tall enough for the tile plus
/// that padding. Sizing the box to the real tile is the point: a wider canvas
/// would hide the label clipping that the captured state produces.
const Size _kycCaptureTileBox =
    Size(390, KycCaptureTile.tileHeight + 2 * Spacing.large);

/// Exact ARB copy (`kycIdFrontLabel`, `kycIdBackLabel`, `kycSelfieStepTitle`)
/// and the capture/retake semantics the step pairs with each — so a preview
/// shows the strings a jeeber sees, not invented stand-ins.
const String _kycCaptureTileFrontLabel = 'Front side';
const String _kycCaptureTileBackLabel = 'Back side';
const String _kycCaptureTileSelfieLabel = 'Take a selfie';

/// `kycSelfieStepTitle` in Arabic. See the section note: the tile cannot
/// localize a caller-supplied label, so this is the only way the matrix's AR
/// rendering gets Arabic text into the tile.
const String _kycCaptureTileSelfieLabelArabic = 'التقط صورة شخصية';

/// A real 48x30 PNG, so the canvas shows an actual decoded thumbnail under
/// `BoxFit.cover` rather than the tile's error fallback. Kept deliberately tiny
/// and inline — a preview must not read a file or a network asset.
final Uint8List _kycCaptureTileDecodablePng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAADAAAAAeCAIAAADlxgqWAAAAdElEQVR42u3WsQnA'
  'MAxE0ZszrVfIFKk9g+dMDAbjoJRGn3Cgzi5eJX0d5Qznqi2c3f+F0jxPQmkCUK7m'
  'DUrXLCCCZoIgmgHiaDoIpfkEJW5LoTQBKP2SCKVZQJArK5RmgFAFIveQe8g95B5y'
  'D7mH3EM/76EbIulRiR4s8zcAAAAASUVORK5CYII=',
);

/// The payload `StubPhotoPickerService` hands the cubit: a solid 0xC0 fill, not
/// a JPEG. Truncated to 4 KB here because the fill pattern is the whole point,
/// not the megabyte.
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
///
/// The `Column(crossAxisAlignment: stretch)` is not decoration — it is the only
/// thing that gives the tile a width. [KycCaptureTile] pins its HEIGHT and
/// nothing else, and its two bodies disagree about what to do with a loose
/// width: the captured [Stack] expands to the maximum, the placeholder [Column]
/// shrink-wraps to the glyph. Dropped straight into this preview's [Scaffold]
/// body — which passes width loosely — the empty tile renders 144 dp wide and
/// the captured one 350 dp, i.e. the slot would visibly change size the moment a
/// photo landed. The wizard's stretch column is what hides that in production,
/// so the previews reproduce it; the collapse itself is pinned in the test.
///
/// `onTap` is a no-op: the production callbacks are `cubit.captureIdFront` and
/// friends, which reach the platform camera through `PhotoPickerService`, and a
/// preview has no business opening one.
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
/// — camera glyph over the slot label, on the lighter `surfaceContainerLow`
/// fill with the 1.5 dp `outlineVariant` border that marks "empty".
///
/// This is the state a jeeber lands on three times in a row, and the only one
/// where the tile is a call to action rather than a receipt.
@JeebPreview(group: 'kyc', name: 'Empty · ID front', size: _kycCaptureTileBox)
Widget kycCaptureTileEmpty() => _kycCaptureTileHosted(
      label: _kycCaptureTileFrontLabel,
      captureCtaSemantic: 'Take photo',
    );

/// Captured: the thumbnail fills the tile under `BoxFit.cover` and the label
/// moves into a translucent pill pinned to the bottom-*start* corner.
///
/// The pill is the piece to watch. It sits in a [PositionedDirectional] with a
/// `start` and no `end`, so the [Stack] lays its [Text] out under unbounded
/// width constraints — the label cannot wrap and cannot ellipsize; it can only
/// run past the tile edge and be clipped by the Stack. At the ARB's real label
/// lengths it fits; the test pins how much headroom is actually left.
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
///
/// This is not a hypothetical: `StubPhotoPickerService` — the default picker in
/// the MVP build, every widget test and every Maestro flow — returns a solid
/// 0xC0 fill, and the production `errorBuilder` exists precisely to keep that
/// from crashing the build. So this, not [kycCaptureTileCaptured], is what a
/// stub-driven run of the wizard actually shows: a grey box with a generic
/// image glyph, and the label pill still on top.
///
/// Worth reviewing as a real-device state too — a corrupt or truncated camera
/// payload lands here, and the fallback gives the user no hint that anything
/// went wrong or that they should retake.
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
///
/// The tile swaps its whole body for a centred `OmdsLoadingState` and disables
/// the tap. Note what goes with it — the camera glyph AND the label — leaving a
/// box with no visible indication of which slot is busy. The `Semantics` label
/// is still attached, so this reads worse for a sighted user than for a screen
/// reader.
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
///
/// `build` tests `isProcessing` BEFORE `hasPhoto`, so the thumbnail the jeeber
/// already captured is replaced by the spinner for the duration of the pick —
/// if they cancel the camera, it reappears, but while the picker is open their
/// existing photo looks gone. Compare this rendering against
/// [kycCaptureTileCapturing]: the two differ only in the container's border
/// (1 dp `outline` here, 1.5 dp `outlineVariant` there), which is the entire
/// visual difference between "replacing a photo" and "taking your first one".
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
/// التقط صورة شخصية) instead of the English one — the longest-plausible-content
/// state, and the one that breaks.
///
/// Two reasons this preview exists. First, `label` arrives as a plain [String]
/// from `KycIdentityStep`, where the l10n lookup happens, so every other preview
/// here hardcodes English and the matrix's AR RTL rendering mirrors the LAYOUT
/// without ever putting an Arabic glyph in the tile. Second, it is where the
/// pill's missing width constraint stops being theoretical: Arabic sets wider
/// than English for the same key, and at 200% text this label runs off the
/// trailing edge of the tile and is chopped by the [Stack]'s `Clip.hardEdge` —
/// no wrap, no ellipsis, just a half-word. The widest ENGLISH label
/// ([kycCaptureTileUndecodableBytes]) survives the same rendering with roughly
/// 30 dp of text slack — about 20 dp once the pill's own trailing padding is
/// counted — which is why only the Arabic reading shows the defect, and why the
/// English one is a near miss rather than a clean pass.
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
