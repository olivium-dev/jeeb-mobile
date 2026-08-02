import 'dart:typed_data';

abstract class PhotoCompressor {

  static const int maxSizeBytes = 2 * 1024 * 1024;

  Future<Uint8List> compress(Uint8List bytes);
}

class HalvingPhotoCompressor implements PhotoCompressor {
  const HalvingPhotoCompressor();

  @override
  Future<Uint8List> compress(Uint8List bytes) async {
    if (bytes.length <= PhotoCompressor.maxSizeBytes) return bytes;
    var current = bytes;
    while (current.length > PhotoCompressor.maxSizeBytes) {
      final next = Uint8List(current.length ~/ 2);

      for (var i = 0; i < next.length; i++) {
        next[i] = current[i * 2];
      }
      current = next;
    }
    return current;
  }
}

class PassthroughPhotoCompressor implements PhotoCompressor {
  const PassthroughPhotoCompressor();

  @override
  Future<Uint8List> compress(Uint8List bytes) async => bytes;
}
