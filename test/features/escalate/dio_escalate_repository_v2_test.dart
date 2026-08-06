import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/case_evidence/domain/case_evidence.dart';
import 'package:jeeb_mobile/features/escalate/data/dio_escalate_repository.dart';
import 'package:jeeb_mobile/features/escalate/domain/escalate_repository.dart';

const _operationId = '123e4567-e89b-42d3-a456-426614174000';

void main() {
  test(
    'retry reuses its UUID and uploaded evidence without a duplicate case',
    () async {
      final adapter = _EscalateAdapter(failFirstReport: true);
      final dio = Dio(BaseOptions(baseUrl: 'https://gateway.test'))
        ..httpClientAdapter = adapter;
      final uploader = _FakeUploader();
      final repository = DioEscalateRepository(
        dio,
        originGateway: true,
        evidenceUploader: uploader,
      );
      final progress = <CaseAttachmentUploadState>[];
      final submission = EscalateSubmission(
        operationId: _operationId,
        deliveryId: 'delivery-1',
        reason: EscalateReason.damaged,
        comment: 'The package was crushed.',
        evidence: const EscalateEvidence(missingSources: <String>['chat']),
        attachments: <CaseAttachmentDraft>[
          CaseAttachmentDraft(
            localId: 'photo-1',
            fileName: 'damage.jpg',
            contentType: 'image/jpeg',
            kind: CaseAttachmentKind.photo,
            bytes: Uint8List.fromList(<int>[1, 2, 3]),
          ),
        ],
      );

      await expectLater(
        repository.submitReport(submission),
        throwsA(
          isA<EscalateException>().having(
            (error) => error.kind,
            'kind',
            EscalateErrorKind.network,
          ),
        ),
      );
      final result = await repository.submitReport(
        submission,
        onProgress: (item) => progress.add(item.state),
      );

      expect(result.caseId, 'dispute-1');
      expect(result.status, 'pending');
      expect(uploader.calls, 1);
      expect(adapter.reportPaths, <String>[
        '/v1/deliveries/delivery-1/escalate',
        '/v1/deliveries/delivery-1/escalate',
      ]);
      expect(adapter.idempotencyKeys, everyElement(_operationId));
      expect(adapter.reportBodies, hasLength(2));
      expect(
        adapter.reportBodies.map((body) => body['operationId']),
        everyElement(_operationId),
      );
      expect(adapter.reportBodies.last.containsKey('evidence'), isFalse);
      expect(
        adapter.reportBodies.last.containsKey('evidenceCompleteness'),
        isFalse,
      );
      expect(
        (adapter.reportBodies.last['photos'] as List<Object?>).single,
        'case-evidence/photo-1',
      );
      expect(adapter.reportBodies.last['attachments'], <String>[
        'case-evidence/photo-1',
      ]);
      expect(progress, contains(CaseAttachmentUploadState.uploaded));
      expect(
        adapter.reportPaths.any((path) => path.contains('service')),
        isFalse,
      );
    },
  );

  test(
    'a conflict carrying existingCaseId recovers as one submission',
    () async {
      final adapter = _EscalateAdapter(conflictReport: true);
      final dio = Dio(BaseOptions(baseUrl: 'https://gateway.test'))
        ..httpClientAdapter = adapter;
      final repository = DioEscalateRepository(
        dio,
        originGateway: true,
        evidenceUploader: _FakeUploader(),
      );

      final result = await repository.submitReport(
        const EscalateSubmission(
          operationId: _operationId,
          deliveryId: 'delivery-1',
          reason: EscalateReason.other,
          evidence: EscalateEvidence.empty,
        ),
      );

      expect(result.caseId, 'dispute-existing');
      expect(result.status, 'pending');
      expect(adapter.reportPaths, hasLength(1));
    },
  );

  test('five photos are attachments and voice is only voiceUrl', () async {
    final adapter = _EscalateAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://gateway.test'))
      ..httpClientAdapter = adapter;
    final uploader = _FakeUploader();
    final repository = DioEscalateRepository(dio, evidenceUploader: uploader);
    final photos = <CaseAttachmentDraft>[
      for (var index = 0; index < 5; index++)
        CaseAttachmentDraft(
          localId: 'photo-$index',
          fileName: 'photo-$index.jpg',
          contentType: 'image/jpeg',
          kind: CaseAttachmentKind.photo,
          bytes: Uint8List.fromList(<int>[index]),
        ),
    ];
    final voice = CaseAttachmentDraft(
      localId: 'voice',
      fileName: 'voice.m4a',
      contentType: 'audio/mp4',
      kind: CaseAttachmentKind.voice,
      bytes: Uint8List.fromList(<int>[9, 8, 7]),
    );

    await repository.submitReport(
      EscalateSubmission(
        operationId: _operationId,
        deliveryId: 'delivery-1',
        reason: EscalateReason.damaged,
        evidence: EscalateEvidence.empty,
        attachments: <CaseAttachmentDraft>[...photos, voice],
      ),
    );

    final body = adapter.reportBodies.single;
    final expectedPhotos = <String>[
      for (var index = 0; index < 5; index++) 'case-evidence/photo-$index',
    ];
    expect(body['photos'], expectedPhotos);
    expect(body['attachments'], expectedPhotos);
    expect(body['voiceUrl'], 'case-evidence/voice');
    expect(
      (body['attachments'] as List<Object?>),
      isNot(contains('case-evidence/voice')),
    );
    expect(uploader.calls, 6);
  });

  test('overlapping retries share one in-flight evidence upload', () async {
    final adapter = _EscalateAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://gateway.test'))
      ..httpClientAdapter = adapter;
    final uploader = _DelayedUploader();
    final repository = DioEscalateRepository(
      dio,
      originGateway: true,
      evidenceUploader: uploader,
    );
    final submission = EscalateSubmission(
      operationId: _operationId,
      deliveryId: 'delivery-1',
      reason: EscalateReason.damaged,
      evidence: EscalateEvidence.empty,
      attachments: <CaseAttachmentDraft>[
        CaseAttachmentDraft(
          localId: 'photo-1',
          fileName: 'damage.jpg',
          contentType: 'image/jpeg',
          kind: CaseAttachmentKind.photo,
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
        ),
      ],
    );

    final first = repository.submitReport(submission);
    final second = repository.submitReport(submission);
    await Future<void>.delayed(Duration.zero);
    expect(uploader.calls, 1);

    uploader.complete();
    await Future.wait(<Future<EscalateResult>>[first, second]);
    expect(uploader.calls, 1);
    expect(adapter.reportPaths, hasLength(2));
    expect(adapter.idempotencyKeys, everyElement(_operationId));
  });

  test('a failed client upload is attempted again on retry', () async {
    final adapter = _EscalateAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://gateway.test'))
      ..httpClientAdapter = adapter;
    final uploader = _FailOnceUploader();
    final repository = DioEscalateRepository(dio, evidenceUploader: uploader);
    final submission = EscalateSubmission(
      operationId: _operationId,
      deliveryId: 'delivery-1',
      reason: EscalateReason.damaged,
      evidence: EscalateEvidence.empty,
      attachments: <CaseAttachmentDraft>[
        CaseAttachmentDraft(
          localId: 'photo-1',
          fileName: 'damage.jpg',
          contentType: 'image/jpeg',
          kind: CaseAttachmentKind.photo,
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
        ),
      ],
    );

    await expectLater(
      repository.submitReport(submission),
      throwsA(
        isA<EscalateException>().having(
          (error) => error.kind,
          'kind',
          EscalateErrorKind.evidenceUpload,
        ),
      ),
    );
    final result = await repository.submitReport(submission);

    expect(result.caseId, 'dispute-1');
    expect(uploader.calls, 2);
    expect(adapter.reportPaths, hasLength(1));
  });
}

