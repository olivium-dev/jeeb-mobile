import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/photo_attachment.dart';
import '../domain/photo_picker_service.dart';

/// Real [PhotoPickerService] over the `image_picker` plugin (JEBV4-13 — the
/// profile-edit "Change avatar" CTA shipped with `onTap: () {}` because no
/// platform picker adapter existed; only [StubPhotoPickerService] did).
///
/// Failure mapping honours the port contract:
///   * user backs out (plugin returns null)      → [PhotoPickFailure.cancelled]
///   * `*_access_denied` platform codes          → [PhotoPickFailure.permissionDenied]
///   * anything else (no camera, unreadable file) → [PhotoPickFailure.unavailable]
class ImagePickerPhotoPickerService implements PhotoPickerService {
  ImagePickerPhotoPickerService({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<RawPhoto> pickFromCamera() =>
      _pick(ImageSource.camera, PhotoSource.camera);

  @override
  Future<RawPhoto> pickFromGallery() =>
      _pick(ImageSource.gallery, PhotoSource.gallery);

  Future<RawPhoto> _pick(ImageSource source, PhotoSource tag) async {
    final XFile? file;
    try {
      file = await _picker.pickImage(source: source);
    } on PlatformException catch (e) {
      throw PhotoPickException(_mapPlatformCode(e.code));
    } catch (_) {
      throw const PhotoPickException(PhotoPickFailure.unavailable);
    }
    if (file == null) {
      throw const PhotoPickException(PhotoPickFailure.cancelled);
    }
    try {
      return RawPhoto(bytes: await file.readAsBytes(), source: tag);
    } catch (_) {
      throw const PhotoPickException(PhotoPickFailure.unavailable);
    }
  }

  PhotoPickFailure _mapPlatformCode(String code) {
    // image_picker surfaces permission denials as `camera_access_denied` /
    // `photo_access_denied` (+ `_permanently` variants on Android).
    if (code.contains('access_denied')) {
      return PhotoPickFailure.permissionDenied;
    }
    return PhotoPickFailure.unavailable;
  }
}
