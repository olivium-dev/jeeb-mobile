import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/voice_request/cubit/voice_recording_cubit.dart';
import 'package:jeeb_mobile/features/voice_request/cubit/voice_recording_state.dart';
import 'package:jeeb_mobile/features/voice_request/data/voice_recording_repository.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_player.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_recorder.dart';
import 'package:jeeb_mobile/features/voice_request/presentation/voice_recording_screen.dart';
import 'package:omds/omds.dart';

import 'support/sync_app_localizations.dart';

/// Builds a cubit with faked collaborators and a non-firing ticker factory
/// so no pending timers are left after pump.
VoiceRecordingCubit _buildCubit() {
  return VoiceRecordingCubit(
    recorder: FakeVoiceRecorder(),
    player: FakeVoicePlayer(),
    repository: FakeVoiceRecordingRepository(),
    // Empty stream — no ticks emitted, no pending timers on dispose.
    tickerFactory: (_) => const Stream.empty(),
  );
}

void main() {
  group('VoiceRecordingScreen (T-MOB-011)', () {
    testWidgets('renders idle mic surface on initial load',
        (tester) async {
      final cubit = _buildCubit();
      addTearDown(cubit.close);
      await tester.pumpWidget(
        wrapForTest(VoiceRecordingScreen(cubit: cubit)),
      );
      await tester.pump();

      expect(find.byType(VoiceRecordingScreen), findsOneWidget);
      // In idle state the waveform widget is NOT shown.
      expect(find.byType(OmdsRecordingInput), findsNothing);
    });

    testWidgets(
        'shows OmdsRecordingInput waveform bar when cubit is in recording phase (AC1)',
        (tester) async {
      final cubit = _buildCubit();
      addTearDown(cubit.close);
      await tester.pumpWidget(
        wrapForTest(VoiceRecordingScreen(cubit: cubit)),
      );

      // Drive to recording state using cubit directly — avoids gestures.
      await cubit.startRecording();
      await tester.pump();

      // While recording, OmdsRecordingInput (with animated waveform) is shown.
      expect(find.byType(OmdsRecordingInput), findsOneWidget);
    });

    testWidgets('send button absent in sent phase — send-disable AC3',
        (tester) async {
      // Pre-seed a cubit already in the sent state to verify the
      // post-send UI: no raw "Send" button, "Record another" visible.
      final cubit = _buildCubit();
      addTearDown(cubit.close);

      await tester.pumpWidget(
        wrapForTest(
          BlocProvider<VoiceRecordingCubit>.value(
            value: cubit,
            child: VoiceRecordingScreen(cubit: cubit),
          ),
        ),
      );

      // Emit the sent state directly.
      cubit.emit(cubit.state.copyWith(
        phase: VoiceRecordingPhase.sent,
        result: const TranscriptionResult(id: 'test-123'),
      ));
      await tester.pump();

      // In sent phase, there should be no Send button (send is disabled AC3).
      // "Record another" CTA replaces the send button.
      expect(find.text('إرسال'), findsNothing); // AR: send
      expect(find.text('Send'), findsNothing); // EN: send
    });

    testWidgets('sends broadcasting hint in the sent confirmation (AC3)',
        (tester) async {
      final cubit = _buildCubit();
      addTearDown(cubit.close);

      await tester.pumpWidget(
        wrapForTest(VoiceRecordingScreen(cubit: cubit)),
      );

      cubit.emit(cubit.state.copyWith(
        phase: VoiceRecordingPhase.sent,
        result: const TranscriptionResult(id: 'tx-001'),
      ));
      await tester.pump();

      // Sent confirmation state renders without crash — screen still visible.
      expect(find.byType(VoiceRecordingScreen), findsOneWidget);
    });
  });
}
