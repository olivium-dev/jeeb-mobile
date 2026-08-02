import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/voice_request/cubit/voice_recording_cubit.dart';
import 'package:jeeb_mobile/features/voice_request/cubit/voice_recording_state.dart';
import 'package:jeeb_mobile/features/voice_request/data/voice_recording_repository.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_player.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_recorder.dart';
import 'package:jeeb_mobile/features/voice_request/presentation/voice_recording_screen.dart';
import 'package:omds/omds.dart';

import 'support/sync_app_localizations.dart';

/// Sprint-6 Stream-B polish: the mic pre-condition failures (permission denied,
/// recorder unavailable) must render a persistent, recoverable surface — not a
VoiceRecordingCubit _buildCubit({VoiceRecorder? recorder}) {
  return VoiceRecordingCubit(
    recorder: recorder ?? FakeVoiceRecorder(),
    player: FakeVoicePlayer(),
    repository: FakeVoiceRecordingRepository(),
    tickerFactory: (_) => const Stream.empty(),
  );
}

void main() {
  group('VoiceRecordingScreen — blocking-state polish (Sprint 6)', () {
    testWidgets(
        'permission denied renders a recoverable OmdsErrorState (not the mic)',
        (tester) async {
      final cubit = _buildCubit();
      addTearDown(cubit.close);
      await tester.pumpWidget(wrapForTest(VoiceRecordingScreen(cubit: cubit)));

      cubit.emit(cubit.state.copyWith(
        phase: VoiceRecordingPhase.idle,
        error: VoiceRecordingError.permissionDenied,
      ));
      await tester.pump();

      // Recoverable blocking surface is shown, keyed for QA targeting.
      expect(find.byKey(VoiceRecordingKeys.blockedState), findsOneWidget);
      expect(find.byType(OmdsErrorState), findsOneWidget);
      // The idle mic + hold-to-record hint are replaced while blocked.
      expect(find.byKey(VoiceRecordingKeys.micButton), findsNothing);
      // Localized permission guidance + retry are present (EN).
      expect(find.text('Microphone access needed'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('recorder unavailable renders the unavailable blocking surface',
        (tester) async {
      final cubit = _buildCubit();
      addTearDown(cubit.close);
      await tester.pumpWidget(wrapForTest(VoiceRecordingScreen(cubit: cubit)));

      cubit.emit(cubit.state.copyWith(
        phase: VoiceRecordingPhase.idle,
        error: VoiceRecordingError.recorderUnavailable,
      ));
      await tester.pump();

      expect(find.byKey(VoiceRecordingKeys.blockedState), findsOneWidget);
      expect(find.text('Microphone unavailable'), findsOneWidget);
    });

    testWidgets(
        'transient error (too-short) does NOT render the blocking surface',
        (tester) async {
      final cubit = _buildCubit();
      addTearDown(cubit.close);
      await tester.pumpWidget(wrapForTest(VoiceRecordingScreen(cubit: cubit)));

      cubit.emit(cubit.state.copyWith(
        phase: VoiceRecordingPhase.idle,
        error: VoiceRecordingError.tooShort,
      ));
      await tester.pump();

      // Transient errors stay on the snackbar path: the idle mic remains.
      expect(find.byKey(VoiceRecordingKeys.blockedState), findsNothing);
      expect(find.byKey(VoiceRecordingKeys.micButton), findsOneWidget);
    });

    testWidgets('Try again re-attempts recording (no dead-end)',
        (tester) async {
      // Healthy recorder so the retry succeeds and the screen recovers.
      final cubit = _buildCubit(recorder: FakeVoiceRecorder());
      addTearDown(cubit.close);
      await tester.pumpWidget(wrapForTest(VoiceRecordingScreen(cubit: cubit)));

      cubit.emit(cubit.state.copyWith(
        phase: VoiceRecordingPhase.idle,
        error: VoiceRecordingError.permissionDenied,
      ));
      await tester.pump();
      expect(find.byKey(VoiceRecordingKeys.blockedState), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pump();

      // Retry cleared the block and entered the recording surface.
      expect(find.byKey(VoiceRecordingKeys.blockedState), findsNothing);
      expect(find.byType(OmdsRecordingInput), findsOneWidget);
    });
  });
}
