import 'dart:typed_data';

import '../domain/photo_attachment.dart';
import '../domain/photo_picker_service.dart';








class StubPhotoPickerService implements PhotoPickerService {
  StubPhotoPickerService({
    this.cameraPayload,
    this.galleryPayload,
    this.cameraFailure,
    this.galleryFailure,
  });

  
  
  
  final Uint8List? cameraPayload;

  
  
  final Uint8List? galleryPayload;

  
  final PhotoPickFailure? cameraFailure;

  
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
