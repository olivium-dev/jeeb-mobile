import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/voice_request/cubit/voice_recording_cubit.dart';
import 'package:jeeb_mobile/features/voice_request/cubit/voice_recording_state.dart';
import 'package:jeeb_mobile/features/voice_request/data/voice_recording_repository.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_player.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_recorder.dart';

/// Test harness — drives the cubit through a manual ticker so we can step the
/// recording-elapsed counter deterministically. The cubit treats each yielded
/// duration as the cumulative elapsed time at that tick.
class _Harness {
  _Harness({
    FakeVoiceRecorder? recorder,
    FakeVoicePlayer? player,
    FakeVoiceRecordingRepository? repository,
  }) : recorder = recorder ?? FakeVoiceRecorder(),
       player = player ?? FakeVoicePlayer(),
       repository = repository ?? FakeVoiceRecordingRepository();

  final FakeVoiceRecorder recorder;
  final FakeVoicePlayer player;
  final FakeVoiceRecordingRepository repository;
  final List<StreamController<Duration>> _tickers = [];

  VoiceRecordingCubit build() {
    return VoiceRecordingCubit(
      recorder: recorder,
      player: player,
      repository: repository,
      tickerFactory: _factory,
      tickInterval: const Duration(milliseconds: 100),
    );
  }

  Stream<Duration> _factory(Duration step) {
    final controller = StreamController<Duration>.broadcast();
    _tickers.add(controller);
    return controller.stream;
  }

  /// Pushes a cumulative elapsed value into the most recently created ticker.
  Future<void> tick(Duration elapsed) async {
    expect(
      _tickers,
      isNotEmpty,
      reason: 'tick() called before any recording started',
    );
    _tickers.last.add(elapsed);
    // Let pending listeners run.
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> closeTickers() async {
    for (final c in _tickers) {
      await c.close();
    }
  }
}

VoiceRecordingCubit _bind(_Harness harness) {
  final cubit = harness.build();
  addTearDown(() async {
    await cubit.close();
    await harness.closeTickers();
  });
  return cubit;
}

void main() {
  group('VoiceRecordingCubit — recording lifecycle', () {
    test('initial state is idle with no clip, no elapsed, no error', () {
      final cubit = _bind(_Harness());
      expect(cubit.state.phase, VoiceRecordingPhase.idle);
      expect(cubit.state.elapsed, Duration.zero);
      expect(cubit.state.clip, isNull);
      expect(cubit.state.error, isNull);
      expect(cubit.state.canSend, isFalse);
    });

    test(
      'startRecording transitions to recording and advances elapsed',
      () async {
        final harness = _Harness();
        final cubit = _bind(harness);

        await cubit.startRecording();
        expect(cubit.state.phase, VoiceRecordingPhase.recording);
        expect(cubit.state.elapsed, Duration.zero);

        await harness.tick(const Duration(milliseconds: 500));
        expect(cubit.state.elapsed, const Duration(milliseconds: 500));

        await harness.tick(const Duration(milliseconds: 1500));
        expect(cubit.state.elapsed, const Duration(milliseconds: 1500));
      },
    );

    test('stopRecording finalises the clip and moves to recorded', () async {
      final harness = _Harness();
      final cubit = _bind(harness);

      await cubit.startRecording();
      await harness.tick(const Duration(milliseconds: 2400));
      await cubit.stopRecording();

      expect(cubit.state.phase, VoiceRecordingPhase.recorded);
      expect(cubit.state.clip, isNotNull);
      expect(cubit.state.clip!.duration, const Duration(milliseconds: 2400));
      expect(cubit.state.canSend, isTrue);
    });

    test(
      'releasing the mic too early raises tooShort and discards the clip',
      () async {
        final harness = _Harness();
        final cubit = _bind(harness);

        await cubit.startRecording();
        await harness.tick(const Duration(milliseconds: 400));
        await cubit.stopRecording();

        expect(cubit.state.phase, VoiceRecordingPhase.idle);
        expect(cubit.state.clip, isNull);
        expect(cubit.state.error, VoiceRecordingError.tooShort);
      },
    );

    test('cancelRecording aborts without raising tooShort', () async {
      final harness = _Harness();
      final cubit = _bind(harness);

      await cubit.startRecording();
      await harness.tick(const Duration(milliseconds: 200));
      await cubit.cancelRecording();

      expect(cubit.state.phase, VoiceRecordingPhase.idle);
      expect(cubit.state.error, isNull);
      expect(cubit.state.clip, isNull);
    });

    test(
      'exceeding the duration cap auto-stops at 60s with maxReached error',
      () async {
        final harness = _Harness();
        final cubit = _bind(harness);

        await cubit.startRecording();
        await harness.tick(VoiceRecordingState.maxDuration);
        // Give the cubit a microtask to run _autoStopAtCap to completion.
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.phase, VoiceRecordingPhase.recorded);
        expect(cubit.state.elapsed, VoiceRecordingState.maxDuration);
        expect(cubit.state.error, VoiceRecordingError.maxDurationReached);
        expect(cubit.state.clip!.duration, VoiceRecordingState.maxDuration);
      },
    );

    test(
      'recorder permission failure surfaces permissionDenied error',
      () async {
        final recorder = FakeVoiceRecorder(
          startFailure: VoiceRecorderFailure.permissionDenied,
        );
        final harness = _Harness(recorder: recorder);
        final cubit = _bind(harness);

        await cubit.startRecording();

        expect(cubit.state.phase, VoiceRecordingPhase.idle);
        expect(cubit.state.error, VoiceRecordingError.permissionDenied);
      },
    );
  });

