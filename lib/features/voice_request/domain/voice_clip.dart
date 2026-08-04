import 'dart:typed_data';

import 'package:equatable/equatable.dart';

class VoiceClip extends Equatable {
  const VoiceClip({
    required this.bytes,
    required this.duration,
    this.mimeType = 'audio/m4a',
    this.sourcePath,
  });

  final Uint8List bytes;
  final Duration duration;
  final String mimeType;

  final String? sourcePath;

  @override
  List<Object?> get props => [bytes.length, duration, mimeType, sourcePath];
}
