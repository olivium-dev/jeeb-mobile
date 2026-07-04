import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/photo_attachment.dart';
import '../domain/photo_picker_service.dart';

/// Real device [PhotoPickerService] backed by the `image_picker` plugin
/// (pubspec `image_picker: ^1.1.2` — declared since T-mobile-040 but never
/// bound until JEBV4-111).
///
/// Before this binding existed, every capture surface (delivery-man onboarding
/// photo step, the KYC wizard's ID-front/ID-back/selfie tiles, JM-051 proof
/// photos) silently fell back to [StubPhotoPickerService], whose synthetic
/// byte blocks are not decodable images — the UI rendered
/// "Exception: Invalid image data" instead of opening a camera.
///
/// Contract (see [PhotoPickerService]):
///  • user backs out          → [PhotoPickException] ([PhotoPickFailure.cancelled])
///  • OS permission denied    → [PhotoPickException] ([PhotoPickFailure.permissionDenied])
///  • hardware/IO failure     → [PhotoPickException] ([PhotoPickFailure.unavailable])
///
/// Captures are down-scaled at the source (maxWidth 1920, quality 85) so the
/// downstream [HalvingPhotoCompressor] rarely has to iterate to fit the 2 MB
/// ceiling.
class ImagePickerPhotoPickerService implements PhotoPickerService {
  ImagePickerPhotoPickerService({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  static const double _maxWidth = 1920;
  static const int _imageQuality = 85;

  @override
  Future<RawPhoto> pickFromCamera() =>
      _pick(ImageSource.camera, PhotoSource.camera);

  @override
  Future<RawPhoto> pickFromGallery() =>
      _pick(ImageSource.gallery, PhotoSource.gallery);

  Future<RawPhoto> _pick(ImageSource source, PhotoSource origin) async {
    final XFile? file;
    try {
      file = await _picker.pickImage(
        source: source,
        maxWidth: _maxWidth,
        imageQuality: _imageQuality,
        requestFullMetadata: false,
      );
    } on PlatformException catch (e) {
      throw PhotoPickException(_mapPlatformFailure(e));
    } catch (_) {
      throw const PhotoPickException(PhotoPickFailure.unavailable);
    }
    // The plugin returns null when the user dismisses the camera/gallery.
    if (file == null) {
      throw const PhotoPickException(PhotoPickFailure.cancelled);
    }
    try {
      final bytes = await file.readAsBytes();
      return RawPhoto(bytes: bytes, source: origin);
    } catch (_) {
      throw const PhotoPickException(PhotoPickFailure.unavailable);
    }
  }

  /// image_picker surfaces OS denials as PlatformException codes
  /// `camera_access_denied` / `photo_access_denied` (and `camera_access_restricted`
  /// on managed devices); everything else is the hardware/IO bucket.
  PhotoPickFailure _mapPlatformFailure(PlatformException e) {
    final code = e.code.toLowerCase();
    if (code.contains('access_denied') || code.contains('access_restricted')) {
      return PhotoPickFailure.permissionDenied;
    }
    return PhotoPickFailure.unavailable;
  }
}
