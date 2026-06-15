import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// A captured audio clip held in memory between recording and upload.
///
/// The bytes live in RAM because the MVP voice flow doesn't persist drafts —
/// the user records, optionally plays back, and either sends or discards. Once
/// the cubit transitions to `sent` the clip is dropped from state.
///
/// [sourcePath] is the on-device file the platform recorder wrote the clip to,
/// when one exists. The real [VoicePlayer] streams playback directly from this
/// path (cheaper than decoding [bytes] in RAM), and the real [VoiceRecorder]
/// deletes the file when the clip is discarded. It is null for in-memory clips
/// produced by [FakeVoiceRecorder], so it stays a pure-bytes value for tests.
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

  /// Absolute path to the recorded file on disk, or null for in-memory clips.
  final String? sourcePath;

  @override
  List<Object?> get props => [bytes.length, duration, mimeType, sourcePath];
}
