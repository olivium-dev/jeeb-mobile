/// Widget previews for [KycCaptureTile] — run with
/// `flutter widget-preview start`.
///
/// The tile is the only capture affordance in the KYC wizard: `KycIdentityStep`
/// mounts three of them (ID front, ID back, selfie), full width inside the
/// step's `EdgeInsets.all(Spacing.large)` padding. Every preview below is
/// wrapped in that same padding so the canvas shows the width the wizard
/// actually gives it — the tile's own height is fixed at
/// [KycCaptureTile.tileHeight], so width is the only free dimension and it is
/// the one that decides whether the label fits.
///
/// **Network-free by construction.** The tile has no cubit, no repository and no
/// gateway — it takes a [PhotoAttachment] and a callback. The only byte payloads
/// here are a 173-byte PNG literal and the stub picker's fill pattern, both
/// inline. Nothing can reach Dio, so [jeebPreviewHost]'s guard is a net that
/// never has to catch anything.
///
/// **Why the ticker is off.** The `isProcessing` branch renders
/// `OmdsLoadingState`, an indeterminate [CircularProgressIndicator] that never
/// stops scheduling frames; the render tests' `pumpAndSettle` would hang on it.
/// A still preview wants a still spinner anyway.
///
/// **What to look at.** Three things these previews were written to make
/// visible, all pinned in `test/previews/kyc/kyc_capture_tile_preview_test.dart`:
///
/// 1. `isProcessing` is checked BEFORE `hasPhoto`, so a retake over an existing
///    photo ([kycCaptureTileRetakeInFlight]) blanks the thumbnail the user
///    already captured and shows the same bare spinner as a first capture
///    ([kycCaptureTileCapturing]). Only the 1 dp vs 1.5 dp border tells them
///    apart.
/// 2. Both processing states drop the tile's only visible text. The `Semantics`
///    label survives, so a screen reader is fine; a sighted user loses which of
///    the three tiles they are looking at.
/// 3. [label] is a plain [String] supplied by the caller, so the AR RTL
///    rendering of this matrix shows ENGLISH label text for every state except
///    [kycCaptureTileArabicLabel], which passes the real ARB value. That one is
///    the only rendering here that exercises Arabic glyphs in the tile.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../features/kyc/presentation/widgets/kyc_capture_tile.dart';
import '../../features/photo_attachment/domain/photo_attachment.dart';
import '../harness/jeeb_preview.dart';

/// One tile at the width `KycIdentityStep` gives it (390 dp phone minus the
/// step's 20 dp padding either side), and just tall enough for the tile plus
/// that padding. Sizing the box to the real tile is the point: a wider canvas
/// would hide the label clipping that the captured state produces.
const Size _tileBox = Size(390, KycCaptureTile.tileHeight + 2 * Spacing.large);

/// Exact ARB copy (`kycIdFrontLabel`, `kycIdBackLabel`, `kycSelfieStepTitle`)
/// and the capture/retake semantics the step pairs with each — so a preview
/// shows the strings a jeeber sees, not invented stand-ins.
const String _frontLabel = 'Front side';
const String _backLabel = 'Back side';
const String _selfieLabel = 'Take a selfie';

/// `kycSelfieStepTitle` in Arabic. See the library note: the tile cannot
/// localize a caller-supplied label, so this is the only way the matrix's AR
/// rendering gets Arabic text into the tile.
const String _selfieLabelArabic = 'التقط صورة شخصية';

/// A real 48x30 PNG, so the canvas shows an actual decoded thumbnail under
/// `BoxFit.cover` rather than the tile's error fallback. Kept deliberately tiny
/// and inline — a preview must not read a file or a network asset.
final Uint8List _decodablePng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAADAAAAAeCAIAAADlxgqWAAAAdElEQVR42u3WsQnA'
  'MAxE0ZszrVfIFKk9g+dMDAbjoJRGn3Cgzi5eJX0d5Qznqi2c3f+F0jxPQmkCUK7m'
  'DUrXLCCCZoIgmgHiaDoIpfkEJW5LoTQBKP2SCKVZQJArK5RmgFAFIveQe8g95B5y'
  'D7mH3EM/76EbIulRiR4s8zcAAAAASUVORK5CYII=',
);

/// The payload `StubPhotoPickerService` hands the cubit: a solid 0xC0 fill, not
/// a JPEG. Truncated to 4 KB here because the fill pattern is the whole point,
/// not the megabyte.
final Uint8List _stubCameraBytes = Uint8List(4 * 1024)
  ..fillRange(0, 4 * 1024, 0xC0);

PhotoAttachment _attachment(String id, Uint8List bytes) => PhotoAttachment(
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
Widget _hosted({
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
@JeebPreview(group: 'kyc', name: 'Empty · ID front', size: _tileBox)
Widget kycCaptureTileEmpty() => _hosted(
      label: _frontLabel,
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
@JeebPreview(group: 'kyc', name: 'Captured · ID back', size: _tileBox)
Widget kycCaptureTileCaptured() => _hosted(
      label: _backLabel,
      photo: _attachment('kyc-id-back', _decodablePng),
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
@JeebPreview(group: 'kyc', name: 'Captured · undecodable bytes', size: _tileBox)
Widget kycCaptureTileUndecodableBytes() => _hosted(
      label: _selfieLabel,
      photo: _attachment('kyc-selfie', _stubCameraBytes),
      captureCtaSemantic: 'Retake selfie',
    );

/// A first capture in flight: `state.capturing == KycCaptureSlot.idFront`.
///
/// The tile swaps its whole body for a centred `OmdsLoadingState` and disables
/// the tap. Note what goes with it — the camera glyph AND the label — leaving a
/// box with no visible indication of which slot is busy. The `Semantics` label
/// is still attached, so this reads worse for a sighted user than for a screen
/// reader.
@JeebPreview(group: 'kyc', name: 'Capturing · first capture', size: _tileBox)
Widget kycCaptureTileCapturing() => _hosted(
      label: _frontLabel,
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
@JeebPreview(group: 'kyc', name: 'Retake in flight · photo hidden', size: _tileBox)
Widget kycCaptureTileRetakeInFlight() => _hosted(
      label: _backLabel,
      photo: _attachment('kyc-id-back', _decodablePng),
      isProcessing: true,
      captureCtaSemantic: 'Retake',
    );

/// The captured tile carrying its real Arabic label (`kycSelfieStepTitle` =
/// التقط صورة شخصية) instead of the English one — the longest-plausible-content
/// state, and the one that breaks.
///
/// Two reasons this preview exists. First, [label] arrives as a plain [String]
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
@JeebPreview(group: 'kyc', name: 'Captured · Arabic label', size: _tileBox)
Widget kycCaptureTileArabicLabel() => _hosted(
      label: _selfieLabelArabic,
      photo: _attachment('kyc-selfie', _decodablePng),
      captureCtaSemantic: 'إعادة التقاط الصورة الشخصية',
    );
