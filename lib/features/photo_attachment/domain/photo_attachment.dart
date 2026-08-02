import 'dart:typed_data';

import 'package:equatable/equatable.dart';



enum PhotoSource { camera, gallery }






class PhotoAttachment extends Equatable {
  const PhotoAttachment({
    required this.id,
    required this.bytes,
    required this.originalSizeBytes,
    required this.source,
  });

  
  
  
  final String id;

  
  
  final Uint8List bytes;

  
  
  final int originalSizeBytes;

  final PhotoSource source;

  int get sizeBytes => bytes.length;

  @override
  List<Object?> get props => [id, bytes.length, originalSizeBytes, source];
}
