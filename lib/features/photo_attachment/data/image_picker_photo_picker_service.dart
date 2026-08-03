import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/photo_attachment.dart';
import '../domain/photo_picker_service.dart';

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

  PhotoPickFailure _mapPlatformFailure(PlatformException e) {
    final code = e.code.toLowerCase();
    if (code.contains('access_denied') || code.contains('access_restricted')) {
      return PhotoPickFailure.permissionDenied;
    }
    return PhotoPickFailure.unavailable;
  }
}
