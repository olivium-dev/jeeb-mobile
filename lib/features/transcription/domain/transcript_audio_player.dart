import 'dart:async';

/// Playback side-channel for the transcription-review screen.
///
/// The voice composer (T-MOB-011) records to a file and the upload echoes back
/// an `audioId`; on this screen the user can replay the *original recording*
/// while reviewing the machine transcription. The composer's [VoicePlayer]
/// (`voice_request/domain/voice_player.dart`) plays from raw `bytes`, which are
/// not available here — the transcription screen only receives a path/id via
/// [VoiceClip.audioPath]. This port therefore plays from a path so the feature
/// stays decoupled from the recorder's in-memory clip shape.
///
/// Production wires a `just_audio`/`audioplayers`-backed implementation; the
/// cubit ships with [NoopTranscriptAudioPlayer] so the screen degrades to a
/// disabled control when no real backend is registered, and widget/cubit tests
/// inject [FakeTranscriptAudioPlayer] to drive the play → position → completed
/// transitions deterministically.
abstract class TranscriptAudioPlayer {
  /// Starts playback of the audio at [path]. [onPosition] is invoked as
  /// playback advances; [onCompleted] fires exactly once at the end.
  Future<void> play(
    String path, {
    required void Function(Duration) onPosition,
    required void Function() onCompleted,
  });

  Future<void> pause();

  Future<void> stop();

  Future<void> dispose();
}

/// Inert player used in release when no audio backend is registered. Every call
/// is a no-op so the screen renders a (disabled) playback control without
/// crashing on a missing registration — the transcription text is still fully
/// reviewable and editable.
class NoopTranscriptAudioPlayer implements TranscriptAudioPlayer {
  const NoopTranscriptAudioPlayer();

  @override
  Future<void> play(
    String path, {
    required void Function(Duration) onPosition,
    required void Function() onCompleted,
  }) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

/// In-memory player for tests. Records the calls so tests can assert which
/// methods fired, and exposes [emitPosition] / [emitCompleted] hooks to replay
/// position updates without a platform stream.
class FakeTranscriptAudioPlayer implements TranscriptAudioPlayer {
  int playCalls = 0;
  int pauseCalls = 0;
  int stopCalls = 0;
  String? lastPath;
  void Function(Duration)? _onPosition;
  void Function()? _onCompleted;

  @override
  Future<void> play(
    String path, {
    required void Function(Duration) onPosition,
    required void Function() onCompleted,
  }) async {
    playCalls++;
    lastPath = path;
    _onPosition = onPosition;
    _onCompleted = onCompleted;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    _onPosition = null;
    _onCompleted = null;
  }

  @override
  Future<void> dispose() async {
    _onPosition = null;
    _onCompleted = null;
  }

  /// Test hook — pretend the player advanced to [position].
  void emitPosition(Duration position) => _onPosition?.call(position);

  /// Test hook — pretend playback finished.
  void emitCompleted() => _onCompleted?.call();
}
