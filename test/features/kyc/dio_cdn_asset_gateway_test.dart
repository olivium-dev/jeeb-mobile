/// JEBV4-259 — KYC ID-photo signed-PUT through a DEDICATED, interceptor-free
/// [Dio] ("approach B": the gateway proxies the PUT to cdn-service and returns
library;

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/idempotency/operation_id.dart';
import 'package:jeeb_mobile/features/kyc/data/dio_cdn_asset_gateway.dart';
import 'package:jeeb_mobile/features/kyc/domain/cdn_asset_gateway.dart';

const _signedUrl =
    'https://signed.cdn.test/api/cdn/put-signed/'
    'selfie_with_liveness?exp=1750000000&ct=jpeg&sig=abc-DEF_123.tok';

void main() {
  // A non-trivial, multi-chunk body so a byte-for-byte comparison is meaningful
  final bytes = Uint8List.fromList(
    List<int>.generate(2048, (i) => (i * 7 + 255) % 256),
  );

  group('DioCdnAssetGateway — broker POST on the shared authenticated Dio', () {
    test('POSTs /api/cdn/assets with slot + content_type', () async {
      final broker = _BrokerRecorder();
      final upload = _UploadRecorder();
      final gateway = DioCdnAssetGateway(broker.dio, uploadDio: upload.dio);

      await gateway.uploadAsset(
        slot: CdnUploadSlot.idDocumentFront,
        bytes: bytes,
      );

      expect(broker.requests.single.method, 'POST');
      expect(broker.requests.single.path, '/api/cdn/assets');
      expect(
        isOperationId(
          broker.requests.single.headers['Idempotency-Key'] as String,
        ),
        isTrue,
      );
      final body = broker.requests.single.data! as Map<String, dynamic>;
      expect(body['slot'], 'id_document_front');
      expect(body['content_type'], 'image/jpeg');
    });

    test('uses a fresh idempotency key for each upload operation', () async {
      final broker = _BrokerRecorder();
      final upload = _UploadRecorder();
      final gateway = DioCdnAssetGateway(broker.dio, uploadDio: upload.dio);

      await gateway.uploadAsset(
        slot: CdnUploadSlot.proofOfDelivery,
        bytes: bytes,
      );
      await gateway.uploadAsset(
        slot: CdnUploadSlot.proofOfDelivery,
        bytes: bytes,
      );

      final keys = broker.requests
          .map((request) => request.headers['Idempotency-Key'] as String)
          .toList();
      expect(keys, hasLength(2));
      expect(keys.toSet(), hasLength(2));
      expect(keys, everyElement(predicate<String>(isOperationId)));
    });

    test('surfaces a broker rejection as CdnUploadException', () async {
      final broker = Dio(BaseOptions(baseUrl: 'https://gateway.test'));
      broker.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException(
              requestOptions: options,
              response: Response<void>(
                requestOptions: options,
                statusCode: 400,
              ),
              type: DioExceptionType.badResponse,
              message: 'HTTP 400',
            ),
          ),
        ),
      );
      final gateway = DioCdnAssetGateway(
        broker,
        uploadDio: _UploadRecorder().dio,
      );

      expect(
        gateway.uploadAsset(slot: CdnUploadSlot.proofOfDelivery, bytes: bytes),
        throwsA(isA<CdnUploadException>()),
      );
    });

    test('maps every CdnUploadSlot to its wire value', () async {
      const expected = <CdnUploadSlot, String>{
        CdnUploadSlot.idDocumentFront: 'id_document_front',
        CdnUploadSlot.idDocumentBack: 'id_document_back',
        CdnUploadSlot.vehicleRegistration: 'vehicle_registration',
        CdnUploadSlot.selfieWithLiveness: 'selfie_with_liveness',
        CdnUploadSlot.proofOfDelivery: 'proof_of_delivery',
        // P4/P5 (b01-20260725): the in-chat camera/gallery attachment slot.
        CdnUploadSlot.chatAttachment: 'chat_attachment',
      };
      // TC-C16: a future slot cannot be added without a mapping assertion here.
      expect(
        expected.length,
        CdnUploadSlot.values.length,
        reason: 'every CdnUploadSlot must have a pinned wire value',
      );
      for (final entry in expected.entries) {
        final broker = _BrokerRecorder();
        final upload = _UploadRecorder();
        final gateway = DioCdnAssetGateway(broker.dio, uploadDio: upload.dio);
        await gateway.uploadAsset(slot: entry.key, bytes: bytes);
        final body = broker.requests.single.data! as Map<String, dynamic>;
        expect(body['slot'], entry.value, reason: 'slot ${entry.key}');
      }
    });
  });

  group('DioCdnAssetGateway — dedicated interceptor-free upload Dio', () {
    test(
      'the default upload Dio is a DIFFERENT instance with NO interceptors',
      () {
        final broker = _BrokerRecorder();
        final gateway = DioCdnAssetGateway(broker.dio); // production default

        expect(identical(gateway.uploadDio, broker.dio), isFalse);
        expect(gateway.uploadDio.interceptors, isEmpty);
      },
    );

    test('the default upload Dio carries BOUNDED connect/send/receive timeouts '
        'so a stalled CDN upload can never hang the submit forever '
        '(JEBV4-259 latent-hang fix)', () {
      final broker = _BrokerRecorder();
      final gateway = DioCdnAssetGateway(broker.dio); // production default
      final opts = gateway.uploadDio.options;

      // The raw Dio() used to have NONE of these — a half-open socket during the
      expect(opts.connectTimeout, isNotNull, reason: 'connect must be bounded');
      expect(
        opts.sendTimeout,
        isNotNull,
        reason: 'the image PUT is a SEND — this is the load-bearing bound',
      );
      expect(opts.receiveTimeout, isNotNull, reason: 'receive must be bounded');
      // Finite and sane (a compressed ID photo should never need > ~30s).
      expect(opts.connectTimeout!.inSeconds, inInclusiveRange(1, 60));
      expect(opts.sendTimeout!.inSeconds, inInclusiveRange(1, 60));
      expect(opts.receiveTimeout!.inSeconds, inInclusiveRange(1, 60));
    });

    test(
      'PUTs to the ABSOLUTE upload_url verbatim — baseUrl never joined',
      () async {
        final broker = _BrokerRecorder();
        final upload = _UploadRecorder(); // its Dio has a decoy baseUrl
        final gateway = DioCdnAssetGateway(broker.dio, uploadDio: upload.dio);

        await gateway.uploadAsset(
          slot: CdnUploadSlot.selfieWithLiveness,
          bytes: bytes,
        );

        // Broker Dio saw ONLY the POST; the PUT never traversed it.
        expect(broker.requests.length, 1);
        final put = upload.captured!;
        expect(put.method, 'PUT');
        // Query string (incl. the signature) is preserved byte-for-byte and the
        expect(put.uri.toString(), _signedUrl);
        expect(put.uri.host, 'signed.cdn.test');
      },
    );

    test(
      'sends the RAW bytes unmodified with Content-Type from required_headers '
      '(never application/json) and NO Authorization',
      () async {
        final broker = _BrokerRecorder();
        final upload = _UploadRecorder();
        final gateway = DioCdnAssetGateway(broker.dio, uploadDio: upload.dio);

        await gateway.uploadAsset(
          slot: CdnUploadSlot.idDocumentFront,
          bytes: bytes,
        );

        final put = upload.captured!;
        // (c) raw bytes, byte-for-byte — not JSON/multipart re-encoded.
        expect(upload.capturedBody, equals(bytes));
        // (c) Content-Type from required_headers, NOT application/json.
        expect(_header(put, 'Content-Type'), 'image/jpeg');
        expect(
          _header(put, 'Content-Type'),
          isNot(contains('application/json')),
        );
        // (d) no Bearer/authorization from any interceptor.
        expect(_header(put, 'Authorization'), isNull);
      },
    );

    test('forwards required_headers verbatim (extra headers) with a custom '
        'contentType', () async {
      final broker = _BrokerRecorder(
        contentType: 'image/png',
        extraHeaders: const {'x-amz-acl': 'private'},
      );
      final upload = _UploadRecorder();
      final gateway = DioCdnAssetGateway(broker.dio, uploadDio: upload.dio);

      await gateway.uploadAsset(
        slot: CdnUploadSlot.idDocumentBack,
        bytes: bytes,
        contentType: 'image/png',
      );

      final put = upload.captured!;
      expect(_header(put, 'Content-Type'), 'image/png');
      expect(_header(put, 'x-amz-acl'), 'private');
    });

    test(
      'uses the HTTP method the broker returns (normalized upper-case)',
      () async {
        final broker = _BrokerRecorder(method: 'put');
        final upload = _UploadRecorder();
        final gateway = DioCdnAssetGateway(broker.dio, uploadDio: upload.dio);

        await gateway.uploadAsset(
          slot: CdnUploadSlot.idDocumentFront,
          bytes: bytes,
        );

        expect(upload.captured!.method, 'PUT');
      },
    );

    test('returns the object_ref from the broker ticket', () async {
      final broker = _BrokerRecorder();
      final upload = _UploadRecorder();
      final gateway = DioCdnAssetGateway(broker.dio, uploadDio: upload.dio);

      final ref = await gateway.uploadAsset(
        slot: CdnUploadSlot.idDocumentFront,
        bytes: bytes,
      );

      expect(ref, 'cdn://obj/id_document_front/abc123');
    });
  });

  group('DioCdnAssetGateway — failure paths', () {
    test('surfaces a non-2xx upstream PUT as CdnUploadException', () async {
      final broker = _BrokerRecorder();
      final upload = _UploadRecorder(status: 403);
      final gateway = DioCdnAssetGateway(broker.dio, uploadDio: upload.dio);

      await expectLater(
        () => gateway.uploadAsset(
          slot: CdnUploadSlot.idDocumentFront,
          bytes: bytes,
        ),
        throwsA(isA<CdnUploadException>()),
      );
      expect(upload.captured, isNotNull, reason: 'the PUT was attempted');
    });

    test(
      'surfaces an upstream transport error as CdnUploadException',
      () async {
        final broker = _BrokerRecorder();
        final upload = _UploadRecorder(throwError: true);
        final gateway = DioCdnAssetGateway(broker.dio, uploadDio: upload.dio);

        await expectLater(
          () => gateway.uploadAsset(
            slot: CdnUploadSlot.idDocumentFront,
            bytes: bytes,
          ),
          throwsA(isA<CdnUploadException>()),
        );
      },
    );

    test(
      'throws (and never attempts the PUT) when upload_url is missing',
      () async {
        final broker = _BrokerRecorder(dropUploadUrl: true);
        final upload = _UploadRecorder();
        final gateway = DioCdnAssetGateway(broker.dio, uploadDio: upload.dio);

        await expectLater(
          () => gateway.uploadAsset(
            slot: CdnUploadSlot.idDocumentFront,
            bytes: bytes,
          ),
          throwsA(isA<CdnUploadException>()),
        );
        expect(upload.captured, isNull, reason: 'no PUT before a valid ticket');
      },
    );

    test('throws when object_ref is missing', () async {
      final broker = _BrokerRecorder(dropObjectRef: true);
      final upload = _UploadRecorder();
      final gateway = DioCdnAssetGateway(broker.dio, uploadDio: upload.dio);

      await expectLater(
        () => gateway.uploadAsset(
          slot: CdnUploadSlot.idDocumentFront,
          bytes: bytes,
        ),
        throwsA(isA<CdnUploadException>()),
      );
    });
  });

  // ===========================================================================
  group('DioCdnAssetGateway.fetchAsset — authenticated read proxy', () {
    test(
      'GETs /api/cdn/assets/content/<ref> on the SHARED Dio as raw bytes',
      () async {
        final payload = Uint8List.fromList(const <int>[1, 2, 3, 4, 5]);
        final broker = _ContentRecorder(body: payload);
        final upload = _UploadRecorder();
        final gateway = DioCdnAssetGateway(broker.dio, uploadDio: upload.dio);

        final out = await gateway.fetchAsset('chat_attachment/abc123.jpg');

        expect(out, payload, reason: 'bytes are returned verbatim');
        final req = broker.requests.single;
        expect(req.method, 'GET');
        expect(req.path, '/api/cdn/assets/content/chat_attachment/abc123.jpg');
        expect(
          req.responseType,
          ResponseType.bytes,
          reason: 'the JSON response transformer must be bypassed',
        );
        expect(
          upload.captured,
          isNull,
          reason:
              'the read is capability-gated — it needs the Bearer the shared '
              'Dio carries, so the bare upload Dio must never be used',
        );
        expect(
          req.path,
          contains('chat_attachment/abc123.jpg'),
          reason:
              'the object_ref `/` stays a PATH SEPARATOR so the gateway '
              'catch-all binds it; the gateway does cdn\'s single-segment encode',
        );
      },
    );

    test('an empty object_ref throws WITHOUT touching the network', () async {
      final broker = _ContentRecorder(body: Uint8List.fromList(const <int>[1]));
      final gateway = DioCdnAssetGateway(
        broker.dio,
        uploadDio: _UploadRecorder().dio,
      );

      await expectLater(
        () => gateway.fetchAsset('   '),
        throwsA(isA<CdnFetchException>()),
      );
      expect(broker.requests, isEmpty);
    });

    test('an empty 200 body throws CdnFetchException', () async {
      final broker = _ContentRecorder(body: Uint8List(0));
      final gateway = DioCdnAssetGateway(
        broker.dio,
        uploadDio: _UploadRecorder().dio,
      );

      await expectLater(
        () => gateway.fetchAsset('chat_attachment/abc.jpg'),
        throwsA(isA<CdnFetchException>()),
      );
    });

    test(
      'a 404 / 500 / network error all surface as CdnFetchException',
      () async {
        for (final status in <int>[404, 500]) {
          final broker = _ContentRecorder(body: Uint8List(0), status: status);
          final gateway = DioCdnAssetGateway(
            broker.dio,
            uploadDio: _UploadRecorder().dio,
          );
          await expectLater(
            () => gateway.fetchAsset('chat_attachment/abc.jpg'),
            throwsA(isA<CdnFetchException>()),
            reason: 'status $status',
          );
        }

        final broken = _ContentRecorder(body: Uint8List(0), networkError: true);
        final gateway = DioCdnAssetGateway(
          broken.dio,
          uploadDio: _UploadRecorder().dio,
        );
        await expectLater(
          () => gateway.fetchAsset('chat_attachment/abc.jpg'),
          throwsA(isA<CdnFetchException>()),
        );
      },
    );
  });
}

