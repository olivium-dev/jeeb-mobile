import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// A captured audio clip held in memory between recording and upload.
///
/// The bytes live in RAM because the MVP voice flow doesn't persist drafts —
/// the user records, optionally plays back, and either sends or discards. Once
/// the cubit transitions to `sent` the clip is dropped from state.
class VoiceClip extends Equatable {
  const VoiceClip({
    required this.bytes,
    required this.duration,
    this.mimeType = 'audio/m4a',
  });

  final Uint8List bytes;
  final Duration duration;
  final String mimeType;

  @override
  List<Object?> get props => [bytes.length, duration, mimeType];
}
