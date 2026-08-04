import 'package:equatable/equatable.dart';

import '../data/voice_recording_repository.dart';
import '../domain/voice_clip.dart';

enum VoiceRecordingPhase { idle, recording, recorded, playing, sending, sent }

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

  static const Duration maxDuration = Duration(seconds: 60);

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
  bool get hasUploadFailure =>
      error == VoiceRecordingError.uploadNetwork ||
      error == VoiceRecordingError.uploadServer ||
      error == VoiceRecordingError.uploadUnknown;
  bool get hasClip =>
      clip != null &&
      (phase == VoiceRecordingPhase.recorded ||
          phase == VoiceRecordingPhase.playing ||
          phase == VoiceRecordingPhase.sending);

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
