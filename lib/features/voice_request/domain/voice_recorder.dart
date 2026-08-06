import 'dart:typed_data';

import 'voice_clip.dart';

enum VoiceRecorderFailure { permissionDenied, unavailable, unknown }

class VoiceRecorderException implements Exception {
  const VoiceRecorderException(this.failure);
  final VoiceRecorderFailure failure;
  @override
  String toString() => 'VoiceRecorderException($failure)';
}

abstract class VoiceRecorder {
  Future<void> start();

  Future<VoiceClip> stop({required Duration recordedDuration});

  Future<void> cancel();

  /// Deletes a completed clip only when this recorder owns its source file.
  Future<void> deleteOwnedClip(VoiceClip clip);
}

class FakeVoiceRecorder implements VoiceRecorder {
  FakeVoiceRecorder({Uint8List? payload, this.startFailure, this.stopFailure})
    : _payload = payload ?? Uint8List.fromList(List.filled(2048, 0x55));

  final VoiceRecorderFailure? startFailure;

  final VoiceRecorderFailure? stopFailure;

  final Uint8List _payload;
  bool _recording = false;

  bool get isRecording => _recording;

  @override
  Future<void> start() async {
    if (startFailure != null) {
      throw VoiceRecorderException(startFailure!);
    }
    _recording = true;
  }

  @override
  Future<VoiceClip> stop({required Duration recordedDuration}) async {
    if (stopFailure != null) {
      _recording = false;
      throw VoiceRecorderException(stopFailure!);
    }
    _recording = false;
    return VoiceClip(bytes: _payload, duration: recordedDuration);
  }

  @override
  Future<void> cancel() async {
    _recording = false;
  }

  @override
  Future<void> deleteOwnedClip(VoiceClip clip) async {}
}
