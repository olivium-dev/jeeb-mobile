import 'dart:async';
import 'dart:ui' show TextRange;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/transcript_audio_player.dart';
import '../domain/voice_clip.dart';

/// Why the transcription is not directly reviewable as final text.
///
/// `none` is the happy path (we have transcribed text). `queued` means the
/// upload succeeded but the transcription is still pending — the user can type
/// their request to keep moving. `failed` means transcription errored or stayed
/// queued past its bounded processing window; the screen offers a retry plus a
/// manual-entry fallback.
enum TranscriptionStatus { ready, queued, failed }

/// Failure reason for the `failed` status, used to pick the banner copy.
enum TranscriptionFailure { none, network, payloadTooLarge, generic, timedOut }

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
    this.language,
    this.queuedReason,
    this.editRange,
    this.appliedQuickAdds = const <String>{},
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

  /// The gateway's detected language code (`ar-LB`, `ar`, `en`), seeded from
  /// [VoiceClip.language]. Null until the voice_request lane forwards it — the
  /// chip then renders nothing rather than guessing from the UI locale.
  final String? language;

  /// The gateway's queued reason (e.g. `circuit_open`, `exhausted_retries`,
  /// `queued_by_owner`) surfaced from the clip instead of being silently
  /// dropped; informational — never rendered as raw untranslated server text
  /// to the user.
  final String? queuedReason;

  /// Which slice of [text] the editor should pre-select when edit mode opens.
  /// Set by the tap-a-word affordance; null for the "Edit all" entry point.
  final TextRange? editRange;

  /// Ids of the quick-add scaffolds already appended, so each chip fires once
  /// and then leaves the row.
  final Set<String> appliedQuickAdds;

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
    String? language,
    String? queuedReason,
    TextRange? editRange,
    Set<String>? appliedQuickAdds,
    bool clearEditRange = false,
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
      language: language ?? this.language,
      queuedReason: queuedReason ?? this.queuedReason,
      // `?? this.editRange` can never null it out, so the reset is explicit.
      editRange: clearEditRange ? null : (editRange ?? this.editRange),
      appliedQuickAdds: appliedQuickAdds ?? this.appliedQuickAdds,
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
        language,
        queuedReason,
        editRange,
        appliedQuickAdds,
      ];
}

/// Drives the transcription-review screen: seeds from the [VoiceClip] handed
/// over by the voice composer, lets the user edit the machine transcription,
/// replays the original recording, and exposes a retry path for the
/// failed/queued states. Pure presentation logic — navigation is owned by the
/// screen's `onConfirm` callback so the cubit stays widget- and router-free.
class TranscriptionCubit extends Cubit<TranscriptionState> {
  TranscriptionCubit({
    TranscriptAudioPlayer? player,
    Duration queuedTimeout = const Duration(seconds: 45),
  })  : _player = player ?? const NoopTranscriptAudioPlayer(),
        _queuedTimeout = queuedTimeout,
        super(const TranscriptionState());

  final TranscriptAudioPlayer _player;
  final Duration _queuedTimeout;
  Timer? _queuedTimer;

  /// Seeds the cubit from the clip handed over by the voice composer. A
  /// non-empty [VoiceClip.transcript] is the happy path; a null/empty
  /// transcript lands on the `queued` status so the user can type instead.
  void seedFromClip(VoiceClip clip) {
    _queuedTimer?.cancel();
    final transcript = clip.transcript?.trim() ?? '';
    final status = transcript.isEmpty
        ? TranscriptionStatus.queued
        : TranscriptionStatus.ready;
    emit(
      TranscriptionState(
        text: transcript,
        status: status,
        audioPath: clip.audioPath,
        localAudioPath: clip.localAudioPath,
        audioDuration: Duration(milliseconds: clip.durationMs),
        language: clip.language,
        queuedReason: clip.reason,
      ),
    );
    if (status == TranscriptionStatus.queued) {
      _queuedTimer = Timer(_queuedTimeout, _onQueuedTimeout);
    }
  }

  void _onQueuedTimeout() {
    if (isClosed) return;
    if (state.status != TranscriptionStatus.queued) return;
    markFailed(TranscriptionFailure.timedOut);
  }

  /// Marks the transcription as failed with [failure], including from the
  /// production queued-timeout path; keeps any audio so the user can still
  /// replay and type a manual description.
  void markFailed(TranscriptionFailure failure) {
    _queuedTimer?.cancel();
    emit(state.copyWith(
      status: TranscriptionStatus.failed,
      failure: failure,
      isEditing: false,
    ));
  }

  void startEditing() => emit(state.copyWith(isEditing: true));

  /// Opens the editor with [range] pre-selected — the "tap the word you want
  /// to fix" affordance, so a one-word correction is not a full retype.
  void startEditingWord(TextRange range) =>
      emit(state.copyWith(isEditing: true, editRange: range));

  /// Appends a labelled scaffold (`Quantity: `) to the request and drops the
  /// user into the editor with the caret after it. Fires once per [id]: the
  /// chip leaves the row, so a double-tap cannot duplicate the fragment.
  void applyQuickAdd(String id, String fragment) {
    if (state.appliedQuickAdds.contains(id)) return;
    final newText = state.text.isEmpty ? fragment : '${state.text}\n$fragment';
    final status = newText.trim().isEmpty
        ? TranscriptionStatus.queued
        : TranscriptionStatus.ready;
    _queuedTimer?.cancel();
    emit(state.copyWith(
      text: newText,
      isEditing: true,
      editRange: TextRange.collapsed(newText.length),
      appliedQuickAdds: <String>{...state.appliedQuickAdds, id},
      status: status,
    ));
    if (status == TranscriptionStatus.queued) {
      _queuedTimer = Timer(_queuedTimeout, _onQueuedTimeout);
    }
  }

  void updateText(String text) => emit(state.copyWith(text: text));

  /// Commits the edited [text] and leaves edit mode. Empty edits drop back to
  /// the `queued` status so the empty-state hint reappears.
  void confirmEdit(String text) {
    final trimmed = text.trim();
    final status = trimmed.isEmpty
        ? TranscriptionStatus.queued
        : TranscriptionStatus.ready;
    _queuedTimer?.cancel();
    emit(state.copyWith(
      text: trimmed,
      isEditing: false,
      clearEditRange: true,
      status: status,
    ));
    if (status == TranscriptionStatus.queued) {
      _queuedTimer = Timer(_queuedTimeout, _onQueuedTimeout);
    }
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

  /// Moves the playhead from the scrubber knob. No-op without a playable
  /// source (same guard as [togglePlayback]); the player call degrades the
  /// same way, because a knob drag must never crash the review screen.
  Future<void> seekTo(Duration position) async {
    final path = state.playbackPath;
    if (path == null || path.isEmpty) return;
    final clamped = position < Duration.zero
        ? Duration.zero
        : (position > state.audioDuration ? state.audioDuration : position);
    emit(state.copyWith(playbackPosition: clamped));
    try {
      await _player.seek(clamped);
    } on Object {
      // The optimistic position already shipped; an unplayable source just
      // means the knob moved and the audio did not.
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
    _queuedTimer?.cancel();
    await _player.stop();
    await _player.dispose();
    return super.close();
  }
}