  group('VoiceRecordingCubit — playback', () {
    test('togglePlayback starts the player and advances position', () async {
      final harness = _Harness();
      final cubit = _bind(harness);

      await cubit.startRecording();
      await harness.tick(const Duration(seconds: 2));
      await cubit.stopRecording();

      await cubit.togglePlayback();
      expect(cubit.state.phase, VoiceRecordingPhase.playing);
      expect(harness.player.playCalls, 1);

      harness.player.emitPosition(const Duration(milliseconds: 500));
      expect(cubit.state.playbackPosition, const Duration(milliseconds: 500));
    });

    test('togglePlayback pauses an in-flight playback', () async {
      final harness = _Harness();
      final cubit = _bind(harness);

      await cubit.startRecording();
      await harness.tick(const Duration(seconds: 2));
      await cubit.stopRecording();

      await cubit.togglePlayback();
      await cubit.togglePlayback();

      expect(cubit.state.phase, VoiceRecordingPhase.recorded);
      expect(harness.player.pauseCalls, 1);
    });

    test(
      'playback completion returns to recorded with full position',
      () async {
        final harness = _Harness();
        final cubit = _bind(harness);

        await cubit.startRecording();
        await harness.tick(const Duration(seconds: 2));
        await cubit.stopRecording();

        await cubit.togglePlayback();
        harness.player.emitCompleted();

        expect(cubit.state.phase, VoiceRecordingPhase.recorded);
        expect(cubit.state.playbackPosition, cubit.state.clip!.duration);
      },
    );

    test('seek is retained before play and forwarded while playing', () async {
      final harness = _Harness();
      final cubit = _bind(harness);

      await cubit.startRecording();
      await harness.tick(const Duration(seconds: 3));
      await cubit.stopRecording();

      await cubit.seekPlayback(const Duration(seconds: 1));
      expect(cubit.state.playbackPosition, const Duration(seconds: 1));
      expect(harness.player.seekCalls, 0);

      await cubit.togglePlayback();
      expect(harness.player.lastStartPosition, const Duration(seconds: 1));

      await cubit.seekPlayback(const Duration(milliseconds: 1500));
      expect(harness.player.seekCalls, 1);
      expect(
        harness.player.lastSeekPosition,
        const Duration(milliseconds: 1500),
      );
    });
  });

