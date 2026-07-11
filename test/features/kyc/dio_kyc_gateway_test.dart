/// KYC submit HTTP contract (JEBV4-113) — pins [DioKycGateway.submit] to the
/// LIVE gateway shape (`KycSubmissionBffController.SubmitJson`): the CDN
/// broker is used to turn captured photos into `*_url` refs, and the submit
/// body carries `id_document_front_url` / `id_document_back_url` /
/// `selfie_with_liveness_url` (always), `vehicle_registration_url`
/// (send-if-present only — JEBV4-113 §4 owner decision left open) and
/// `tos_accepted_version` (threaded from `signContract()` when present).
///
/// The previous body shape (`document_type` / `has_id_front` / `has_id_back`
/// / `has_selfie`) matched no live endpoint and is gone; these tests assert
/// the new shape end to end via the real [DioCdnAssetGateway] against a
/// recording [Dio], the same "no mock framework" house style used by the
/// chat gateway contract test.
library;

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/kyc/data/dio_cdn_asset_gateway.dart';
import 'package:jeeb_mobile/features/kyc/data/dio_kyc_gateway.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_gateway.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_submission.dart';
import 'package:jeeb_mobile/features/photo_attachment/domain/photo_attachment.dart';

/// Records every outbound request and resolves a response computed per
/// request, so the CDN broker POSTs, the signed PUTs, and the final
/// `/v1/kyc/submit` POST can each be answered distinctly. A resolver may
/// throw a [DioException] to simulate an HTTP error response (e.g. the BFF's
/// RFC-7807 400).
///
/// JEBV4-259: since the CDN signed-PUT now uses a DEDICATED, interceptor-free
/// Dio, this recorder is passed as BOTH the broker Dio and (via
/// `uploadDio: rec.dio`) the upload Dio, so the PUT stays observable here. The
/// dedicated-Dio isolation itself is proven in dio_cdn_asset_gateway_test.dart.
class _RecordingDio {
  _RecordingDio(this._resolve) {
    dio = Dio(BaseOptions(baseUrl: 'http://gateway.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          try {
            handler.resolve(_resolve(options));
          } on DioException catch (e) {
            handler.reject(e);
          }
        },
      ),
    );
  }

  final Response<dynamic> Function(RequestOptions options) _resolve;
  late final Dio dio;
  final List<RequestOptions> requests = <RequestOptions>[];

  List<RequestOptions> get cdnBrokerCalls =>
      requests.where((r) => r.path == '/api/cdn/assets').toList();

  RequestOptions get submitCall =>
      requests.singleWhere((r) => r.path == '/v1/kyc/submit');
}

/// Standard resolver: answers the CDN broker, the signed PUT, and the KYC
/// submit POST with canned success responses.
Response<dynamic> _happyPath(RequestOptions options) {
  if (options.path == '/api/cdn/assets') {
    final slot = (options.data as Map)['slot'] as String;
    return Response<dynamic>(
      data: <String, dynamic>{
        'upload_url': 'https://signed.cdn.test/put/$slot',
        'object_ref': 'cdn://obj/$slot/abc123',
        'expires_in': 300,
      },
      statusCode: 200,
      requestOptions: options,
    );
  }
  if (options.path.startsWith('https://signed.cdn.test/put/')) {
    return Response<dynamic>(data: null, statusCode: 200, requestOptions: options);
  }
  if (options.path == '/v1/kyc/submit') {
    return Response<dynamic>(
      data: <String, dynamic>{'state': 'Submitted'},
      statusCode: 201,
      requestOptions: options,
    );
  }
  throw StateError('Unexpected request in test: ${options.path}');
}

PhotoAttachment _photo(String id) => PhotoAttachment(
      id: id,
      bytes: Uint8List.fromList(List<int>.generate(8, (i) => i)),
      originalSizeBytes: 8,
      source: PhotoSource.camera,
    );

