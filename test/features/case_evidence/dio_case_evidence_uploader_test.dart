import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/case_evidence/data/dio_case_evidence_uploader.dart';
import 'package:jeeb_mobile/features/case_evidence/domain/case_evidence.dart';

const _operationId = '123e4567-e89b-42d3-a456-426614174000';

void main() {
  for (final entry in <CaseEvidenceSlot, String>{
    CaseEvidenceSlot.disputeEvidence: 'dispute_evidence',
    CaseEvidenceSlot.supportAttachment: 'support_attachment',
  }.entries) {
    test('requests the ${entry.value} gateway CDN slot', () async {
      final brokerAdapter = _BrokerAdapter();
      final uploadAdapter = _UploadAdapter();
      final gatewayDio = Dio(BaseOptions(baseUrl: 'https://gateway.test'))
        ..httpClientAdapter = brokerAdapter;
      final uploadDio = Dio()..httpClientAdapter = uploadAdapter;
      final uploader = DioCaseEvidenceUploader(
        gatewayDio,
        slot: entry.key,
        uploadDio: uploadDio,
      );

      final uploaded = await uploader.upload(
        attachment: CaseAttachmentDraft(
          localId: 'photo-1',
          fileName: 'proof.jpg',
          contentType: 'image/jpeg',
          kind: CaseAttachmentKind.photo,
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
        ),
        operationId: _operationId,
      );

      expect(brokerAdapter.body['slot'], entry.value);
      expect(brokerAdapter.body['operation_id'], _operationId);
      expect(brokerAdapter.idempotencyKey, '$_operationId:photo-1');
      expect(uploadAdapter.calls, 1);
      expect(uploaded.objectRef, '${entry.value}/proof.jpg');
    });
  }
}

class _BrokerAdapter implements HttpClientAdapter {
  Map<String, dynamic> body = <String, dynamic>{};
  String? idempotencyKey;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    body = Map<String, dynamic>.from(options.data as Map);
    idempotencyKey = options.headers['Idempotency-Key'] as String?;
    return ResponseBody.fromString(
      jsonEncode(<String, Object?>{
        'upload_url': 'https://cdn.test/upload',
        'object_ref': '${body['slot']}/proof.jpg',
        'method': 'PUT',
      }),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }
}

class _UploadAdapter implements HttpClientAdapter {
  int calls = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromString('', 200);
  }
}
