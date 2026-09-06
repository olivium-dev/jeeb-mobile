// ESC-01/ESC-02/ESC-03 + COPY-07: the photo and the microphone each own their
// own note, and neither borrows the other's copy.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/escalate/application/escalate_cubit.dart';
import 'package:jeeb_mobile/features/escalate/domain/escalate_repository.dart';
import 'package:jeeb_mobile/features/escalate/presentation/escalate_screen.dart';
import 'package:jeeb_mobile/features/photo_attachment/domain/photo_attachment.dart';
import 'package:jeeb_mobile/features/photo_attachment/domain/photo_picker_service.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_clip.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_recorder.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _Repo implements EscalateRepository {
  const _Repo();

  @override
  Future<EscalateEvidence> fetchEvidence({required String deliveryId}) async =>
      EscalateEvidence.empty;

  @override
  Future<EscalateResult> submitEscalation({
    required String deliveryId,
    required EscalateReason reason,
    String? comment,
    List<String> photoPaths = const <String>[],
    String? voicePath,
    EscalateEvidence evidence = EscalateEvidence.empty,
  }) async => const EscalateResult(caseId: 'dispute-1', status: 'open');
}

class _FailingPicker implements PhotoPickerService {
  _FailingPicker(this.failure);

  final PhotoPickFailure failure;

  @override
  Future<RawPhoto> pickFromCamera() => pickFromGallery();

  @override
  Future<RawPhoto> pickFromGallery() async => throw PhotoPickException(failure);
}

class _OkPicker implements PhotoPickerService {
  @override
  Future<RawPhoto> pickFromCamera() => pickFromGallery();

  @override
  Future<RawPhoto> pickFromGallery() async => RawPhoto(
    bytes: Uint8List.fromList(<int>[1, 2, 3]),
    source: PhotoSource.gallery,
  );
}

/// Fails on `start()` — the ESC-03 lane that used to write into `_photoError`.
class _StartFailingRecorder implements VoiceRecorder {
  _StartFailingRecorder(this.failure);

  final VoiceRecorderFailure failure;

  @override
  Future<void> start() async => throw VoiceRecorderException(failure);

  @override
  Future<VoiceClip> stop({required Duration recordedDuration}) async =>
      throw StateError('not recording');

  @override
  Future<void> cancel() async {}

  @override
  Future<void> deleteOwnedClip(VoiceClip clip) async {}
}

/// Records, then fails on `stop()` — the ESC-02 silent-discard lane.
class _StopFailingRecorder implements VoiceRecorder {
  int cancelCalls = 0;

  @override
  Future<void> start() async {}

  @override
  Future<VoiceClip> stop({required Duration recordedDuration}) async =>
      throw const VoiceRecorderException(VoiceRecorderFailure.unknown);

  @override
  Future<void> cancel() async => cancelCalls += 1;

  @override
  Future<void> deleteOwnedClip(VoiceClip clip) async {}
}

void main() {
  final delegates =
      (wrapForTest(const SizedBox()) as MaterialApp).localizationsDelegates!;

  Widget build({
    PhotoPickerService? photoPicker,
    VoiceRecorder? voiceRecorder,
    Locale locale = const Locale('en'),
  }) => MaterialApp(
    theme: AppTheme.midnight(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: delegates,
    home: BlocProvider<EscalateCubit>(
      create: (_) =>
          EscalateCubit(repository: const _Repo(), deliveryId: 'dlv-1'),
      child: EscalateScreen(
        photoPicker: photoPicker,
        voiceRecorder: voiceRecorder,
      ),
    ),
  );

  Finder byId(String id) => find.bySemanticsIdentifier(id);

  Future<void> pickPhoto(WidgetTester tester) async {
    await tester.ensureVisible(byId('dispute_photos_add_cta'));
    await tester.tap(byId('dispute_photos_add_cta'));
    await tester.pumpAndSettle();
  }

  Future<void> tapVoice(WidgetTester tester) async {
    await tester.ensureVisible(byId('dispute_voice'));
    await tester.tap(byId('dispute_voice'));
    await tester.pumpAndSettle();
  }

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final tag = locale.languageCode;

    testWidgets(
      '[$tag] a denied photo permission notes under the PHOTO block',
      (tester) async {
        useReduceMotion(tester);
        await tester.pumpWidget(
          build(
            photoPicker: _FailingPicker(PhotoPickFailure.permissionDenied),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();
        await pickPhoto(tester);

        expect(byId('dispute_photos_error'), findsOneWidget);
        expect(byId('dispute_voice_error'), findsNothing);
        // COPY-07: the photo key, never the microphone one.
        final l10n = AppLocalizations.of(tester.element(byId('dispute_root')));
        final note = byId('dispute_photos_error');
        expect(
          find.descendant(
            of: note,
            matching: find.text(l10n.photoAttachmentPermissionDenied),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: note,
            matching: find.text(l10n.voiceRecordingErrorPermission),
          ),
          findsNothing,
        );
      },
    );

    testWidgets('[$tag] an unavailable picker gets its own copy, not silence', (
      tester,
    ) async {
      useReduceMotion(tester);
      await tester.pumpWidget(
        build(
          photoPicker: _FailingPicker(PhotoPickFailure.unavailable),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();
      await pickPhoto(tester);

      expect(byId('dispute_photos_error'), findsOneWidget);
      final l10n = AppLocalizations.of(tester.element(byId('dispute_root')));
      expect(
        find.descendant(
          of: byId('dispute_photos_error'),
          matching: find.text(l10n.photoAttachmentUnavailable),
        ),
        findsOneWidget,
      );
    });

    testWidgets('[$tag] a mic START failure notes under the VOICE block', (
      tester,
    ) async {
      useReduceMotion(tester);
      await tester.pumpWidget(
        build(
          voiceRecorder: _StartFailingRecorder(
            VoiceRecorderFailure.permissionDenied,
          ),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();
      await tapVoice(tester);

      // ESC-03: this used to land in `_photoError`.
      expect(byId('dispute_voice_error'), findsOneWidget);
      expect(byId('dispute_photos_error'), findsNothing);
    });
  }

  testWidgets('a cancelled pick leaves no note at all', (tester) async {
    useReduceMotion(tester);
    await tester.pumpWidget(
      build(photoPicker: _FailingPicker(PhotoPickFailure.cancelled)),
    );
    await tester.pumpAndSettle();
    await pickPhoto(tester);

    expect(byId('dispute_photos_error'), findsNothing);
    expect(byId('dispute_voice_error'), findsNothing);
  });

  testWidgets('a mic STOP failure says the clip is gone (ESC-02)', (
    tester,
  ) async {
    useReduceMotion(tester);
    final recorder = _StopFailingRecorder();
    await tester.pumpWidget(build(voiceRecorder: recorder));
    await tester.pumpAndSettle();

    await tapVoice(tester); // start
    await tapVoice(tester); // stop → throws

    expect(byId('dispute_voice_error'), findsOneWidget);
    expect(byId('dispute_photos_error'), findsNothing);
    expect(recorder.cancelCalls, 1);
  });

  testWidgets('a successful pick clears a standing photo note', (tester) async {
    useReduceMotion(tester);
    await tester.pumpWidget(build(photoPicker: _OkPicker()));
    await tester.pumpAndSettle();
    await pickPhoto(tester);

    expect(byId('dispute_photos_error'), findsNothing);
    expect(byId('dispute_photos_chip_0'), findsOneWidget);
  });
}
