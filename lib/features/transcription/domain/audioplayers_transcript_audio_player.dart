import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'transcript_audio_player.dart';

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
