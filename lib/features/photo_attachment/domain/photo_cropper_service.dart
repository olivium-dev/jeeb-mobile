import 'dart:typed_data';

/// Port for the square-crop step between pick and compress (F5). Reference
/// pattern only (rahmah-fe's `image_cropper` square-first config) — no
/// borrowed keys/config.
abstract class PhotoCropperService {
  /// Returns the cropped bytes, or null when the user cancels the crop UI —
  /// callers must treat that the same as cancelling the pick itself.
  Future<Uint8List?> crop(Uint8List bytes);
}
