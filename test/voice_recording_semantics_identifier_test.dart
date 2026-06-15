// VOICE-D2 addressability locks.
//
// `Key()` does NOT surface as an Android `resource-id` to uiautomator/Maestro —
// only `Semantics(identifier:)` maps onto
// `AccessibilityNodeInfo.viewIdResourceName`. These tests prove every
// voice-composer control carries the expected `voice_request_*` identifier as
// an independently queryable `SemanticsNode`, using the repo's canonical
// `find.bySemanticsIdentifier(...)` finder (see
// test/semantics_identifier_surfacing_test.dart). They FAIL on the pre-fix
// source (no `Semantics(identifier:)` wrapper → `findsNothing`) and PASS after,
// verified via `git stash push -- lib/features/voice_request/...`.

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
  group('VoiceRecording Semantics identifiers surface to uiautomator (D2)', () {
    testWidgets('idle phase exposes voice_request_mic_button identifier',
        (tester) async {
      final handle = tester.ensureSemantics();
      final cubit = _buildCubit();
      addTearDown(cubit.close);
      await tester.pumpWidget(
        wrapForTest(VoiceRecordingScreen(cubit: cubit)),
      );
      await tester.pump();

      expect(
        find.bySemanticsIdentifier('voice_request_mic_button'),
        findsOneWidget,
        reason: 'mic button must carry a Semantics identifier, not just a Key',
      );
      handle.dispose();
    });

    testWidgets('recording phase exposes waveform + cancel identifiers',
        (tester) async {
      final handle = tester.ensureSemantics();
      final cubit = _buildCubit();
      addTearDown(cubit.close);
      await tester.pumpWidget(
        wrapForTest(VoiceRecordingScreen(cubit: cubit)),
      );
      await cubit.startRecording();
      await tester.pump();

      expect(
        find.bySemanticsIdentifier('voice_request_recording_waveform'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('voice_request_cancel_button'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets(
        'recorded phase exposes playback toggle, progress, send identifiers',
        (tester) async {
      final handle = tester.ensureSemantics();
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

      expect(
        find.bySemanticsIdentifier('voice_request_playback_toggle'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('voice_request_playback_progress'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('voice_request_send_button'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets(
        'sent phase exposes voice_request_record_another_button identifier',
        (tester) async {
      final handle = tester.ensureSemantics();
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
        find.bySemanticsIdentifier('voice_request_record_another_button'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
