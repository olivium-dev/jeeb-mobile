import 'dart:typed_data';

/// Port for the square-crop step between pick and compress (F5).
abstract class PhotoCropperService {
  /// Returns the cropped bytes, or null when the user cancels the crop UI.
  Future<Uint8List?> crop(Uint8List bytes);
}
