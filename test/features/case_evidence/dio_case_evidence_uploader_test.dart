import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/observability/session_trace/capture/obs_dio_interceptor.dart';
import 'package:jeeb_mobile/core/observability/session_trace/model/obs_event.dart';
import 'package:jeeb_mobile/core/observability/session_trace/observability.dart';
import 'package:jeeb_mobile/core/observability/session_trace/observability_config.dart';
import 'package:jeeb_mobile/core/observability/session_trace/secret_redactor.dart';
import 'package:jeeb_mobile/features/case_evidence/data/dio_case_evidence_uploader.dart';
import 'package:jeeb_mobile/features/case_evidence/domain/case_evidence.dart';

const _operationId = '123e4567-e89b-42d3-a456-426614174000';

void main() {
  setUp(() {
    Observability.instance.resetForTest();
    ObservabilityConfig.instance.reset();
  });

  tearDown(() {
    Observability.instance.resetForTest();
    ObservabilityConfig.instance.reset();
  });

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

  test('the signed upload Dio is attached once and records only scrubbed URL + '
      'binary byte summary', () async {
    final brokerAdapter = _BrokerAdapter();
    final uploadAdapter = _UploadAdapter();
    final gatewayDio = Dio(BaseOptions(baseUrl: 'https://gateway.test'))
      ..httpClientAdapter = brokerAdapter;
    final uploadDio = Dio()..httpClientAdapter = uploadAdapter;
    final uploader = DioCaseEvidenceUploader(
      gatewayDio,
      slot: CaseEvidenceSlot.disputeEvidence,
      uploadDio: uploadDio,
    );
    ObsDioInterceptor.attachTo(uploadDio);
    expect(
      uploadDio.interceptors.whereType<ObsDioInterceptor>(),
      hasLength(kObsCompiledIn ? 1 : 0),
    );
    final sink = _FakeSink();
    Observability.instance.sink = sink;
    Observability.instance.setSessionForTest('upload-session');
    ObservabilityConfig.instance.enabled = true;

    await uploader.upload(
      attachment: CaseAttachmentDraft(
        localId: 'photo-1',
        fileName: 'proof.jpg',
        contentType: 'image/jpeg',
        kind: CaseAttachmentKind.photo,
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
      ),
      operationId: _operationId,
    );

    final event = sink.events.single as ObsApiEvent;
    expect(event.method, 'PUT');
    expect(event.path, SecretRedactor.externalUploadPath);
    expect(event.requestBody, <String, Object?>{'_bytes': 3});
    expect(jsonEncode(event.toJson()), isNot(contains('signed-secret')));
  }, skip: !kObsCompiledIn);
}

final class _FakeSink implements ObservabilitySink {
  final List<ObsEvent> events = <ObsEvent>[];

  @override
  void add(ObsEvent event, {bool flushNow = false}) => events.add(event);

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}

  @override
  String? get sessionFilePath => '/tmp/case-upload-trace.jsonl';
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
        'upload_url':
            'https://cdn.test/upload?signature=signed-secret#private-fragment',
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
