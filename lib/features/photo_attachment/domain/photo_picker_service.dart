import 'dart:typed_data';

import 'photo_attachment.dart';


class RawPhoto {
  const RawPhoto({required this.bytes, required this.source});

  final Uint8List bytes;
  final PhotoSource source;
}




enum PhotoPickFailure {
  
  cancelled,

  
  
  permissionDenied,

  
  unavailable,
}




class PhotoPickException implements Exception {
  const PhotoPickException(this.failure);

  final PhotoPickFailure failure;

  @override
  String toString() => 'PhotoPickException(${failure.name})';
}




abstract class PhotoPickerService {
  
  
  
  
  Future<RawPhoto> pickFromCamera();

  
  
  Future<RawPhoto> pickFromGallery();
}
