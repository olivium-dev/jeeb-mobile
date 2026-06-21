import 'package:image_picker/image_picker.dart';

import '../domain/photo_attachment.dart';
import '../domain/photo_picker_service.dart';

/// Real device-backed [PhotoPickerService] (JM-051 proof-photo + JM-039
/// onboarding / KYC identity capture). Wraps `image_picker` so the cubits,
/// screens, and tests never import the plugin directly — the in-memory
/// [StubPhotoPickerService] remains the unit-test / Maestro seam.
///
/// Maps the plugin's `null` (user-cancelled) onto
/// [PhotoPickFailure.cancelled] and any platform error onto
/// [PhotoPickFailure.unavailable], matching the exception contract the
/// [PhotoPickerService] interface documents (the cubit add() flow is a single
/// try/catch). The OS permission-denied path surfaces as a platform error too;
/// `image_picker` does not distinguish it from "unavailable" on the returned
/// `XFile`, so it degrades to [PhotoPickFailure.unavailable] (the screen still
/// renders the generic capture-failed copy rather than crashing).
///
/// Images are requested at a bounded resolution + JPEG quality so the upload
/// payload stays small without a separate compression pass (the proof-photo /
/// identity flows do not need full-resolution originals).
class ImagePickerPhotoPickerService implements PhotoPickerService {
  ImagePickerPhotoPickerService({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Cap the longest edge so a 12MP phone shot doesn't upload a multi-MB blob.
  static const double _maxEdge = 1600;

  /// JPEG quality (0-100). 80 keeps proof/identity photos legible at a
  /// fraction of the original size.
  static const int _quality = 80;

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
        maxWidth: _maxEdge,
        maxHeight: _maxEdge,
        imageQuality: _quality,
      );
    } catch (_) {
      // Camera unavailable, permission denied, file unreadable, etc. — the
      // interface buckets all platform faults under `unavailable`.
      throw const PhotoPickException(PhotoPickFailure.unavailable);
    }
    if (file == null) {
      // User backed out without choosing — the documented cancelled contract.
      throw const PhotoPickException(PhotoPickFailure.cancelled);
    }
    final bytes = await file.readAsBytes();
    return RawPhoto(bytes: bytes, source: origin);
  }
}