class _FakeUploader implements CaseEvidenceUploader {
  int calls = 0;

  @override
  Future<UploadedCaseAttachment> upload({
    required CaseAttachmentDraft attachment,
    required String operationId,
    CaseAttachmentProgressCallback? onProgress,
  }) async {
    calls++;
    onProgress?.call(
      CaseAttachmentProgress(
        localId: attachment.localId,
        state: CaseAttachmentUploadState.uploading,
        sentBytes: 1,
        totalBytes: 3,
      ),
    );
    onProgress?.call(
      CaseAttachmentProgress(
        localId: attachment.localId,
        state: CaseAttachmentUploadState.uploaded,
        sentBytes: 3,
        totalBytes: 3,
        objectRef: 'case-evidence/${attachment.localId}',
      ),
    );
    return UploadedCaseAttachment(
      localId: attachment.localId,
      objectRef: 'case-evidence/${attachment.localId}',
      fileName: attachment.fileName,
      contentType: attachment.contentType,
      kind: attachment.kind,
    );
  }
}

class _DelayedUploader implements CaseEvidenceUploader {
  int calls = 0;
  final Completer<void> _release = Completer<void>();

  void complete() => _release.complete();

  @override
  Future<UploadedCaseAttachment> upload({
    required CaseAttachmentDraft attachment,
    required String operationId,
    CaseAttachmentProgressCallback? onProgress,
  }) async {
    calls++;
    await _release.future;
    return UploadedCaseAttachment(
      localId: attachment.localId,
      objectRef: 'case-evidence/${attachment.localId}',
      fileName: attachment.fileName,
      contentType: attachment.contentType,
      kind: attachment.kind,
    );
  }
}

class _FailOnceUploader implements CaseEvidenceUploader {
  int calls = 0;

  @override
  Future<UploadedCaseAttachment> upload({
    required CaseAttachmentDraft attachment,
    required String operationId,
    CaseAttachmentProgressCallback? onProgress,
  }) async {
    calls++;
    if (calls == 1) {
      throw const CaseEvidenceUploadException('CDN upload failed.');
    }
    return UploadedCaseAttachment(
      localId: attachment.localId,
      objectRef: 'case-evidence/${attachment.localId}',
      fileName: attachment.fileName,
      contentType: attachment.contentType,
      kind: attachment.kind,
    );
  }
}

class _EscalateAdapter implements HttpClientAdapter {
  _EscalateAdapter({this.failFirstReport = false, this.conflictReport = false});

  final bool failFirstReport;
  final bool conflictReport;
  final List<String> reportPaths = <String>[];
  final List<String?> idempotencyKeys = <String?>[];
  final List<Map<String, dynamic>> reportBodies = <Map<String, dynamic>>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'POST' && options.path.endsWith('/escalate')) {
      reportPaths.add(options.path);
      idempotencyKeys.add(options.headers['Idempotency-Key'] as String?);
      reportBodies.add(Map<String, dynamic>.from(options.data as Map));
      if (failFirstReport && reportPaths.length == 1) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      }
      if (conflictReport) {
        return _json(<String, Object?>{
          'existingCaseId': 'dispute-existing',
        }, status: 409);
      }
      return _json(<String, Object?>{
        'id': 'dispute-1',
        'status': 'pending',
        'version': 1,
      }, status: 201);
    }
    return _json(const <String, Object?>{});
  }
}

ResponseBody _json(Map<String, Object?> body, {int status = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}
