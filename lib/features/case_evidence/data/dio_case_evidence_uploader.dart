import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../domain/case_evidence.dart';

enum CaseEvidenceSlot {
  disputeEvidence('dispute_evidence'),
  supportAttachment('support_attachment');

  const CaseEvidenceSlot(this.wireValue);

  final String wireValue;
}

/// Uploads case evidence through the gateway-owned CDN broker contract.
///
/// The mobile app never addresses a Jeeb microservice. The broker returns an
/// opaque upload URL and object reference; only that reference is sent in a
/// dispute or support payload.
class DioCaseEvidenceUploader implements CaseEvidenceUploader {
  DioCaseEvidenceUploader(
    this._gatewayDio, {
    required CaseEvidenceSlot slot,
    Dio? uploadDio,
  }) : _slot = slot,
       _uploadDio = uploadDio ?? Dio();

  static const String _brokerPath = '/api/cdn/assets';

  final Dio _gatewayDio;
  final Dio _uploadDio;
  final CaseEvidenceSlot _slot;

  @override
  Future<UploadedCaseAttachment> upload({
    required CaseAttachmentDraft attachment,
    required String operationId,
    CaseAttachmentProgressCallback? onProgress,
  }) async {
    try {
      final bytes = await _bytes(attachment);
      final broker = await _gatewayDio.post<Map<String, dynamic>>(
        _brokerPath,
        data: <String, Object?>{
          'slot': _slot.wireValue,
          'content_type': attachment.contentType,
          'file_name': attachment.fileName,
          'kind': attachment.kind.name,
          'operation_id': operationId,
        },
        options: Options(
          headers: <String, Object?>{
            'Idempotency-Key': '$operationId:${attachment.localId}',
          },
        ),
      );
      final data = broker.data ?? const <String, dynamic>{};
      final uploadUrl = _requiredString(data, 'upload_url');
      final objectRef = _requiredString(data, 'object_ref');
      final headers = _headers(data['required_headers']);
      final method = _string(data['method'])?.toUpperCase() ?? 'PUT';

      onProgress?.call(
        CaseAttachmentProgress(
          localId: attachment.localId,
          state: CaseAttachmentUploadState.uploading,
          totalBytes: bytes.length,
        ),
      );
      final response = await _uploadDio.request<void>(
        uploadUrl,
        data: bytes,
        options: Options(
          method: method,
          headers: headers,
          contentType: attachment.contentType,
          responseType: ResponseType.plain,
          validateStatus: (_) => true,
        ),
        onSendProgress: (sent, total) => onProgress?.call(
          CaseAttachmentProgress(
            localId: attachment.localId,
            state: CaseAttachmentUploadState.uploading,
            sentBytes: sent,
            totalBytes: total > 0 ? total : bytes.length,
          ),
        ),
      );
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        throw CaseEvidenceUploadException('Evidence upload returned $status.');
      }
      onProgress?.call(
        CaseAttachmentProgress(
          localId: attachment.localId,
          state: CaseAttachmentUploadState.uploaded,
          sentBytes: bytes.length,
          totalBytes: bytes.length,
          objectRef: objectRef,
        ),
      );
      return UploadedCaseAttachment(
        localId: attachment.localId,
        objectRef: objectRef,
        fileName: attachment.fileName,
        contentType: attachment.contentType,
        kind: attachment.kind,
      );
    } on CaseEvidenceUploadException {
      rethrow;
    } on DioException catch (error) {
      throw CaseEvidenceUploadException(
        error.message ?? 'Evidence upload failed.',
        offline: _isOffline(error),
      );
    } on FileSystemException catch (error) {
      throw CaseEvidenceUploadException(error.message);
    }
  }

  Future<Uint8List> _bytes(CaseAttachmentDraft attachment) async {
    final bytes = attachment.bytes;
    if (bytes != null) return bytes;
    final path = attachment.path;
    if (path == null || path.trim().isEmpty) {
      throw const CaseEvidenceUploadException('Evidence file is unavailable.');
    }
    return File(path).readAsBytes();
  }

  static String _requiredString(Map<String, dynamic> data, String key) {
    final value = _string(data[key]);
    if (value == null) {
      throw CaseEvidenceUploadException('Gateway response is missing $key.');
    }
    return value;
  }

  static String? _string(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static Map<String, String> _headers(Object? value) {
    if (value is! Map) return const <String, String>{};
    return value.map((key, item) => MapEntry('$key', '$item'));
  }

  static bool _isOffline(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout => true,
      _ => false,
    };
  }
}
