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

  /// The transcribe call or its poll budget ran out — not a connectivity fault.
  uploadTimeout,

  /// 413: the clip is too long/large to accept. Terminal — re-record only.
  uploadTooLarge,

  /// 415: the container/codec is not accepted. Terminal — re-record only.
  uploadUnsupported,

  /// Transcription is down (502/503/504). Retrying later can win.
  uploadUnavailable,
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
      error == VoiceRecordingError.uploadUnknown ||
      error == VoiceRecordingError.uploadTimeout ||
      error == VoiceRecordingError.uploadTooLarge ||
      error == VoiceRecordingError.uploadUnsupported ||
      error == VoiceRecordingError.uploadUnavailable;

  /// Terminal upload kinds: no retry of the SAME clip can ever succeed.
  bool get hasTerminalUploadFailure =>
      error == VoiceRecordingError.uploadTooLarge ||
      error == VoiceRecordingError.uploadUnsupported;
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
