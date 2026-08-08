import 'dart:io';
import 'dart:typed_data';

import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/photo_cropper_service.dart';

/// `image_cropper`-backed [PhotoCropperService]. The plugin crops from a file
/// path, so this round-trips the picked bytes through a temp-dir scratch file.
class ImageCropperPhotoCropperService implements PhotoCropperService {
  ImageCropperPhotoCropperService({ImageCropper? cropper})
      : _cropper = cropper ?? ImageCropper();

  final ImageCropper _cropper;

  static const int _compressQuality = 85;

  @override
  Future<Uint8List?> crop(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final source = File(
      '${dir.path}/profile_avatar_source_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await source.writeAsBytes(bytes, flush: true);
    try {
      final cropped = await _cropper.cropImage(
        sourcePath: source.path,
        // Square-first crop shape (pattern only).
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: _compressQuality,
        uiSettings: [
          AndroidUiSettings(lockAspectRatio: true),
          IOSUiSettings(aspectRatioLockEnabled: true, resetAspectRatioEnabled: false),
        ],
      );
      if (cropped == null) return null;
      return await File(cropped.path).readAsBytes();
    } finally {
      if (await source.exists()) await source.delete();
    }
  }
}