void main() {
  group('DioKycGateway.submit — CDN upload wiring', () {
    test('uploads idFront/idBack/selfie unconditionally, skips vehicle when '
        'absent from the draft', () async {
      final rec = _RecordingDio(_happyPath);
      final gateway = DioKycGateway(rec.dio, DioCdnAssetGateway(rec.dio, uploadDio: rec.dio));
      const draft = KycSubmission(status: KycStatus.notSubmitted);
      final withPhotos = draft.copyWith(
        idFront: _photo('front'),
        idBack: _photo('back'),
        selfie: _photo('selfie'),
      );

      await gateway.submit(withPhotos);

      final slots =
          rec.cdnBrokerCalls.map((r) => (r.data as Map)['slot']).toList();
      expect(slots, unorderedEquals(
        <String>['id_document_front', 'id_document_back', 'selfie_with_liveness'],
      ));
      expect(slots, isNot(contains('vehicle_registration')));
    });

    test('uploads the vehicle-registration asset too when present '
        '(send-if-present)', () async {
      final rec = _RecordingDio(_happyPath);
      final gateway = DioKycGateway(rec.dio, DioCdnAssetGateway(rec.dio, uploadDio: rec.dio));
      const draft = KycSubmission(status: KycStatus.notSubmitted);
      final withVehicle = draft.copyWith(
        idFront: _photo('front'),
        idBack: _photo('back'),
        selfie: _photo('selfie'),
        vehicleRegistration: _photo('vehicle'),
      );

      await gateway.submit(withVehicle);

      final slots =
          rec.cdnBrokerCalls.map((r) => (r.data as Map)['slot']).toList();
      expect(slots, unorderedEquals(<String>[
        'id_document_front',
        'id_document_back',
        'selfie_with_liveness',
        'vehicle_registration',
      ]));
    });
  });

  group('DioKycGateway.submit — live submit body contract (JEBV4-113 §1)',
      () {
    test('sends id_document_front_url / id_document_back_url / '
        'selfie_with_liveness_url resolved from the CDN uploads, and no '
        'vehicle_registration_url when no vehicle asset exists', () async {
      final rec = _RecordingDio(_happyPath);
      final gateway = DioKycGateway(rec.dio, DioCdnAssetGateway(rec.dio, uploadDio: rec.dio));
      const draft = KycSubmission(status: KycStatus.notSubmitted);
      final withPhotos = draft.copyWith(
        idFront: _photo('front'),
        idBack: _photo('back'),
        selfie: _photo('selfie'),
      );

      await gateway.submit(withPhotos);

      final body = rec.submitCall.data as Map<String, dynamic>;
      expect(body['id_document_front_url'], 'cdn://obj/id_document_front/abc123');
      expect(body['id_document_back_url'], 'cdn://obj/id_document_back/abc123');
      expect(
        body['selfie_with_liveness_url'],
        'cdn://obj/selfie_with_liveness/abc123',
      );
      expect(body.containsKey('vehicle_registration_url'), isFalse);
      // E3/JEBV4-197: id_type is REQUIRED and always sent (national-ID default).
      expect(body['id_type'], 'national_id');
      // The dead shape from before this fix must be fully gone.
      expect(body.containsKey('document_type'), isFalse);
      expect(body.containsKey('has_id_front'), isFalse);
      expect(body.containsKey('has_id_back'), isFalse);
      expect(body.containsKey('has_selfie'), isFalse);
    });

    test('sends id_type (always) and id_number (when captured) per E3 '
        '(JEBV4-197)', () async {
      final rec = _RecordingDio(_happyPath);
      final gateway = DioKycGateway(rec.dio, DioCdnAssetGateway(rec.dio, uploadDio: rec.dio));
      const draft = KycSubmission(status: KycStatus.notSubmitted);
      final withId = draft.copyWith(
        idFront: _photo('front'),
        idBack: _photo('back'),
        selfie: _photo('selfie'),
        idNumber: '123456789012',
      );

      await gateway.submit(withId);

      final body = rec.submitCall.data as Map<String, dynamic>;
      expect(body['id_type'], 'national_id');
      expect(body['id_number'], '123456789012');
    });

    test('omits id_number when the draft never captured one', () async {
      final rec = _RecordingDio(_happyPath);
      final gateway = DioKycGateway(rec.dio, DioCdnAssetGateway(rec.dio, uploadDio: rec.dio));
      const draft = KycSubmission(status: KycStatus.notSubmitted);
      final noId = draft.copyWith(
        idFront: _photo('front'),
        idBack: _photo('back'),
        selfie: _photo('selfie'),
      );

      await gateway.submit(noId);

      final body = rec.submitCall.data as Map<String, dynamic>;
      // id_type is still always present; id_number is send-if-present.
      expect(body['id_type'], 'national_id');
      expect(body.containsKey('id_number'), isFalse);
    });

    test('sends the ratified E3/Q-042 wire value for every id_type variant '
        '(canonical residency, never residency_permit)', () async {
      for (final entry in {
        KycIdType.nationalId: 'national_id',
        KycIdType.passport: 'passport',
        KycIdType.residency: 'residency',
      }.entries) {
        final rec = _RecordingDio(_happyPath);
        final gateway = DioKycGateway(rec.dio, DioCdnAssetGateway(rec.dio, uploadDio: rec.dio));
        const draft = KycSubmission(status: KycStatus.notSubmitted);
        final typed = draft.copyWith(
          idFront: _photo('front'),
          idBack: _photo('back'),
          selfie: _photo('selfie'),
          idType: entry.key,
          idNumber: 'DOC-1234',
        );

        await gateway.submit(typed);

        final body = rec.submitCall.data as Map<String, dynamic>;
        expect(body['id_type'], entry.value);
      }
    });

    test('includes vehicle_registration_url only when a vehicle asset '
        'exists in state (send-if-present)', () async {
      final rec = _RecordingDio(_happyPath);
      final gateway = DioKycGateway(rec.dio, DioCdnAssetGateway(rec.dio, uploadDio: rec.dio));
      const draft = KycSubmission(status: KycStatus.notSubmitted);
      final withVehicle = draft.copyWith(
        idFront: _photo('front'),
        idBack: _photo('back'),
        selfie: _photo('selfie'),
        vehicleRegistration: _photo('vehicle'),
      );

      await gateway.submit(withVehicle);

      final body = rec.submitCall.data as Map<String, dynamic>;
      expect(
        body['vehicle_registration_url'],
        'cdn://obj/vehicle_registration/abc123',
      );
    });

    test('threads tos_accepted_version into the submit body when present',
        () async {
      final rec = _RecordingDio(_happyPath);
      final gateway = DioKycGateway(rec.dio, DioCdnAssetGateway(rec.dio, uploadDio: rec.dio));
      const draft = KycSubmission(status: KycStatus.notSubmitted);
      final withTos = draft.copyWith(
        idFront: _photo('front'),
        idBack: _photo('back'),
        selfie: _photo('selfie'),
        tosAcceptedVersion: 'v3',
      );

      await gateway.submit(withTos);

      final body = rec.submitCall.data as Map<String, dynamic>;
      expect(body['tos_accepted_version'], 'v3');
    });

    test('omits tos_accepted_version when the draft never had it set',
        () async {
      final rec = _RecordingDio(_happyPath);
      final gateway = DioKycGateway(rec.dio, DioCdnAssetGateway(rec.dio, uploadDio: rec.dio));
      const draft = KycSubmission(status: KycStatus.notSubmitted);
      final noTos = draft.copyWith(
        idFront: _photo('front'),
        idBack: _photo('back'),
        selfie: _photo('selfie'),
      );

      await gateway.submit(noTos);

      final body = rec.submitCall.data as Map<String, dynamic>;
      expect(body.containsKey('tos_accepted_version'), isFalse);
    });

    test('omits tos_accepted_version when it is set but empty', () async {
      final rec = _RecordingDio(_happyPath);
      final gateway = DioKycGateway(rec.dio, DioCdnAssetGateway(rec.dio, uploadDio: rec.dio));
      const draft = KycSubmission(status: KycStatus.notSubmitted);
      final emptyTos = draft.copyWith(
        idFront: _photo('front'),
        idBack: _photo('back'),
        selfie: _photo('selfie'),
        tosAcceptedVersion: '',
      );

      await gateway.submit(emptyTos);

      final body = rec.submitCall.data as Map<String, dynamic>;
      expect(body.containsKey('tos_accepted_version'), isFalse);
    });

    test('POSTs the submit body to /v1/kyc/submit and parses the response',
        () async {
      final rec = _RecordingDio(_happyPath);
      final gateway = DioKycGateway(rec.dio, DioCdnAssetGateway(rec.dio, uploadDio: rec.dio));
      const draft = KycSubmission(status: KycStatus.notSubmitted);
      final withPhotos = draft.copyWith(
        idFront: _photo('front'),
        idBack: _photo('back'),
        selfie: _photo('selfie'),
      );

      final result = await gateway.submit(withPhotos);

      expect(rec.submitCall.method, 'POST');
      expect(result.status, KycStatus.pending);
    });
  });

  group('DioKycGateway.submit — RFC-7807 field-scoped 400 translation '
      '(JEBV4-113 review finding 1)', () {
    /// Answers the CDN legs happily but rejects the submit POST with the
    /// BFF's real problem shape: `{"type": ..., "field": "id_number",
    /// "detail": ...}` on HTTP 400.
    Response<dynamic> rejectSubmit(RequestOptions options) {
      if (options.path == '/v1/kyc/submit') {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: options,
            statusCode: 400,
            data: <String, dynamic>{
              'type': 'https://jeeb.dev/errors/validation',
              'title': 'Invalid submission field',
              'detail': r'id_number must be exactly 12 digits (^\d{12}$).',
              'status': 400,
              'field': 'id_number',
            },
          ),
        );
      }
      return _happyPath(options);
    }

    KycSubmission draftWithPhotos() =>
        const KycSubmission(status: KycStatus.notSubmitted).copyWith(
          idFront: _photo('front'),
          idBack: _photo('back'),
          selfie: _photo('selfie'),
          idNumber: '123',
        );

    test('a 400 problem carrying field throws KycSubmitFieldException with '
        'that field + detail', () async {
      final rec = _RecordingDio(rejectSubmit);
      final gateway = DioKycGateway(rec.dio, DioCdnAssetGateway(rec.dio, uploadDio: rec.dio));

      await expectLater(
        gateway.submit(draftWithPhotos()),
        throwsA(
          isA<KycSubmitFieldException>()
              .having((e) => e.field, 'field', 'id_number')
              .having((e) => e.detail, 'detail', contains('12 digits')),
        ),
      );
    });

    test('a 400 problem WITHOUT a field extension rethrows the raw '
        'DioException (generic handling stays intact)', () async {
      Response<dynamic> rejectPlain(RequestOptions options) {
        if (options.path == '/v1/kyc/submit') {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response<dynamic>(
              requestOptions: options,
              statusCode: 400,
              data: <String, dynamic>{
                'title': 'Missing document references',
                'status': 400,
              },
            ),
          );
        }
        return _happyPath(options);
      }

      final rec = _RecordingDio(rejectPlain);
      final gateway = DioKycGateway(rec.dio, DioCdnAssetGateway(rec.dio, uploadDio: rec.dio));

      await expectLater(
        gateway.submit(draftWithPhotos()),
        throwsA(isA<DioException>()),
      );
    });
  });
}