/// P4/P5: records `GET /api/cdn/assets/content/…` on the SHARED authenticated
/// Dio and resolves (or rejects) it with a canned binary body.
class _ContentRecorder {
  _ContentRecorder({
    required this.body,
    this.status = 200,
    this.networkError = false,
  }) {
    dio = Dio(BaseOptions(baseUrl: 'https://gateway.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          if (networkError) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                message: 'socket down',
              ),
            );
            return;
          }
          if (status < 200 || status >= 300) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response<dynamic>(
                  statusCode: status,
                  requestOptions: options,
                ),
                type: DioExceptionType.badResponse,
                message: 'HTTP $status',
              ),
            );
            return;
          }
          handler.resolve(
            Response<dynamic>(
              statusCode: 200,
              requestOptions: options,
              data: body,
            ),
          );
        },
      ),
    );
  }

  final Uint8List body;
  final int status;
  final bool networkError;
  late final Dio dio;
  final List<RequestOptions> requests = <RequestOptions>[];
}

String? _header(RequestOptions options, String name) {
  final lower = name.toLowerCase();
  for (final entry in options.headers.entries) {
    if (entry.key.toLowerCase() == lower) return '${entry.value}';
  }
  return null;
}

/// Broker (shared, authenticated gateway Dio) recorder — resolves the
/// `POST /api/cdn/assets` ticket with the approach-B fields. Interceptor-based
/// on purpose: the SHARED Dio legitimately carries interceptors; the upload Dio
class _BrokerRecorder {
  _BrokerRecorder({
    this.method = 'PUT',
    this.contentType = 'image/jpeg',
    this.extraHeaders = const {},
    this.dropUploadUrl = false,
    this.dropObjectRef = false,
  }) {
    dio = Dio(BaseOptions(baseUrl: 'https://gateway.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(_ticket(options));
        },
      ),
    );
  }

  final String method;
  final String contentType;
  final Map<String, String> extraHeaders;
  final bool dropUploadUrl;
  final bool dropObjectRef;
  late final Dio dio;
  final List<RequestOptions> requests = <RequestOptions>[];

  Response<dynamic> _ticket(RequestOptions options) {
    final data = options.data;
    final slot = data is Map ? '${data['slot']}' : 'unknown';
    return Response<dynamic>(
      statusCode: 200,
      requestOptions: options,
      data: <String, dynamic>{
        if (!dropUploadUrl)
          'upload_url':
              'https://signed.cdn.test/api/cdn/put-signed/$slot'
              '?exp=1750000000&ct=jpeg&sig=abc-DEF_123.tok',
        if (!dropObjectRef) 'object_ref': 'cdn://obj/$slot/abc123',
        'expires_in': 300,
        'method': method,
        'required_headers': <String, dynamic>{
          'Content-Type': contentType,
          ...extraHeaders,
        },
      },
    );
  }
}

