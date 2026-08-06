// Widget tests for EscalateScreen / dispute-open-evidence (JM-060; ex T-MOB-022).

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/case_evidence/domain/case_evidence.dart';
import 'package:jeeb_mobile/features/escalate/application/escalate_cubit.dart';
import 'package:jeeb_mobile/features/escalate/domain/escalate_repository.dart';
import 'package:jeeb_mobile/features/escalate/presentation/escalate_screen.dart';
import 'package:jeeb_mobile/features/photo_attachment/domain/photo_attachment.dart';
import 'package:jeeb_mobile/features/photo_attachment/domain/photo_picker_service.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_clip.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_recorder.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'support/sync_app_localizations.dart';

class _FakeRepo implements EscalateRepository {
  const _FakeRepo({this.failWith});
  final EscalateErrorKind? failWith;

  @override
  Future<EscalateEvidence> fetchEvidence({required String deliveryId}) async =>
      const EscalateEvidence(
        chatSnapshotUrl: 'https://cdn.jeeb.app/snapshots/conv-1.html',
        chatMessageCount: 3,
        timeline: [EscalateTimelineEntry(status: 'Ordered')],
      );

  @override
  Future<EscalateResult> submitEscalation({
    required String deliveryId,
    required EscalateReason reason,
    String? comment,
    List<String> photoPaths = const [],
    String? voicePath,
    EscalateEvidence evidence = EscalateEvidence.empty,
  }) async {
    if (failWith != null) throw EscalateException(failWith!);
    return const EscalateResult(caseId: 'dispute-999', status: 'open');
  }
}

class _UploadRepo implements EscalateRepository, EscalateV2Repository {
  _UploadRepo({this.failUpload = false});

  final bool failUpload;
  final Completer<EscalateResult> held = Completer<EscalateResult>();
  final List<String> operationIds = <String>[];

  @override
  Future<EscalateEvidence> fetchEvidence({required String deliveryId}) async =>
      EscalateEvidence.empty;

  @override
  Future<EscalateResult> submitReport(
    EscalateSubmission submission, {
    CaseAttachmentProgressCallback? onProgress,
  }) {
    operationIds.add(submission.operationId);
    final localId = submission.attachments.single.localId;
    if (failUpload) {
      onProgress?.call(
        CaseAttachmentProgress(
          localId: localId,
          state: CaseAttachmentUploadState.failed,
          message: 'upload failed',
        ),
      );
      throw const EscalateException(EscalateErrorKind.evidenceUpload);
    }
    onProgress?.call(
      CaseAttachmentProgress(
        localId: localId,
        state: CaseAttachmentUploadState.uploading,
        sentBytes: 1,
        totalBytes: 4,
      ),
    );
    return held.future;
  }

  @override
  Future<EscalateResult> submitEscalation({
    required String deliveryId,
    required EscalateReason reason,
    String? comment,
    List<String> photoPaths = const <String>[],
    String? voicePath,
    EscalateEvidence evidence = EscalateEvidence.empty,
  }) {
    throw UnimplementedError();
  }
}

class _PhotoPicker implements PhotoPickerService {
  @override
  Future<RawPhoto> pickFromCamera() => pickFromGallery();

  @override
  Future<RawPhoto> pickFromGallery() async => RawPhoto(
    bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
    source: PhotoSource.gallery,
  );
}

class _CleanupVoiceRecorder implements VoiceRecorder {
  final String path = '/app-owned/dispute-voice.m4a';
  final List<String> deletedPaths = <String>[];
  int cancelCalls = 0;
  bool recording = false;

  @override
  Future<void> start() async => recording = true;

  @override
  Future<VoiceClip> stop({required Duration recordedDuration}) async {
    recording = false;
    return VoiceClip(
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      duration: recordedDuration,
      sourcePath: path,
    );
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    recording = false;
  }

  @override
  Future<void> deleteOwnedClip(VoiceClip clip) async {
    final sourcePath = clip.sourcePath;
    if (sourcePath == path) deletedPaths.add(sourcePath!);
  }
}