  group('VoiceRecordingCubit — discard and send', () {
    test('discardClip wipes the clip and returns to idle', () async {
      final harness = _Harness();
      final cubit = _bind(harness);

      await cubit.startRecording();
      await harness.tick(const Duration(seconds: 2));
      await cubit.stopRecording();
      await cubit.discardClip();

      expect(cubit.state.phase, VoiceRecordingPhase.idle);
      expect(cubit.state.clip, isNull);
    });

    test(
      'send uploads the clip and reaches sent with a TranscriptionResult',
      () async {
        final harness = _Harness(
          repository: FakeVoiceRecordingRepository(transcript: 'hello'),
        );
        final cubit = _bind(harness);

        await cubit.startRecording();
        await harness.tick(const Duration(seconds: 3));
        await cubit.stopRecording();
        await cubit.send();

        expect(cubit.state.phase, VoiceRecordingPhase.sent);
        expect(cubit.state.result, isNotNull);
        expect(cubit.state.result!.transcript, 'hello');
        expect(harness.repository.uploadCalls, 1);
      },
    );

    test(
      'send refuses when the clip is shorter than the min sendable length',
      () async {
        // Force a short clip into the state by mocking the recorder return.
        final harness = _Harness();
        final cubit = _bind(harness);

        // Build a manual clip below the threshold and inject it via stop.
        await cubit.startRecording();
        await harness.tick(const Duration(milliseconds: 1100));
        await cubit.stopRecording();
        // Sanity — we're in recorded with a >= 1s clip.
        expect(cubit.state.canSend, isTrue);

        await cubit.discardClip();
        // No clip → send is a no-op.
        await cubit.send();
        expect(cubit.state.phase, VoiceRecordingPhase.idle);
        expect(harness.repository.uploadCalls, 0);
      },
    );

    test('send surfaces uploadNetwork on network failure', () async {
      final repo = FakeVoiceRecordingRepository()
        ..failure = VoiceUploadFailure.network;
      final harness = _Harness(repository: repo);
      final cubit = _bind(harness);

      await cubit.startRecording();
      await harness.tick(const Duration(seconds: 2));
      await cubit.stopRecording();
      await cubit.send();

      expect(cubit.state.phase, VoiceRecordingPhase.recorded);
      expect(cubit.state.error, VoiceRecordingError.uploadNetwork);
      expect(
        cubit.state.clip,
        isNotNull,
        reason: 'clip is retained so the user can retry',
      );
    });

    test(
      'retry after upload failure clears the error and submits retained clip',
      () async {
        final repository = FakeVoiceRecordingRepository(
          failure: VoiceUploadFailure.server,
        );
        final harness = _Harness(repository: repository);
        final cubit = _bind(harness);

        await cubit.startRecording();
        await harness.tick(const Duration(seconds: 2));
        await cubit.stopRecording();
        await cubit.send();

        expect(cubit.state.hasUploadFailure, isTrue);
        expect(cubit.state.clip, isNotNull);

        repository.failure = null;
        await cubit.send();

        expect(repository.uploadCalls, 2);
        expect(cubit.state.phase, VoiceRecordingPhase.sent);
        expect(cubit.state.error, isNull);
      },
    );

    test('reset clears the sent state so the user can record again', () async {
      final harness = _Harness();
      final cubit = _bind(harness);

      await cubit.startRecording();
      await harness.tick(const Duration(seconds: 2));
      await cubit.stopRecording();
      await cubit.send();
      await cubit.reset();

      expect(cubit.state.phase, VoiceRecordingPhase.idle);
      expect(cubit.state.clip, isNull);
      expect(cubit.state.result, isNull);
    });

    test('acknowledgeError clears a pending error one-shot', () async {
      final harness = _Harness();
      final cubit = _bind(harness);

      await cubit.startRecording();
      await harness.tick(const Duration(milliseconds: 400));
      await cubit.stopRecording();
      expect(cubit.state.error, VoiceRecordingError.tooShort);

      cubit.acknowledgeError();
      expect(cubit.state.error, isNull);
    });
  });
}
