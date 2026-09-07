import 'dart:typed_data';

import '../../../core/network/app_failure.dart';

enum CaseAttachmentKind { photo, voice, file }

class CaseAttachmentDraft {
  const CaseAttachmentDraft({
    required this.localId,
    required this.fileName,
    required this.contentType,
    required this.kind,
    this.bytes,
    this.path,
  }) : assert(bytes != null || path != null);

  final String localId;
  final String fileName;
  final String contentType;
  final CaseAttachmentKind kind;
  final Uint8List? bytes;
  final String? path;
}

enum CaseAttachmentUploadState { queued, uploading, uploaded, failed }

class CaseAttachmentProgress {
  const CaseAttachmentProgress({
    required this.localId,
    required this.state,
    this.sentBytes = 0,
    this.totalBytes = 0,
    this.objectRef,
    this.message,
  });

  final String localId;
  final CaseAttachmentUploadState state;
  final int sentBytes;
  final int totalBytes;
  final String? objectRef;
  final String? message;

  double get fraction {
    if (state == CaseAttachmentUploadState.uploaded) return 1;
    if (totalBytes <= 0) return 0;
    return (sentBytes / totalBytes).clamp(0, 1);
  }
}

class UploadedCaseAttachment {
  const UploadedCaseAttachment({
    required this.localId,
    required this.objectRef,
    required this.fileName,
    required this.contentType,
    required this.kind,
  });

  final String localId;
  final String objectRef;
  final String fileName;
  final String contentType;
  final CaseAttachmentKind kind;

  Map<String, Object?> toJson() => <String, Object?>{
    'objectRef': objectRef,
    'fileName': fileName,
    'contentType': contentType,
    'kind': kind.name,
  };
}

typedef CaseAttachmentProgressCallback =
    void Function(CaseAttachmentProgress progress);

abstract class CaseEvidenceUploader {
  Future<UploadedCaseAttachment> upload({
    required CaseAttachmentDraft attachment,
    required String operationId,
    CaseAttachmentProgressCallback? onProgress,
  });
}

class CaseEvidenceUploadException implements Exception {
  const CaseEvidenceUploadException(
    this.message, {
    this.offline = false,
    this.failure,
  });

  /// DIAGNOSTIC ONLY — never rendered to a user; the copy comes from
  /// [appFailure] through `failureCopy`.
  final String message;
  final bool offline;

  /// The classified failure, when the thrower could produce one.
  final AppFailure? failure;

  AppFailure get appFailure =>
      failure ??
      (offline ? const NetworkFailure(offline: true) : const UnknownFailure());

  @override
  String toString() => 'CaseEvidenceUploadException($message)';
}
