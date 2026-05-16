import 'dart:typed_data';

import 'voice_clip.dart';

/// Reason a recorder rejected an operation. The cubit maps these onto user-
/// facing copy (mic permission, hardware unavailable, generic failure).
enum VoiceRecorderFailure { permissionDenied, unavailable, unknown }

/// Thrown by [VoiceRecorder] implementations when [start] or [stop] cannot
/// complete. The cubit catches it and emits the matching error state.
class VoiceRecorderException implements Exception {
  const VoiceRecorderException(this.failure);
  final VoiceRecorderFailure failure;
  @override
  String toString() => 'VoiceRecorderException($failure)';
}

/// Side-channel for the cubit to capture microphone audio. The MVP cubit ships
/// with [FakeVoiceRecorder] so the screen can run without platform plumbing;
/// production wires a `record`-package-backed implementation later.
abstract class VoiceRecorder {
  Future<void> start();

  /// Stops recording and returns the captured clip. [recordedDuration] is the
  /// elapsed time the cubit measured — implementations are free to clamp to a
  /// shorter value if the platform reports a truncated buffer.
  Future<VoiceClip> stop({required Duration recordedDuration});

  /// Aborts an in-flight recording without producing a clip. Safe to call
  /// while idle.
  Future<void> cancel();
}

/// In-memory recorder used during the UI-only milestone and unit tests. Hands
/// back deterministic bytes so widget/cubit tests can assert on the payload
/// shape without spinning up the platform recorder.
class FakeVoiceRecorder implements VoiceRecorder {
  FakeVoiceRecorder({
    Uint8List? payload,
    this.startFailure,
    this.stopFailure,
  }) : _payload = payload ?? Uint8List.fromList(List.filled(2048, 0x55));

  /// Optional failure injected on [start] — lets tests cover the permission
  /// denial path without subclassing.
  final VoiceRecorderFailure? startFailure;

  /// Optional failure injected on [stop].
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
}
