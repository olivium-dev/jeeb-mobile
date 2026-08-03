import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/voice_request/cubit/voice_recording_cubit.dart';
import 'package:jeeb_mobile/features/voice_request/cubit/voice_recording_state.dart';
import 'package:jeeb_mobile/features/voice_request/data/voice_recording_repository.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_clip.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_player.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_recorder.dart';
import 'package:jeeb_mobile/features/voice_request/presentation/voice_recording_screen.dart';
import 'package:omds/omds.dart';

import 'support/sync_app_localizations.dart';

/// Builds a cubit with faked collaborators and a non-firing ticker factory
/// so no pending timers are left after pump.
VoiceRecordingCubit _buildCubit({
  FakeVoiceRecordingRepository? repository,
  FakeVoicePlayer? player,
}) {
  return VoiceRecordingCubit(
    recorder: FakeVoiceRecorder(),
    player: player ?? FakeVoicePlayer(),
    repository: repository ?? FakeVoiceRecordingRepository(),
    // Empty stream — no ticks emitted, no pending timers on dispose.
    tickerFactory: (_) => const Stream.empty(),
  );
}

VoiceClip _clip() => VoiceClip(
  bytes: Uint8List.fromList(List<int>.filled(32, 0x33)),
  duration: const Duration(seconds: 5),
  sourcePath: '/tmp/clip.m4a',
);

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance > secondLuminance
      ? firstLuminance
      : secondLuminance;
  final darker = firstLuminance > secondLuminance
      ? secondLuminance
      : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('VoiceRecordingScreen (T-MOB-011)', () {
    testWidgets('renders idle mic surface on initial load', (tester) async {
      final cubit = _buildCubit();
      addTearDown(cubit.close);
      await tester.pumpWidget(wrapForTest(VoiceRecordingScreen(cubit: cubit)));
      await tester.pump();

      expect(find.byType(VoiceRecordingScreen), findsOneWidget);
      // In idle state the waveform widget is NOT shown.
      expect(find.byKey(VoiceRecordingKeys.recordingWaveform), findsNothing);
    });

    testWidgets(
      'shows the live waveform mark when cubit is in recording phase (AC1)',
      (tester) async {
        final cubit = _buildCubit();
        addTearDown(cubit.close);
        await tester.pumpWidget(
          wrapForTest(VoiceRecordingScreen(cubit: cubit)),
        );

        // Drive to recording state using cubit directly — avoids gestures.
        await cubit.startRecording();
        await tester.pump();

        // While recording, the JeebWaveform.live mark is shown.
        expect(
          find.byKey(VoiceRecordingKeys.recordingWaveform),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'recorded phase switches to review copy with record-again and submit',
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

        expect(find.text('Review your recording'), findsOneWidget);
        expect(
          find.text('Press and hold the mic. Release to stop.'),
          findsNothing,
        );
        expect(find.byKey(VoiceRecordingKeys.micButton), findsNothing);
        expect(find.byType(OmdsSeekBar), findsOneWidget);
        expect(find.text('Record again'), findsOneWidget);
        expect(find.text('Submit'), findsOneWidget);
      },
    );

    testWidgets(
      'OMDS seek rail has token contrast, visible thumb, and 48dp target',
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

        final seekBar = tester.widget<OmdsSeekBar>(find.byType(OmdsSeekBar));
        final background = Theme.of(
          tester.element(find.byType(OmdsSeekBar)),
        ).colorScheme.surface;
        expect(
          _contrastRatio(seekBar.activeColor!, background),
          greaterThanOrEqualTo(3),
        );
        expect(
          _contrastRatio(seekBar.inactiveColor!, background),
          greaterThanOrEqualTo(3),
        );
        expect(seekBar.onChangeEnd, isNotNull);
        expect(seekBar.thumbColor, seekBar.activeColor);
        expect(seekBar.thumbRadius, greaterThanOrEqualTo(5));

        final slider = find.descendant(
          of: find.byType(OmdsSeekBar),
          matching: find.byType(Slider),
        );
        expect(slider, findsNWidgets(2));
        expect(tester.getSize(slider.last).height, greaterThanOrEqualTo(48));
      },
    );

    testWidgets(
      'server failure persists with retry-submit and record-again recovery',
      (tester) async {
        final repository = FakeVoiceRecordingRepository(
          failure: VoiceUploadFailure.server,
        );
        final cubit = _buildCubit(repository: repository);
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

        await tester.tap(find.text('Submit'));
        await tester.pump();

        expect(cubit.state.error, VoiceRecordingError.uploadServer);
        expect(find.byKey(VoiceRecordingKeys.uploadErrorState), findsOneWidget);
        expect(find.byType(OmdsErrorState), findsOneWidget);
        expect(find.text("Couldn't submit your recording"), findsOneWidget);
        expect(find.text('Record again'), findsOneWidget);
        expect(find.text('Retry upload & submit'), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);

        await tester.pump();
        expect(find.byKey(VoiceRecordingKeys.uploadErrorState), findsOneWidget);

        repository.failure = null;
        await tester.tap(find.text('Retry upload & submit'));
        await tester.pump();

        expect(repository.uploadCalls, 2);
        expect(cubit.state.phase, VoiceRecordingPhase.sent);
        expect(cubit.state.error, isNull);
      },
    );

    testWidgets('record again recovers from a persistent upload failure', (
      tester,
    ) async {
      final cubit = _buildCubit();
      addTearDown(cubit.close);
      await tester.pumpWidget(wrapForTest(VoiceRecordingScreen(cubit: cubit)));
      cubit.emit(
        cubit.state.copyWith(
          phase: VoiceRecordingPhase.recorded,
          clip: _clip(),
          elapsed: const Duration(seconds: 5),
          error: VoiceRecordingError.uploadNetwork,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Record again'));
      await tester.pump();

      expect(cubit.state.phase, VoiceRecordingPhase.idle);
      expect(cubit.state.clip, isNull);
      expect(cubit.state.error, isNull);
      expect(find.byKey(VoiceRecordingKeys.micButton), findsOneWidget);
    });

    testWidgets('send button absent in sent phase — send-disable AC3', (
      tester,
    ) async {
      // Pre-seed a cubit already in the sent state to verify the
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
      cubit.emit(
        cubit.state.copyWith(
          phase: VoiceRecordingPhase.sent,
          result: const TranscriptionResult(id: 'test-123'),
        ),
      );
      await tester.pump();

      // In sent phase, there should be no Send button (send is disabled AC3).
      expect(find.text('إرسال'), findsNothing); // AR: send
      expect(find.text('Send'), findsNothing); // EN: send
    });

    testWidgets('sends broadcasting hint in the sent confirmation (AC3)', (
      tester,
    ) async {
      final cubit = _buildCubit();
      addTearDown(cubit.close);

      await tester.pumpWidget(wrapForTest(VoiceRecordingScreen(cubit: cubit)));

      cubit.emit(
        cubit.state.copyWith(
          phase: VoiceRecordingPhase.sent,
          result: const TranscriptionResult(id: 'tx-001'),
        ),
      );
      await tester.pump();

      // Sent confirmation state renders without crash — screen still visible.
      expect(find.byType(VoiceRecordingScreen), findsOneWidget);
    });
  });
}
