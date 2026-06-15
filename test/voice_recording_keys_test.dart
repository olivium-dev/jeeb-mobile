import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/voice_request/cubit/voice_recording_cubit.dart';
import 'package:jeeb_mobile/features/voice_request/cubit/voice_recording_state.dart';
import 'package:jeeb_mobile/features/voice_request/data/voice_recording_repository.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_clip.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_player.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_recorder.dart';
import 'package:jeeb_mobile/features/voice_request/presentation/voice_recording_screen.dart';

import 'support/sync_app_localizations.dart';

/// Cubit wired with faked collaborators and a non-firing ticker so no pending
/// timers survive a pump.
VoiceRecordingCubit _buildCubit() {
  return VoiceRecordingCubit(
    recorder: FakeVoiceRecorder(),
    player: FakeVoicePlayer(),
    repository: FakeVoiceRecordingRepository(),
    tickerFactory: (_) => const Stream.empty(),
  );
}

VoiceClip _clip() => VoiceClip(
      bytes: Uint8List.fromList(List<int>.filled(32, 0x33)),
      duration: const Duration(seconds: 5),
      sourcePath: '/tmp/clip.m4a',
    );

void main() {
  group('VoiceRecording stable keys for QA (T-MOB-011 DoD)', () {
    testWidgets('idle phase exposes the mic-button key', (tester) async {
      final cubit = _buildCubit();
      addTearDown(cubit.close);
      await tester.pumpWidget(
        wrapForTest(VoiceRecordingScreen(cubit: cubit)),
      );
      await tester.pump();

      expect(find.byKey(VoiceRecordingKeys.micButton), findsOneWidget);
      expect(find.byKey(VoiceRecordingKeys.sendButton), findsNothing);
    });

    testWidgets('recording phase exposes waveform + cancel keys',
        (tester) async {
      final cubit = _buildCubit();
      addTearDown(cubit.close);
      await tester.pumpWidget(
        wrapForTest(VoiceRecordingScreen(cubit: cubit)),
      );
      await cubit.startRecording();
      await tester.pump();

      expect(
        find.byKey(VoiceRecordingKeys.recordingWaveform),
        findsOneWidget,
      );
      expect(find.byKey(VoiceRecordingKeys.cancelButton), findsOneWidget);
      expect(find.byKey(VoiceRecordingKeys.micButton), findsNothing);
    });

    testWidgets('recorded phase exposes playback toggle, progress, discard, send',
        (tester) async {
      final cubit = _buildCubit();
      addTearDown(cubit.close);
      await tester.pumpWidget(
        wrapForTest(VoiceRecordingScreen(cubit: cubit)),
      );
      cubit.emit(
        cubit.state.copyWith(
          phase: VoiceRecordingPhase.recorded,
          clip: _clip(),
          elapsed: const Duration(seconds: 5),
        ),
      );
      await tester.pump();

      expect(find.byKey(VoiceRecordingKeys.playbackToggle), findsOneWidget);
      expect(find.byKey(VoiceRecordingKeys.playbackProgress), findsOneWidget);
      expect(find.byKey(VoiceRecordingKeys.discardButton), findsOneWidget);
      expect(find.byKey(VoiceRecordingKeys.sendButton), findsOneWidget);
    });

    testWidgets('sent phase exposes the record-another key, hides send',
        (tester) async {
      final cubit = _buildCubit();
      addTearDown(cubit.close);
      await tester.pumpWidget(
        wrapForTest(VoiceRecordingScreen(cubit: cubit)),
      );
      cubit.emit(
        cubit.state.copyWith(
          phase: VoiceRecordingPhase.sent,
          result: const TranscriptionResult(id: 'abc-123'),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(VoiceRecordingKeys.recordAnotherButton),
        findsOneWidget,
      );
      expect(find.byKey(VoiceRecordingKeys.sendButton), findsNothing);
    });
  });
}
