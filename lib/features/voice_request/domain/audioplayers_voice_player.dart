import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'voice_clip.dart';
import 'voice_player.dart';

class AudioPlayersVoicePlayer implements VoicePlayer {
  AudioPlayersVoicePlayer({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<void>? _completeSub;

  @override
  Future<void> play(
    VoiceClip clip, {
    required void Function(Duration) onPosition,
    required void Function() onCompleted,
    Duration startAt = Duration.zero,
  }) async {
    await _cancelSubscriptions();
    _positionSub = _player.onPositionChanged.listen(onPosition);
    _completeSub = _player.onPlayerComplete.listen((_) => onCompleted());
    final source = _sourceFor(clip);
    if (startAt == Duration.zero) {
      await _player.play(source);
    } else {
      await _player.play(source, position: startAt);
    }
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _cancelSubscriptions();
    await _player.stop();
  }

  Source _sourceFor(VoiceClip clip) {
    final String? path = clip.sourcePath;
    if (path != null && path.isNotEmpty) {
      return DeviceFileSource(path);
    }
    return BytesSource(clip.bytes, mimeType: clip.mimeType);
  }

  Future<void> _cancelSubscriptions() async {
    await _positionSub?.cancel();
    await _completeSub?.cancel();
    _positionSub = null;
    _completeSub = null;
  }
}
