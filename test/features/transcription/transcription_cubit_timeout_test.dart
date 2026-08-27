import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/transcription/application/transcription_cubit.dart';
import 'package:jeeb_mobile/features/transcription/domain/voice_clip.dart';

void main() {
  group('TranscriptionCubit queued timeout', () {
    const queuedTimeout = Duration(seconds: 3);

    test('a queued transcription becomes a timed-out failure', () {
      fakeAsync((async) {
        final cubit = TranscriptionCubit(queuedTimeout: queuedTimeout);
        addTearDown(cubit.close);

        cubit.seedFromClip(
          const VoiceClip(audioPath: 'audio-1', durationMs: 3000),
        );
        expect(cubit.state.status, TranscriptionStatus.queued);

        async.elapse(queuedTimeout - const Duration(milliseconds: 1));
        expect(cubit.state.status, TranscriptionStatus.queued);
        expect(cubit.state.failure, TranscriptionFailure.none);

        async.elapse(const Duration(milliseconds: 1));
        expect(cubit.state.status, TranscriptionStatus.failed);
        expect(cubit.state.failure, TranscriptionFailure.timedOut);
      });
    });

    test('confirming text cancels the queued failure timer', () {
      fakeAsync((async) {
        final cubit = TranscriptionCubit(queuedTimeout: queuedTimeout);
        addTearDown(cubit.close);

        cubit.seedFromClip(
          const VoiceClip(audioPath: 'audio-1', durationMs: 3000),
        );
        async.elapse(const Duration(seconds: 1));
        cubit.confirmEdit('Bring two bottles of water');

        expect(cubit.state.status, TranscriptionStatus.ready);
        async.elapse(queuedTimeout * 2);
        expect(cubit.state.status, TranscriptionStatus.ready);
        expect(cubit.state.failure, TranscriptionFailure.none);
      });
    });
  });

  test('seedFromClip retains detected language and queued reason', () {
    final cubit = TranscriptionCubit();
    addTearDown(cubit.close);

    cubit.seedFromClip(
      const VoiceClip(
        audioPath: 'audio-2',
        durationMs: 4200,
        language: 'ar-LB',
        reason: 'circuit_open',
      ),
    );

    expect(cubit.state.language, 'ar-LB');
    expect(cubit.state.queuedReason, 'circuit_open');
  });
}
