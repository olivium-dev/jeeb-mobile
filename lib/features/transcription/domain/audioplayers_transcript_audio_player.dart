import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'transcript_audio_player.dart';

/// Real [TranscriptAudioPlayer] built on the `audioplayers` package
/// (JEBV4-13 — the transcription replay control shipped wired to
/// [NoopTranscriptAudioPlayer], so the visible play button did nothing).
///
/// Mirrors the established `AudioPlayersVoicePlayer` adapter idiom
/// (voice_request/domain/audioplayers_voice_player.dart): the cubit owns the
/// playback phase; this adapter only translates the plugin's position /
/// completion streams into the [play] callbacks and tears the subscriptions
/// down on [pause]/[stop] so a closed cubit never receives stray ticks.
///
/// The underlying [AudioPlayer] is created LAZILY on first [play] so merely
/// constructing the screen (route tables, widget tests) never touches
/// platform channels.
class AudioPlayersTranscriptAudioPlayer implements TranscriptAudioPlayer {
  AudioPlayersTranscriptAudioPlayer({AudioPlayer? player}) : _player = player;

  AudioPlayer? _player;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<void>? _completeSub;

  AudioPlayer get _resolved => _player ??= AudioPlayer();

  @override
  Future<void> play(
    String path, {
    required void Function(Duration) onPosition,
    required void Function() onCompleted,
  }) async {
    final player = _resolved;
    await _cancelSubscriptions();
    _positionSub = player.onPositionChanged.listen(onPosition);
    _completeSub = player.onPlayerComplete.listen((_) => onCompleted());
    await player.play(DeviceFileSource(path));
  }

  @override
  Future<void> pause() async {
    await _player?.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    // Deliberately `_player?`, not `_resolved`: dragging the knob before any
    // play must not construct a source-less platform player.
    await _player?.seek(position);
  }

  @override
  Future<void> stop() async {
    await _cancelSubscriptions();
    await _player?.stop();
  }

  @override
  Future<void> dispose() async {
    await _cancelSubscriptions();
    await _player?.dispose();
    _player = null;
  }

  Future<void> _cancelSubscriptions() async {
    await _positionSub?.cancel();
    await _completeSub?.cancel();
    _positionSub = null;
    _completeSub = null;
  }
}
