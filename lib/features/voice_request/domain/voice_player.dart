import 'voice_clip.dart';

/// Side-channel for the cubit to play back the captured clip before sending.
/// Production wires a `just_audio`-backed implementation; the MVP cubit ships
/// with [FakeVoicePlayer] so widget tests can drive playback transitions.
///
/// Position updates flow back to the cubit through the [onPosition] callback
/// supplied to [play] so the cubit can render the progress bar without owning
/// a platform stream. The cubit is responsible for stopping the playback when
/// the user discards the clip or sends.
abstract class VoicePlayer {
  /// Starts playback of [clip]. [onPosition] is invoked as playback advances
  /// (typically once per ~100ms); [onCompleted] fires exactly once when the
  /// clip reaches the end.
  Future<void> play(
    VoiceClip clip, {
    required void Function(Duration) onPosition,
    required void Function() onCompleted,
    Duration startAt = Duration.zero,
  });

  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> stop();
}

/// In-memory player used by the UI milestone and tests. Records the calls so
/// tests can assert which methods fired and replays positions on demand via
/// [emitPosition] / [emitCompleted].
class FakeVoicePlayer implements VoicePlayer {
  int playCalls = 0;
  int pauseCalls = 0;
  int seekCalls = 0;
  int stopCalls = 0;
  VoiceClip? lastClip;
  Duration lastStartPosition = Duration.zero;
  Duration lastSeekPosition = Duration.zero;
  void Function(Duration)? _onPosition;
  void Function()? _onCompleted;

  @override
  Future<void> play(
    VoiceClip clip, {
    required void Function(Duration) onPosition,
    required void Function() onCompleted,
    Duration startAt = Duration.zero,
  }) async {
    playCalls++;
    lastClip = clip;
    lastStartPosition = startAt;
    _onPosition = onPosition;
    _onCompleted = onCompleted;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
  }

  @override
  Future<void> seek(Duration position) async {
    seekCalls++;
    lastSeekPosition = position;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    _onPosition = null;
    _onCompleted = null;
  }

  /// Test hook — pretend the player advanced to [position].
  void emitPosition(Duration position) => _onPosition?.call(position);

  /// Test hook — pretend playback finished.
  void emitCompleted() => _onCompleted?.call();
}
