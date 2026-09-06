import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/idempotency/operation_id.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/app_failure_mapper.dart';
import '../../case_evidence/data/dio_case_evidence_uploader.dart';
import '../../case_evidence/domain/case_evidence.dart';
import '../domain/escalate_repository.dart';

class DioEscalateRepository
    implements EscalateRepository, EscalateV2Repository {
  DioEscalateRepository(
    this._dio, {
    bool? originGateway,
    CaseEvidenceUploader? evidenceUploader,
  }) : _evidenceUploader =
           evidenceUploader ??
           DioCaseEvidenceUploader(
             _dio,
             slot: CaseEvidenceSlot.disputeEvidence,
           );

  final Dio _dio;

  final CaseEvidenceUploader _evidenceUploader;
  final Map<String, UploadedCaseAttachment> _uploaded =
      <String, UploadedCaseAttachment>{};
  final Map<String, Future<UploadedCaseAttachment>> _uploadsInFlight =
      <String, Future<UploadedCaseAttachment>>{};

  @override
  Future<EscalateEvidence> fetchEvidence({required String deliveryId}) {
    // Canonical evidence is captured by the gateway when the dispute is
    // created. Mobile has no evidence-preview endpoint and performs no fanout.
    return Future<EscalateEvidence>.value(EscalateEvidence.empty);
  }

  @override
  Future<EscalateResult> submitEscalation({
    required String deliveryId,
    required EscalateReason reason,
    String? comment,
    List<String> photoPaths = const [],
    String? voicePath,
    EscalateEvidence evidence = EscalateEvidence.empty,
  }) {
    // A local device path is not a CDN object ref: the drafts go through
    // submitReport, which uploads first (ESC-07).
    final drafts = <CaseAttachmentDraft>[
      for (final path in photoPaths.take(5))
        CaseAttachmentDraft(
          localId: path,
          path: path,
          fileName: path.split('/').last,
          contentType: 'image/jpeg',
          kind: CaseAttachmentKind.photo,
        ),
      if (voicePath != null && voicePath.isNotEmpty)
        CaseAttachmentDraft(
          localId: 'voice',
          path: voicePath,
          fileName: voicePath.split('/').last,
          contentType: 'audio/mp4',
          kind: CaseAttachmentKind.voice,
        ),
    ];
    return submitReport(
      EscalateSubmission(
        operationId: newOperationId(),
        deliveryId: deliveryId,
        reason: reason,
        comment: comment,
        evidence: evidence,
        attachments: drafts,
      ),
    );
  }

  @override
  Future<EscalateResult> submitReport(
    EscalateSubmission submission, {
    CaseAttachmentProgressCallback? onProgress,
  }) async {
    final uploaded = <UploadedCaseAttachment>[];
    for (final attachment in submission.attachments) {
      final cacheKey = '${submission.operationId}:${attachment.localId}';
      final cached = _uploaded[cacheKey];
      if (cached != null) {
        uploaded.add(cached);
        onProgress?.call(
          CaseAttachmentProgress(
            localId: attachment.localId,
            state: CaseAttachmentUploadState.uploaded,
            objectRef: cached.objectRef,
          ),
        );
        continue;
      }
      try {
        final inFlight = _uploadsInFlight[cacheKey];
        if (inFlight != null) {
          final item = await inFlight;
          uploaded.add(item);
          onProgress?.call(
            CaseAttachmentProgress(
              localId: attachment.localId,
              state: CaseAttachmentUploadState.uploaded,
              objectRef: item.objectRef,
            ),
          );
          continue;
        }
        final upload = _evidenceUploader
            .upload(
              attachment: attachment,
              operationId: submission.operationId,
              onProgress: onProgress,
            )
            .then((item) {
              _uploaded[cacheKey] = item;
              return item;
            });
        _uploadsInFlight[cacheKey] = upload;
        final item = await upload;
        uploaded.add(item);
      } on CaseEvidenceUploadException catch (error) {
        // No message: the screen renders the failure kind, never repo prose.
        onProgress?.call(
          CaseAttachmentProgress(
            localId: attachment.localId,
            state: CaseAttachmentUploadState.failed,
          ),
        );
        throw EscalateException.classified(
          error.offline
              ? EscalateErrorKind.network
              : EscalateErrorKind.evidenceUpload,
          cause: error,
          failure: error.appFailure,
        );
      } finally {
        _uploadsInFlight.remove(cacheKey);
      }
    }
    return _postReport(
      operationId: submission.operationId,
      deliveryId: submission.deliveryId,
      reason: submission.reason,
      comment: submission.comment,
      attachments: uploaded,
    );
  }

  Future<EscalateResult> _postReport({
    required String operationId,
    required String deliveryId,
    required EscalateReason reason,
    required String? comment,
    required List<UploadedCaseAttachment> attachments,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/deliveries/$deliveryId/escalate',
        data: _disputeBody(
          operationId: operationId,
          deliveryId: deliveryId,
          reason: reason,
          comment: comment,
          attachments: attachments,
        ),
        options: Options(
          headers: <String, Object?>{'Idempotency-Key': operationId},
        ),
      );
      return EscalateResult.fromJson(response.data ?? const {});
    } on DioException catch (e) {
      final existingId = _existingDisputeId(e.response?.data);
      if (e.response?.statusCode == 409 && existingId != null) {
        return EscalateResult(caseId: existingId, status: 'pending');
      }
      throw EscalateException.classified(
        _mapDioError(e),
        cause: e,
        failure: AppFailure.of(e),
      );
    } on IOException catch (e) {
      throw EscalateException.classified(
        EscalateErrorKind.network,
        cause: e,
        failure: networkFailureFromReachability(cause: e),
      );
    }
  }

  Map<String, Object?> _disputeBody({
    required String operationId,
    required String deliveryId,
    required EscalateReason reason,
    required String? comment,
    required List<UploadedCaseAttachment> attachments,
  }) {
    final photos = attachments
        .where((item) => item.kind == CaseAttachmentKind.photo)
        .map((item) => item.objectRef)
        .take(5)
        .toList(growable: false);
    final voices = attachments
        .where((item) => item.kind == CaseAttachmentKind.voice)
        .toList(growable: false);
    return <String, Object?>{
      'operationId': operationId,
      'deliveryId': deliveryId,
      'requestId': deliveryId,
      'reason': _reasonParam(reason),
      if (comment != null && comment.isNotEmpty) 'comment': comment,
      'photos': photos,
      if (voices.isNotEmpty) 'voiceUrl': voices.first.objectRef,
      if (photos.isNotEmpty) 'attachments': photos,
    };
  }

  String? _existingDisputeId(Object? body) {
    if (body is! Map) return null;
    for (final key in const <String>[
      'existingCaseId',
      'existingDisputeId',
      'disputeId',
      'caseId',
      'id',
    ]) {
      final value = body[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    final nested = _existingDisputeId(body['extensions'] ?? body['data']);
    if (nested != null) return nested;
    final detail = body['detail'];
    if (detail is! String) return null;
    final match = RegExp(r'Existing case id:\s*([^\s.]+)').firstMatch(detail);
    return match?.group(1);
  }

  EscalateErrorKind _mapDioError(DioException e) {
    if (e.response == null) {
      switch (e.type) {
        case DioExceptionType.connectionError:
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return EscalateErrorKind.network;
        default:
          return EscalateErrorKind.server;
      }
    }
    switch (e.response!.statusCode) {
      case 404:
        return EscalateErrorKind.notFound;
      case 409:
        return EscalateErrorKind.alreadyOpen;
      default:
        return EscalateErrorKind.server;
    }
  }

  static String _reasonParam(EscalateReason reason) {
    switch (reason) {
      case EscalateReason.damaged:
        return 'damaged';
      case EscalateReason.wrongItem:
        return 'wrong_item';
      case EscalateReason.noShow:
        return 'no_show';
      case EscalateReason.fraud:
        return 'fraud';
      case EscalateReason.abuse:
        return 'abuse';
      case EscalateReason.other:
        return 'other';
    }
  }
}
