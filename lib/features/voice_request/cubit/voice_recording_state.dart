import 'package:equatable/equatable.dart';

import '../data/voice_recording_repository.dart';
import '../domain/voice_clip.dart';

/// Discrete phases of the voice-request flow. Drives which controls the
/// screen renders (mic vs. playback row, send button enable, error banner).
enum VoiceRecordingPhase {
  idle,
  recording,
  recorded,
  playing,
  sending,
  sent,
}

/// Reasons surfaced to the user when something goes wrong. One-shot — the
/// view clears it via [VoiceRecordingCubit.acknowledgeError] so the same copy
/// doesn't re-render on every rebuild.
enum VoiceRecordingError {
  permissionDenied,
  recorderUnavailable,
  recorderFailed,
  tooShort,
  maxDurationReached,
  uploadNetwork,
  uploadServer,
  uploadUnknown,
}

class VoiceRecordingState extends Equatable {
  const VoiceRecordingState({
    this.phase = VoiceRecordingPhase.idle,
    this.elapsed = Duration.zero,
    this.playbackPosition = Duration.zero,
    this.clip,
    this.error,
    this.result,
  });

  /// Hard cap on a single voice request. The recorder is auto-stopped if the
  /// user keeps holding the button past this point and the cubit surfaces
  /// [VoiceRecordingError.maxDurationReached] so they know why.
  static const Duration maxDuration = Duration(seconds: 60);

  /// Minimum duration the cubit will accept before treating the recording as
  /// real audio. A shorter press is treated as a mis-tap — the clip is
  /// discarded and [VoiceRecordingError.tooShort] is raised.
  static const Duration minSendableDuration = Duration(seconds: 1);

  final VoiceRecordingPhase phase;
  final Duration elapsed;
  final Duration playbackPosition;
  final VoiceClip? clip;
  final VoiceRecordingError? error;
  final TranscriptionResult? result;

  bool get isRecording => phase == VoiceRecordingPhase.recording;
  bool get isPlaying => phase == VoiceRecordingPhase.playing;
  bool get isSending => phase == VoiceRecordingPhase.sending;
  bool get hasClip =>
      clip != null &&
      (phase == VoiceRecordingPhase.recorded ||
          phase == VoiceRecordingPhase.playing ||
          phase == VoiceRecordingPhase.sending);

  /// Whether the captured clip meets the minimum length to be uploaded.
  bool get canSend => hasClip && clip!.duration >= minSendableDuration;

  VoiceRecordingState copyWith({
    VoiceRecordingPhase? phase,
    Duration? elapsed,
    Duration? playbackPosition,
    VoiceClip? clip,
    bool clearClip = false,
    VoiceRecordingError? error,
    bool clearError = false,
    TranscriptionResult? result,
    bool clearResult = false,
  }) {
    return VoiceRecordingState(
      phase: phase ?? this.phase,
      elapsed: elapsed ?? this.elapsed,
      playbackPosition: playbackPosition ?? this.playbackPosition,
      clip: clearClip ? null : (clip ?? this.clip),
      error: clearError ? null : (error ?? this.error),
      result: clearResult ? null : (result ?? this.result),
    );
  }

  @override
  List<Object?> get props => [
        phase,
        elapsed,
        playbackPosition,
        clip,
        error,
        result,
      ];
}
