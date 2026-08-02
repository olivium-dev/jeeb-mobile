import 'voice_clip.dart';









abstract class VoicePlayer {
  
  
  
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

  
  void emitPosition(Duration position) => _onPosition?.call(position);

  
  void emitCompleted() => _onCompleted?.call();
}
