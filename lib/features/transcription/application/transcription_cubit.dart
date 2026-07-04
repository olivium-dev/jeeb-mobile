import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/transcript_audio_player.dart';
import '../domain/voice_clip.dart';

/// Why the transcription is not directly reviewable as final text.
///
/// `none` is the happy path (we have transcribed text). `queued` means the
/// upload succeeded but the transcription is still pending — the user can type
/// their request to keep moving. `failed` means the transcription call errored;
/// the screen offers a retry plus a manual-entry fallback.
enum TranscriptionStatus { ready, queued, failed }

/// Failure reason for the `failed` status, used to pick the banner copy.
enum TranscriptionFailure { none, network, payloadTooLarge, generic }

/// State for the transcription-review screen.
///
/// Holds the editable [text], the [status] that drives the empty/failed
/// banners, the edit-mode flag, and the audio-playback sub-state (whether the
/// original recording is playing and where the playhead is).
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

  /// JEBV4-13: the recorder's on-device file, preferred for replay over
  /// [audioPath] (which is the gateway `audioId`, not a playable path).
  final String? localAudioPath;

  final Duration audioDuration;
  final bool isPlaying;
  final Duration playbackPosition;

  /// True when there is a real recording to replay (a non-empty path).
  bool get hasAudio => (audioPath ?? '').isNotEmpty;

  /// The path playback actually uses: prefer the on-device recorder file
  /// (JEBV4-13 — the gateway `audioId` in [audioPath] is not locally
  /// playable), falling back to [audioPath] for callers that hand over a
  /// real path/URL there.
  String? get playbackPath =>
      (localAudioPath ?? '').isNotEmpty ? localAudioPath : audioPath;

  /// True when the user has at least some text to send forward. Confirm is
  /// gated on this so we never push an empty request into the summary step.
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

/// Drives the transcription-review screen: seeds from the [VoiceClip] handed
/// over by the voice composer, lets the user edit the machine transcription,
/// replays the original recording, and exposes a retry path for the
/// failed/queued states. Pure presentation logic — navigation is owned by the
/// screen's `onConfirm` callback so the cubit stays widget- and router-free.
class TranscriptionCubit extends Cubit<TranscriptionState> {
  TranscriptionCubit({TranscriptAudioPlayer? player})
      : _player = player ?? const NoopTranscriptAudioPlayer(),
        super(const TranscriptionState());

  final TranscriptAudioPlayer _player;

  /// Seeds the cubit from the clip handed over by the voice composer. A
  /// non-empty [VoiceClip.transcript] is the happy path; a null/empty
  /// transcript lands on the `queued` status so the user can type instead.
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

  /// Marks the transcription as failed with [failure]; keeps any audio so the
  /// user can still replay and type a manual description.
  void markFailed(TranscriptionFailure failure) {
    emit(state.copyWith(
      status: TranscriptionStatus.failed,
      failure: failure,
      isEditing: false,
    ));
  }

  void startEditing() => emit(state.copyWith(isEditing: true));

  void updateText(String text) => emit(state.copyWith(text: text));

  /// Commits the edited [text] and leaves edit mode. Empty edits drop back to
  /// the `queued` status so the empty-state hint reappears.
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

  /// Toggles playback of the original recording. No-op when there is no audio.
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
      // JEBV4-13: an unplayable source (e.g. a server audioId with no local
      // file on a cold deep link) must never crash the review screen — reset
      // the toggle instead of leaving a stuck "playing" state.
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
