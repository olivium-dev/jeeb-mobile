import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/transcript_audio_player.dart';
import '../domain/voice_clip.dart';

enum TranscriptionStatus { ready, queued, failed }

enum TranscriptionFailure { none, network, payloadTooLarge, generic }

class TranscriptionState extends Equatable {
  const TranscriptionState({
    this.text = '',
    this.status = TranscriptionStatus.ready,
    this.failure = TranscriptionFailure.none,
    this.isEditing = false,
    this.audioPath,
    this.localAudioPath,
    this.audioDuration = Duration.zero,
    this.isPlaying = false,
    this.playbackPosition = Duration.zero,
  });

  final String text;
  final TranscriptionStatus status;
  final TranscriptionFailure failure;
  final bool isEditing;
  final String? audioPath;

  final String? localAudioPath;

  final Duration audioDuration;
  final bool isPlaying;
  final Duration playbackPosition;

  bool get hasAudio => (audioPath ?? '').isNotEmpty;

  String? get playbackPath =>
      (localAudioPath ?? '').isNotEmpty ? localAudioPath : audioPath;

  bool get canConfirm => text.trim().isNotEmpty;

  TranscriptionState copyWith({
    String? text,
    TranscriptionStatus? status,
    TranscriptionFailure? failure,
    bool? isEditing,
    String? audioPath,
    String? localAudioPath,
    Duration? audioDuration,
    bool? isPlaying,
    Duration? playbackPosition,
  }) {
    return TranscriptionState(
      text: text ?? this.text,
      status: status ?? this.status,
      failure: failure ?? this.failure,
      isEditing: isEditing ?? this.isEditing,
      audioPath: audioPath ?? this.audioPath,
      localAudioPath: localAudioPath ?? this.localAudioPath,
      audioDuration: audioDuration ?? this.audioDuration,
      isPlaying: isPlaying ?? this.isPlaying,
      playbackPosition: playbackPosition ?? this.playbackPosition,
    );
  }

  @override
  List<Object?> get props => [
        text,
        status,
        failure,
        isEditing,
        audioPath,
        localAudioPath,
        audioDuration,
        isPlaying,
        playbackPosition,
      ];
}

class TranscriptionCubit extends Cubit<TranscriptionState> {
  TranscriptionCubit({TranscriptAudioPlayer? player})
      : _player = player ?? const NoopTranscriptAudioPlayer(),
        super(const TranscriptionState());

  final TranscriptAudioPlayer _player;

  void seedFromClip(VoiceClip clip) {
    final transcript = clip.transcript?.trim() ?? '';
    emit(
      TranscriptionState(
        text: transcript,
        status: transcript.isEmpty
            ? TranscriptionStatus.queued
            : TranscriptionStatus.ready,
        audioPath: clip.audioPath,
        localAudioPath: clip.localAudioPath,
        audioDuration: Duration(milliseconds: clip.durationMs),
      ),
    );
  }

  void markFailed(TranscriptionFailure failure) {
    emit(state.copyWith(
      status: TranscriptionStatus.failed,
      failure: failure,
      isEditing: false,
    ));
  }

  void startEditing() => emit(state.copyWith(isEditing: true));

  void updateText(String text) => emit(state.copyWith(text: text));

  void confirmEdit(String text) {
    final trimmed = text.trim();
    emit(state.copyWith(
      text: trimmed,
      isEditing: false,
      status: trimmed.isEmpty
          ? TranscriptionStatus.queued
          : TranscriptionStatus.ready,
    ));
  }

  Future<void> togglePlayback() async {
    final path = state.playbackPath;
    if (path == null || path.isEmpty) return;
    if (state.isPlaying) {
      await _player.pause();
      emit(state.copyWith(isPlaying: false));
      return;
    }
    final restart = state.playbackPosition >= state.audioDuration;
    emit(state.copyWith(
      isPlaying: true,
      playbackPosition: restart ? Duration.zero : state.playbackPosition,
    ));
    try {
      await _player.play(
        path,
        onPosition: _onPosition,
        onCompleted: _onCompleted,
      );
    } on Object {
      // file on a cold deep link) must never crash the review screen — reset
      emit(state.copyWith(isPlaying: false));
    }
  }

  void _onPosition(Duration position) {
    if (!state.isPlaying) return;
    final clamped =
        position > state.audioDuration ? state.audioDuration : position;
    emit(state.copyWith(playbackPosition: clamped));
  }

  void _onCompleted() {
    emit(state.copyWith(
      isPlaying: false,
      playbackPosition: state.audioDuration,
    ));
  }

  @override
  Future<void> close() async {
    await _player.stop();
    await _player.dispose();
    return super.close();
  }
}
