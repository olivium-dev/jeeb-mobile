// NET-08/NET-09 + R6: the upload spine carries timeouts and a CLASSIFIED
// failure, and no English prose ever reaches the progress row.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/case_evidence/data/dio_case_evidence_uploader.dart';
import 'package:jeeb_mobile/features/case_evidence/domain/case_evidence.dart';

const _operationId = '123e4567-e89b-42d3-a456-426614174000';

/// A draft whose only source is a blank path — the "file is unavailable" lane.
const CaseAttachmentDraft _blankPathDraft = CaseAttachmentDraft(
  localId: 'photo-1',
  fileName: 'evidence.jpg',
  contentType: 'image/jpeg',
  kind: CaseAttachmentKind.photo,
  path: '   ',
);

CaseAttachmentDraft _bytesDraft() => CaseAttachmentDraft(
  localId: 'photo-1',
  fileName: 'evidence.jpg',
  contentType: 'image/jpeg',
  kind: CaseAttachmentKind.photo,
  bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
);

ResponseBody _brokerBody(Map<String, Object?> json) => ResponseBody.fromString(
  jsonEncode(json),
  200,
  headers: <String, List<String>>{
    Headers.contentTypeHeader: <String>[Headers.jsonContentType],
  },
);

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._respond);

  final Future<ResponseBody> Function(RequestOptions options) _respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => _respond(options);

  @override
  void close({bool force = false}) {}
}

DioException _dioError(RequestOptions options, DioExceptionType type) =>
    DioException(requestOptions: options, type: type);

/// Broker that always resolves; the upload leg is what each test varies.
_ScriptedAdapter _okBroker([Map<String, Object?>? overrides]) =>
    _ScriptedAdapter(
      (options) async => _brokerBody(<String, Object?>{
        'upload_url': 'https://cdn.test/put',
        'object_ref': 'ref-1',
        ...?overrides,
      }),
    );

DioCaseEvidenceUploader _uploader({
  required HttpClientAdapter broker,
  HttpClientAdapter? upload,
  Dio? uploadDio,
}) {
  final gatewayDio = Dio(BaseOptions(baseUrl: 'https://gateway.test'))
    ..httpClientAdapter = broker;
  final Dio? injected =
      uploadDio ??
      (upload == null ? null : (Dio()..httpClientAdapter = upload));
  return DioCaseEvidenceUploader(
    gatewayDio,
    slot: CaseEvidenceSlot.disputeEvidence,
    uploadDio: injected,
  );
}

void main() {
  test('the default upload client carries connect/send/receive timeouts', () {
    // NET-08: a bare `Dio()` has none, so a stalled PUT hangs forever.
    final uploader = DioCaseEvidenceUploader(
      Dio(BaseOptions(baseUrl: 'https://gateway.test'))
        ..httpClientAdapter = _okBroker(),
      slot: CaseEvidenceSlot.disputeEvidence,
    );

    const expected = Duration(seconds: 30);
    expect(uploader.uploadDio.options.connectTimeout, expected);
    expect(uploader.uploadDio.options.sendTimeout, expected);
    expect(uploader.uploadDio.options.receiveTimeout, expected);
    expect(Dio().options.sendTimeout, isNull, reason: 'the baseline it fixes');
  });

  test(
    'a sendTimeout classifies as TimeoutFailure and reads as offline',
    () async {
      final uploader = _uploader(
        broker: _okBroker(),
        upload: _ScriptedAdapter(
          (options) async =>
              throw _dioError(options, DioExceptionType.sendTimeout),
        ),
      );

      final progress = <CaseAttachmentProgress>[];
      await expectLater(
        uploader.upload(
          attachment: _bytesDraft(),
          operationId: _operationId,
          onProgress: progress.add,
        ),
        throwsA(
          isA<CaseEvidenceUploadException>()
              .having((e) => e.appFailure, 'appFailure', isA<TimeoutFailure>())
              .having((e) => e.offline, 'offline', isTrue),
        ),
      );
      // R6: repository prose never reaches a rendered slot.
      expect(progress.every((p) => p.message == null), isTrue);
    },
  );

  test('a 503 PUT classifies as ServerFailure(503)', () async {
    final uploader = _uploader(
      broker: _okBroker(),
      upload: _ScriptedAdapter(
        (options) async => ResponseBody.fromString('', 503),
      ),
    );

    await expectLater(
      uploader.upload(attachment: _bytesDraft(), operationId: _operationId),
      throwsA(
        isA<CaseEvidenceUploadException>().having(
          (e) => e.appFailure,
          'appFailure',
          isA<ServerFailure>().having((f) => f.status, 'status', 503),
        ),
      ),
    );
  });

  test('a 4xx PUT classifies as ValidationFailure', () async {
    final uploader = _uploader(
      broker: _okBroker(),
      upload: _ScriptedAdapter(
        (options) async => ResponseBody.fromString('', 422),
      ),
    );

    await expectLater(
      uploader.upload(attachment: _bytesDraft(), operationId: _operationId),
      throwsA(
        isA<CaseEvidenceUploadException>().having(
          (e) => e.appFailure,
          'appFailure',
          isA<ValidationFailure>(),
        ),
      ),
    );
  });

  test('a broker response missing object_ref is a parse failure', () async {
    final uploader = _uploader(
      broker: _ScriptedAdapter(
        (options) async => _brokerBody(<String, Object?>{
          'upload_url': 'https://cdn.test/put',
        }),
      ),
      upload: _ScriptedAdapter(
        (options) async => ResponseBody.fromString('', 200),
      ),
    );

    await expectLater(
      uploader.upload(attachment: _bytesDraft(), operationId: _operationId),
      throwsA(
        isA<CaseEvidenceUploadException>().having(
          (e) => e.appFailure,
          'appFailure',
          isA<UnknownFailure>().having((f) => f.parse, 'parse', isTrue),
        ),
      ),
    );
  });

  test('an attachment with no readable source is UnknownFailure', () async {
    final uploader = _uploader(
      broker: _okBroker(),
      upload: _ScriptedAdapter(
        (options) async => ResponseBody.fromString('', 200),
      ),
    );

    await expectLater(
      uploader.upload(attachment: _blankPathDraft, operationId: _operationId),
      throwsA(
        isA<CaseEvidenceUploadException>()
            .having((e) => e.appFailure, 'appFailure', isA<UnknownFailure>())
            .having((e) => e.offline, 'offline', isFalse),
      ),
    );
  });

  test('appFailure falls back to NetworkFailure when only offline is set', () {
    const exception = CaseEvidenceUploadException('diag', offline: true);
    expect(exception.appFailure, isA<NetworkFailure>());
    expect((exception.appFailure as NetworkFailure).offline, isTrue);
  });
}
