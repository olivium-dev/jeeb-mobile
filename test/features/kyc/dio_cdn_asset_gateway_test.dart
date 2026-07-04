/// CDN signed-PUT broker contract (JEBV4-113 §3.5 / ADR-0004).
///
/// Pins [DioCdnAssetGateway] to the two-step flow the gateway broker expects:
///   1. POST /api/cdn/assets {slot, content_type} → {upload_url, object_ref, expires_in}
///   2. PUT the raw bytes to the returned (absolute) upload_url.
/// and confirms the resolved `object_ref` — the value downstream callers embed
/// as a KYC submit `*_url` field — is returned from [uploadAsset].
library;

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/kyc/data/dio_cdn_asset_gateway.dart';
import 'package:jeeb_mobile/features/kyc/domain/cdn_asset_gateway.dart';

/// Records every outbound request and resolves a response computed from the
/// request (so the two calls in [DioCdnAssetGateway.uploadAsset] — the
/// broker POST and the direct PUT — can be answered differently).
class _RecordingDio {
  _RecordingDio(this._resolve) {
    dio = Dio(BaseOptions(baseUrl: 'http://gateway.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(_resolve(options));
        },
      ),
    );
  }

  final Response<dynamic> Function(RequestOptions options) _resolve;
  late final Dio dio;
  final List<RequestOptions> requests = <RequestOptions>[];

  int get count => requests.length;
}

Response<dynamic> _brokerTicket(
  RequestOptions options, {
  String objectRefPrefix = 'cdn://obj',
}) {
  final slot = (options.data as Map)['slot'] as String;
  return Response<dynamic>(
    data: <String, dynamic>{
      'upload_url': 'https://signed.cdn.test/put/$slot',
      'object_ref': '$objectRefPrefix/$slot/abc123',
      'expires_in': 300,
    },
    statusCode: 200,
    requestOptions: options,
  );
}

Response<dynamic> _happyPath(RequestOptions options) {
  if (options.path == '/api/cdn/assets') {
    return _brokerTicket(options);
  }
  // The PUT to the signed URL — bytes accepted, no body.
  return Response<dynamic>(
    data: null,
    statusCode: 200,
    requestOptions: options,
  );
}

void main() {
  final bytes = Uint8List.fromList(List<int>.generate(16, (i) => i));

  group('DioCdnAssetGateway — broker request shape', () {
    test('POSTs /api/cdn/assets with slot + content_type', () async {
      final rec = _RecordingDio(_happyPath);
      final gateway = DioCdnAssetGateway(rec.dio);

      await gateway.uploadAsset(
        slot: CdnUploadSlot.idDocumentFront,
        bytes: bytes,
      );

      final brokerCall = rec.requests.first;
      expect(brokerCall.method, 'POST');
      expect(brokerCall.path, '/api/cdn/assets');
      final body = brokerCall.data as Map<String, dynamic>;
      expect(body['slot'], 'id_document_front');
      expect(body['content_type'], 'image/jpeg');
    });

    test('maps every CdnUploadSlot to its wire value', () async {
      final expected = <CdnUploadSlot, String>{
        CdnUploadSlot.idDocumentFront: 'id_document_front',
        CdnUploadSlot.idDocumentBack: 'id_document_back',
        CdnUploadSlot.vehicleRegistration: 'vehicle_registration',
        CdnUploadSlot.selfieWithLiveness: 'selfie_with_liveness',
      };

      for (final entry in expected.entries) {
        final rec = _RecordingDio(_happyPath);
        final gateway = DioCdnAssetGateway(rec.dio);

        await gateway.uploadAsset(slot: entry.key, bytes: bytes);

        final body = rec.requests.first.data as Map<String, dynamic>;
        expect(body['slot'], entry.value, reason: 'slot ${entry.key}');
      }
    });

    test('honors a custom contentType end to end (broker request + PUT '
        'header)', () async {
      final rec = _RecordingDio(_happyPath);
      final gateway = DioCdnAssetGateway(rec.dio);

      await gateway.uploadAsset(
        slot: CdnUploadSlot.idDocumentBack,
        bytes: bytes,
        contentType: 'image/png',
      );

      final brokerBody = rec.requests.first.data as Map<String, dynamic>;
      expect(brokerBody['content_type'], 'image/png');
      final putCall = rec.requests[1];
      expect(putCall.headers['Content-Type'], 'image/png');
    });
  });

  group('DioCdnAssetGateway — two-step upload + object_ref return', () {
    test('PUTs the raw bytes to the exact upload_url from the broker '
        'response (absolute URL, not joined to the gateway base path)',
        () async {
      final rec = _RecordingDio(_happyPath);
      final gateway = DioCdnAssetGateway(rec.dio);

      await gateway.uploadAsset(
        slot: CdnUploadSlot.selfieWithLiveness,
        bytes: bytes,
      );

      expect(rec.count, 2);
      final putCall = rec.requests[1];
      expect(putCall.method, 'PUT');
      expect(putCall.path, 'https://signed.cdn.test/put/selfie_with_liveness');
      expect(putCall.data, bytes);
    });

    test('returns the object_ref from the broker ticket', () async {
      final rec = _RecordingDio(_happyPath);
      final gateway = DioCdnAssetGateway(rec.dio);

      final ref = await gateway.uploadAsset(
        slot: CdnUploadSlot.idDocumentFront,
        bytes: bytes,
      );

      expect(ref, 'cdn://obj/id_document_front/abc123');
    });

    test('defaults contentType to image/jpeg when not supplied', () async {
      final rec = _RecordingDio(_happyPath);
      final gateway = DioCdnAssetGateway(rec.dio);

      await gateway.uploadAsset(
        slot: CdnUploadSlot.idDocumentFront,
        bytes: bytes,
      );

      final putCall = rec.requests[1];
      expect(putCall.headers['Content-Type'], 'image/jpeg');
    });
  });

  group('DioCdnAssetGateway — malformed ticket', () {
    test('throws CdnUploadException when upload_url is missing (and never '
        'attempts the PUT)', () async {
      final rec = _RecordingDio((options) {
        return Response<dynamic>(
          data: <String, dynamic>{'object_ref': 'cdn://obj/x/1'},
          statusCode: 200,
          requestOptions: options,
        );
      });
      final gateway = DioCdnAssetGateway(rec.dio);

      await expectLater(
        () => gateway.uploadAsset(
          slot: CdnUploadSlot.idDocumentFront,
          bytes: bytes,
        ),
        throwsA(isA<CdnUploadException>()),
      );
      expect(rec.count, 1, reason: 'no PUT should be attempted');
    });

    test('throws CdnUploadException when object_ref is missing', () async {
      final rec = _RecordingDio((options) {
        return Response<dynamic>(
          data: <String, dynamic>{
            'upload_url': 'https://signed.cdn.test/put/x',
          },
          statusCode: 200,
          requestOptions: options,
        );
      });
      final gateway = DioCdnAssetGateway(rec.dio);

      await expectLater(
        () => gateway.uploadAsset(
          slot: CdnUploadSlot.idDocumentFront,
          bytes: bytes,
        ),
        throwsA(isA<CdnUploadException>()),
      );
      expect(rec.count, 1, reason: 'no PUT should be attempted');
    });
  });
}
