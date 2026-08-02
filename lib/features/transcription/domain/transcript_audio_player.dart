import 'dart:async';

abstract class TranscriptAudioPlayer {
  Future<void> play(
    String path, {
    required void Function(Duration) onPosition,
    required void Function() onCompleted,
  });

  Future<void> pause();

  Future<void> stop();

  Future<void> dispose();
}

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

  void emitPosition(Duration position) => _onPosition?.call(position);

  void emitCompleted() => _onCompleted?.call();
}