/// Dedicated upload Dio recorder — an [HttpClientAdapter] (NOT an interceptor,
/// so the upload Dio stays interceptor-free) capturing the outgoing
/// [RequestOptions] and the exact bytes Dio put on the wire. Its Dio carries a
class _UploadRecorder {
  _UploadRecorder({this.status = 200, this.throwError = false}) {
    _adapter = _CapturingAdapter(this);
    dio = Dio(BaseOptions(baseUrl: 'http://decoy-base-should-be-ignored.test'))
      ..interceptors.clear(keepImplyContentTypeInterceptor: false)
      ..httpClientAdapter = _adapter;
  }

  final int status;
  final bool throwError;
  late final Dio dio;
  late final _CapturingAdapter _adapter;
  RequestOptions? captured;
  Uint8List? capturedBody;
}

class _CapturingAdapter implements HttpClientAdapter {
  _CapturingAdapter(this._owner);

  final _UploadRecorder _owner;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    _owner.captured = options;
    if (requestStream != null) {
      final chunks = await requestStream.toList();
      _owner.capturedBody = Uint8List.fromList(
        chunks.expand((chunk) => chunk).toList(),
      );
    }
    if (_owner.throwError) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'simulated transport failure',
      );
    }
    return ResponseBody.fromString('', _owner.status);
  }

  @override
  void close({bool force = false}) {}
}
