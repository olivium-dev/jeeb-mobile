// ESC-06/ESC-07: no dead Retry on a terminal failure, and the v1 submit path
// uploads before it POSTs instead of sending device paths as CDN refs.

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/case_evidence/domain/case_evidence.dart';
import 'package:jeeb_mobile/features/escalate/application/escalate_cubit.dart';
import 'package:jeeb_mobile/features/escalate/data/dio_escalate_repository.dart';
import 'package:jeeb_mobile/features/escalate/domain/escalate_repository.dart';
import 'package:jeeb_mobile/features/escalate/presentation/escalate_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _FailingRepo implements EscalateRepository {
  const _FailingRepo(this.kind, this.failure);

  final EscalateErrorKind kind;
  final AppFailure failure;

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
  }) async => throw EscalateException.classified(kind, failure: failure);
}

/// Records what the v1 path handed the uploader and what it POSTed.
class _RecordingUploader implements CaseEvidenceUploader {
  final List<CaseAttachmentDraft> drafts = <CaseAttachmentDraft>[];

  @override
  Future<UploadedCaseAttachment> upload({
    required CaseAttachmentDraft attachment,
    required String operationId,
    CaseAttachmentProgressCallback? onProgress,
  }) async {
    drafts.add(attachment);
    return UploadedCaseAttachment(
      localId: attachment.localId,
      objectRef: 'cdn://${attachment.localId}',
      fileName: attachment.fileName,
      contentType: attachment.contentType,
      kind: attachment.kind,
    );
  }
}

class _CapturingAdapter implements HttpClientAdapter {
  final List<Object?> bodies = <Object?>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    bodies.add(options.data);
    return ResponseBody.fromString(
      '{"id":"dispute-1","status":"open"}',
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  final delegates =
      (wrapForTest(const SizedBox()) as MaterialApp).localizationsDelegates!;

  Widget build(EscalateRepository repo, {Locale locale = const Locale('en')}) =>
      MaterialApp(
        theme: AppTheme.midnight(),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: delegates,
        home: BlocProvider<EscalateCubit>(
          create: (_) =>
              EscalateCubit(repository: repo, deliveryId: 'dlv-1')
                ..setReason(EscalateReason.other),
          child: const EscalateScreen(),
        ),
      );

  Finder byId(String id) => find.bySemanticsIdentifier(id);

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(byId('dispute_submit_cta'));
    await tester.tap(byId('dispute_submit_cta'));
    await tester.pumpAndSettle();
  }

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final tag = locale.languageCode;

    testWidgets('[$tag] notFound gets the way out, never a Retry that 404s', (
      tester,
    ) async {
      useReduceMotion(tester);
      await tester.pumpWidget(
        build(
          const _FailingRepo(EscalateErrorKind.notFound, NotFoundFailure()),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();
      await submit(tester);

      expect(byId('dispute_error'), findsOneWidget);
      expect(byId('dispute_error_exit_cta'), findsOneWidget);
      expect(byId('dispute_error_retry_cta'), findsNothing);
    });

    testWidgets('[$tag] alreadyOpen gets the way out too', (tester) async {
      useReduceMotion(tester);
      await tester.pumpWidget(
        build(
          const _FailingRepo(EscalateErrorKind.alreadyOpen, ConflictFailure()),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();
      await submit(tester);

      expect(byId('dispute_error_exit_cta'), findsOneWidget);
      expect(byId('dispute_error_retry_cta'), findsNothing);
    });
  }

  testWidgets('a network failure keeps a real Retry', (tester) async {
    useReduceMotion(tester);
    await tester.pumpWidget(
      build(
        const _FailingRepo(
          EscalateErrorKind.network,
          NetworkFailure(offline: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await submit(tester);

    expect(byId('dispute_error_retry_cta'), findsOneWidget);
  });

  test(
    'the v1 submit path uploads first and never POSTs a device path',
    () async {
      final uploader = _RecordingUploader();
      final adapter = _CapturingAdapter();
      final repository = DioEscalateRepository(
        Dio(BaseOptions(baseUrl: 'https://gateway.test'))
          ..httpClientAdapter = adapter,
        evidenceUploader: uploader,
      );

      await repository.submitEscalation(
        deliveryId: 'dlv-1',
        reason: EscalateReason.damaged,
        photoPaths: const <String>['/device/local/photo-1.jpg'],
        voicePath: '/device/local/voice.m4a',
      );

      // ESC-07: the local paths reached the UPLOADER, not the dispute body.
      expect(uploader.drafts, hasLength(2));
      expect(uploader.drafts.first.path, '/device/local/photo-1.jpg');

      final body = adapter.bodies.single! as Map<String, Object?>;
      expect(body['photos'], <String>['cdn:///device/local/photo-1.jpg']);
      expect(body['voiceUrl'], 'cdn://voice');
      expect(
        (body['photos']! as List).first.toString().startsWith('cdn://'),
        isTrue,
        reason: 'a garbage device path as an object ref loses the evidence',
      );
    },
  );
}
