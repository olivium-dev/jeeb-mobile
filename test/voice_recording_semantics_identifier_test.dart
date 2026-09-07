// VOICE-D2 addressability locks.

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

    // TEST-07: the upload-failure surface and its two acts were addressable
    // only by Key, so no uiautomator step could reach them.
    testWidgets('a RETRYABLE upload failure exposes the surface, the retry '
        'and the discard', (tester) async {
      final handle = tester.ensureSemantics();
      final cubit = _buildCubit();
      addTearDown(cubit.close);
      await tester.pumpWidget(wrapForTest(VoiceRecordingScreen(cubit: cubit)));
      cubit.emit(
        cubit.state.copyWith(
          phase: VoiceRecordingPhase.recorded,
          clip: _clip(),
          error: VoiceRecordingError.uploadServer,
        ),
      );
      await tester.pump();

      expect(
        find.bySemanticsIdentifier('voice_request_upload_error_state'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('voice_request_retry_upload_button'),
        findsOneWidget,
      );
      expect(find.byKey(VoiceRecordingKeys.discardButton), findsOneWidget);
      handle.dispose();
    });

    // R6: 413/415 can never succeed on a retry of the SAME clip.
    testWidgets('a TERMINAL upload failure hides the retry and keeps only '
        'record-again', (tester) async {
      final handle = tester.ensureSemantics();
      final cubit = _buildCubit();
      addTearDown(cubit.close);
      await tester.pumpWidget(wrapForTest(VoiceRecordingScreen(cubit: cubit)));
      cubit.emit(
        cubit.state.copyWith(
          phase: VoiceRecordingPhase.recorded,
          clip: _clip(),
          error: VoiceRecordingError.uploadTooLarge,
        ),
      );
      await tester.pump();

      expect(
        find.bySemanticsIdentifier('voice_request_upload_error_state'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('voice_request_retry_upload_button'),
        findsNothing,
      );
      expect(find.byKey(VoiceRecordingKeys.discardButton), findsOneWidget);
      handle.dispose();
    });

    // VOICE-02: "Try again" cannot grant a permanently denied OS permission.
    testWidgets('the permission-denied surface exposes an Open Settings CTA',
        (tester) async {
      final handle = tester.ensureSemantics();
      final cubit = _buildCubit();
      addTearDown(cubit.close);
      await tester.pumpWidget(wrapForTest(VoiceRecordingScreen(cubit: cubit)));
      cubit.emit(
        cubit.state.copyWith(error: VoiceRecordingError.permissionDenied),
      );
      await tester.pump();

      expect(
        find.bySemanticsIdentifier('voice_request_blocked_state'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('voice_request_open_settings_cta'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('the recorder-unavailable surface has NO Open Settings CTA',
        (tester) async {
      final handle = tester.ensureSemantics();
      final cubit = _buildCubit();
      addTearDown(cubit.close);
      await tester.pumpWidget(wrapForTest(VoiceRecordingScreen(cubit: cubit)));
      cubit.emit(
        cubit.state.copyWith(error: VoiceRecordingError.recorderUnavailable),
      );
      await tester.pump();

      expect(
        find.bySemanticsIdentifier('voice_request_open_settings_cta'),
        findsNothing,
      );
      handle.dispose();
    });

    // EP-20: the transient snack was an unlabelled `showOmdsErrorSnackbar`.
    testWidgets('a transient error surfaces the identified Jeeb snack',
        (tester) async {
      final handle = tester.ensureSemantics();
      final cubit = _buildCubit();
      addTearDown(cubit.close);
      await tester.pumpWidget(wrapForTest(VoiceRecordingScreen(cubit: cubit)));
      cubit.emit(cubit.state.copyWith(error: VoiceRecordingError.tooShort));
      await tester.pump();
      await tester.pump();

      expect(
        find.bySemanticsIdentifier('voice_request_transient_error'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
