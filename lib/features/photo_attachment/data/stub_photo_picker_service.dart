import 'dart:typed_data';

import '../domain/photo_attachment.dart';
import '../domain/photo_picker_service.dart';

/// In-memory picker used by the MVP build and by widget tests.
///
/// Returns synthetic byte payloads (a single repeated byte) so the UI can be
/// exercised end-to-end without `image_picker`, runtime permissions, or a
/// real camera. The real platform binding lands with the camera plugin task;
/// at that point this implementation stays as the default `PhotoPickerService`
/// for tests and Maestro flows.
class StubPhotoPickerService implements PhotoPickerService {
  StubPhotoPickerService({
    this.cameraPayload,
    this.galleryPayload,
    this.cameraFailure,
    this.galleryFailure,
  });

  /// Bytes returned from [pickFromCamera] when no failure is configured.
  /// Defaults to a 1 MB block so the compression path is exercised but the
  /// payload fits under the 2 MB ceiling without iteration.
  final Uint8List? cameraPayload;

  /// Bytes returned from [pickFromGallery] when no failure is configured.
  /// Defaults to a 3 MB block so the gallery path exercises the compressor.
  final Uint8List? galleryPayload;

  /// When set, [pickFromCamera] throws [PhotoPickException] with this failure.
  final PhotoPickFailure? cameraFailure;

  /// When set, [pickFromGallery] throws [PhotoPickException] with this failure.
  final PhotoPickFailure? galleryFailure;

  @override
  Future<RawPhoto> pickFromCamera() async {
    if (cameraFailure != null) {
      throw PhotoPickException(cameraFailure!);
    }
    final bytes = cameraPayload ?? _filled(1 * 1024 * 1024, 0xC0);
    return RawPhoto(bytes: bytes, source: PhotoSource.camera);
  }

  @override
  Future<RawPhoto> pickFromGallery() async {
    if (galleryFailure != null) {
      throw PhotoPickException(galleryFailure!);
    }
    final bytes = galleryPayload ?? _filled(3 * 1024 * 1024, 0xA0);
    return RawPhoto(bytes: bytes, source: PhotoSource.gallery);
  }

  static Uint8List _filled(int length, int byte) {
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      out[i] = byte & 0xFF;
    }
    return out;
  }
}