// A GoRouter so the success listener (goNamed dispute-status) + support link
GoRouter _router({
  EscalateRepository? repo,
  PhotoPickerService? photoPicker,
  VoiceRecorder? voiceRecorder,
}) {
  return GoRouter(
    initialLocation: '/orders/dlv-1/escalate',
    routes: [
      GoRoute(
        path: '/orders/:id/escalate',
        name: 'escalate',
        builder: (context, state) => BlocProvider<EscalateCubit>(
          create: (_) => EscalateCubit(
            repository: repo ?? const _FakeRepo(),
            deliveryId: state.pathParameters['id'] ?? '',
          ),
          child: EscalateScreen(
            photoPicker: photoPicker,
            voiceRecorder: voiceRecorder,
          ),
        ),
      ),
      GoRoute(
        path: '/disputes/:id',
        name: 'dispute-status',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text('dispute-status:${state.pathParameters['id']}'),
          ),
        ),
      ),
      GoRoute(
        path: '/support',
        name: 'support-ticket',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('support'))),
      ),
      GoRoute(
        path: '/',
        name: 'shell',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('home'))),
      ),
    ],
  );
}

void main() {
  // Reuse the sync localizations delegate list from the shared helper.
  final delegates =
      (wrapForTest(const SizedBox()) as MaterialApp).localizationsDelegates!;

  Widget build({
    EscalateRepository? repo,
    Locale locale = const Locale('en'),
    PhotoPickerService? photoPicker,
    VoiceRecorder? voiceRecorder,
  }) {
    final router = _router(
      repo: repo,
      photoPicker: photoPicker,
      voiceRecorder: voiceRecorder,
    );
    return MaterialApp.router(
      theme: AppTheme.midnight(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: delegates,
      // Midnight primitives loop ∞ (02-STUDY-NOTES M0-4): `pumpAndSettle` only
      // terminates under reduce motion.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      routerConfig: router,
    );
  }

  Finder byId(String id) => find.bySemanticsIdentifier(id);

  Future<void> captureVoice(
    WidgetTester tester,
    _CleanupVoiceRecorder recorder,
  ) async {
    await tester.ensureVisible(byId('dispute_voice'));
    await tester.tap(byId('dispute_voice'));
    await tester.pump();
    expect(recorder.recording, isTrue);
    await tester.tap(byId('dispute_voice'));
    await tester.pumpAndSettle();
    expect(find.text('Re-record'), findsOneWidget);
  }

  testWidgets('renders report title and reason options', (tester) async {
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();

    expect(find.text('Report an Issue'), findsOneWidget);
    expect(find.text('Damaged item'), findsOneWidget);
    expect(find.text('Fraud'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);
  });

  testWidgets('exposes the blueprint dispute identifiers', (tester) async {
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();

    for (final id in const [
      'dispute_reason',
      'dispute_photos',
      'dispute_voice',
      'dispute_submit_cta',
      'dispute_support_link',
      'dispute_back',
    ]) {
      expect(byId(id), findsWidgets, reason: 'missing identifier $id');
    }
  });

  testWidgets('submit button is disabled until reason selected', (
    tester,
  ) async {
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();

    // Tapping submit with no reason is a no-op (stays on the form).
    await tester.tap(find.text('Submit Report'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Submit Report'), findsOneWidget);
  });

  testWidgets('selecting a reason and submitting routes to dispute-status', (
    tester,
  ) async {
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Damaged item'));
    await tester.pump();

    await tester.tap(find.text('Submit Report'));
    await tester.pumpAndSettle();

    expect(find.text('dispute-status:dispute-999'), findsOneWidget);
  });

  testWidgets('server error shows error message', (tester) async {
    await tester.pumpWidget(
      build(repo: const _FakeRepo(failWith: EscalateErrorKind.server)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('No-show'));
    await tester.pump();
    await tester.tap(find.text('Submit Report'));
    await tester.pumpAndSettle();

    expect(find.textContaining("Couldn't submit"), findsOneWidget);
  });

  testWidgets('renders in Arabic locale', (tester) async {
    await tester.pumpWidget(build(locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('الإبلاغ عن مشكلة'), findsOneWidget);
    expect(find.text('عنصر تالف'), findsOneWidget);

    final dir = Directionality.of(tester.element(find.byType(EscalateScreen)));
    expect(dir, TextDirection.rtl);
  });

  testWidgets('shows accessible evidence upload progress', (tester) async {
    final repo = _UploadRepo();
    await tester.pumpWidget(build(repo: repo, photoPicker: _PhotoPicker()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Damaged item'));
    await tester.pump();
    await tester.ensureVisible(byId('dispute_photos_add_cta'));
    await tester.pump();
    await tester.tap(byId('dispute_photos_add_cta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit Report'));
    await tester.pump();

    expect(byId('dispute_submitting'), findsOneWidget);
    expect(byId('dispute_upload_progress'), findsOneWidget);
    expect(byId('dispute_upload_dispute_photo_1.jpg'), findsOneWidget);

    repo.held.complete(
      const EscalateResult(caseId: 'dispute-uploaded', status: 'pending'),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('upload error preserves the operation UUID across retry', (
    tester,
  ) async {
    final repo = _UploadRepo(failUpload: true);
    await tester.pumpWidget(build(repo: repo, photoPicker: _PhotoPicker()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Damaged item'));
    await tester.pump();
    await tester.ensureVisible(byId('dispute_photos_add_cta'));
    await tester.pump();
    await tester.tap(byId('dispute_photos_add_cta'));
    await tester.pumpAndSettle();
    final commentFinder = find.descendant(
      of: byId('dispute_comment_field'),
      matching: find.byType(EditableText),
    );
    await tester.ensureVisible(commentFinder);
    await tester.enterText(commentFinder, 'The box was crushed.');
    await tester.pump();
    await tester.tap(find.text('Submit Report'));
    await tester.pumpAndSettle();

    expect(byId('dispute_error'), findsOneWidget);
    expect(find.textContaining('could not be uploaded'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(commentFinder).controller.text,
      'The box was crushed.',
    );
    await tester.tap(find.text('Submit Report'));
    await tester.pumpAndSettle();

    expect(repo.operationIds, hasLength(2));
    expect(repo.operationIds.last, repo.operationIds.first);
  });

  testWidgets('discard deletes the app-owned recorded voice clip', (
    tester,
  ) async {
    final recorder = _CleanupVoiceRecorder();
    await tester.pumpWidget(build(voiceRecorder: recorder));
    await tester.pumpAndSettle();
    await captureVoice(tester, recorder);

    await tester.tap(find.text('Re-record'));
    await tester.pumpAndSettle();

    expect(recorder.deletedPaths, <String>[recorder.path]);
    expect(find.text('Re-record'), findsNothing);
  });

  testWidgets('successful submission deletes the recorded voice before route', (
    tester,
  ) async {
    final recorder = _CleanupVoiceRecorder();
    await tester.pumpWidget(build(voiceRecorder: recorder));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Damaged item'));
    await tester.pump();
    await captureVoice(tester, recorder);

    await tester.tap(find.text('Submit Report'));
    await tester.pumpAndSettle();

    expect(recorder.deletedPaths, <String>[recorder.path]);
    expect(find.text('dispute-status:dispute-999'), findsOneWidget);
  });

  testWidgets('navigation disposes and deletes a captured voice clip', (
    tester,
  ) async {
    final recorder = _CleanupVoiceRecorder();
    await tester.pumpWidget(build(voiceRecorder: recorder));
    await tester.pumpAndSettle();
    await captureVoice(tester, recorder);

    await tester.ensureVisible(byId('dispute_support_link'));
    await tester.tap(byId('dispute_support_link'));
    await tester.pumpAndSettle();

    expect(find.text('support'), findsOneWidget);
    expect(recorder.deletedPaths, <String>[recorder.path]);
  });

  testWidgets('navigation cancels an active recorder for temp cleanup', (
    tester,
  ) async {
    final recorder = _CleanupVoiceRecorder();
    await tester.pumpWidget(build(voiceRecorder: recorder));
    await tester.pumpAndSettle();
    await tester.ensureVisible(byId('dispute_voice'));
    await tester.tap(byId('dispute_voice'));
    await tester.pump();

    await tester.ensureVisible(byId('dispute_support_link'));
    await tester.tap(byId('dispute_support_link'));
    await tester.pumpAndSettle();

    expect(recorder.cancelCalls, 1);
    expect(find.text('support'), findsOneWidget);
  });
}
