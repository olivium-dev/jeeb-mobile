// S7 — dropoff OTP handover endpoint contract.
//
// The defining piece of the delivery-lifecycle step is the door-OTP handover.
// Both repositories must speak the `/v1/deliveries/{id}/otp[/verify]` paths so
// the single `MockGatewayClient` rewrite key (`/v1/deliveries` →
// `/delivery-service/v1/deliveries`) catches them. The verify path previously
// used an un-versioned `/deliveries` that is NOT a rewrite key, so it bypassed
// the rewrite and 404'd against the Express mock. These tests pin the paths so
// the regression can't silently come back.

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/active_delivery_jeeber/data/dio_active_delivery_repository.dart';
import 'package:jeeb_mobile/features/kyc/domain/cdn_asset_gateway.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/active_delivery_repository.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import 'package:jeeb_mobile/features/otp_handover/data/dio_otp_handover_repository.dart';
import 'package:jeeb_mobile/features/otp_handover/domain/otp_handover_repository.dart';

/// Records every GET/POST path + body, returns scripted responses.
/// The OTP-handover paths never upload a proof photo — this inert CDN gateway
/// only satisfies the [DioActiveDeliveryRepository] constructor.
class _UnusedCdnAssetGateway implements CdnAssetGateway {
  const _UnusedCdnAssetGateway();

  @override
  Future<String> uploadAsset({
    required CdnUploadSlot slot,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) =>
      throw UnimplementedError();

  /// P4/P5: the OTP-handover paths never READ a CDN asset either.
  @override
  Future<Uint8List> fetchAsset(String objectRef) async => Uint8List(0);
}

class _RecordingDio extends Fake implements Dio {
  final List<String> getPaths = [];
  final List<String> postPaths = [];
  Map<String, dynamic>? lastPostData;

  Map<String, dynamic> nextGetData = const {};
  Map<String, dynamic> nextPostData = const {};

  /// When set, the next POST throws this instead of returning a 200. Used to
  /// drive the repositories' status→error mapping (401/423/…). The GET path
  /// (verifyDoorOtp's best-effort issue-on-demand) still succeeds so the test
  /// exercises the verify POST's error branch, not the GET's.
  DioException? nextPostError;

  Response<T> _resp<T>(String path, Object? data) => Response<T>(
        requestOptions: RequestOptions(path: path),
        statusCode: 200,
        data: data as T,
      );

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    getPaths.add(path);
    return _resp<T>(path, nextGetData);
  }

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    postPaths.add(path);
    lastPostData = data as Map<String, dynamic>?;
    if (nextPostError != null) throw nextPostError!;
    return _resp<T>(path, nextPostData);
  }
}

/// Builds a `DioException` carrying [status] as the badResponse code — the
/// shape the repositories map onto their domain errors.
DioException _httpError(int status) => DioException(
      requestOptions: RequestOptions(path: '/v1/deliveries/d/otp/verify'),
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: ''),
        statusCode: status,
      ),
    );

void main() {
  group('DioOtpHandoverRepository — /v1/deliveries contract', () {
    test('fetchHandoverCode GETs /v1/deliveries/{id}/otp', () async {
      final dio = _RecordingDio()..nextGetData = {'code': '1234'};
      final repo = DioOtpHandoverRepository(dio);

      final result = await repo.fetchHandoverCode(deliveryId: 'delivery-005');

      expect(result.code, '1234');
      expect(result.smsTriggered, isFalse);
      expect(dio.getPaths, ['/v1/deliveries/delivery-005/otp']);
    });

    // G4 (sprint-009): the LIVE gateway shape (run-23 wire evidence) — the
    // endpoint is an SMS trigger: `{deliveryId, triggered: true, message}`,
    // NO `code`. The repo must surface `smsTriggered` rather than throw
    // `parse` (the pre-fix behavior that flipped the customer screen into a
    // code-ENTRY grid).
    test('live SMS-trigger body (no code) → OtpFetchResult.smsTriggered',
        () async {
      final dio = _RecordingDio()
        ..nextGetData = {
          'deliveryId': 'delivery-005',
          'message': '4-digit OTP sent to the delivery recipient.',
          'triggered': true,
        };
      final repo = DioOtpHandoverRepository(dio);

      final result = await repo.fetchHandoverCode(deliveryId: 'delivery-005');

      expect(result.code, isNull);
      expect(result.smsTriggered, isTrue);
    });

    test('body with neither code nor triggered → parse error', () async {
      final dio = _RecordingDio()..nextGetData = {'deliveryId': 'delivery-005'};
      final repo = DioOtpHandoverRepository(dio);

      await expectLater(
        repo.fetchHandoverCode(deliveryId: 'delivery-005'),
        throwsA(
          isA<OtpHandoverException>().having(
            (e) => e.kind,
            'kind',
            OtpHandoverErrorKind.parse,
          ),
        ),
      );
    });

    test('submitOtp POSTs /v1/deliveries/{id}/otp/verify (rewrite-catchable)',
        () async {
      final dio = _RecordingDio()..nextPostData = {'verified': true};
      final repo = DioOtpHandoverRepository(dio);

      final result = await repo.submitOtp(deliveryId: 'delivery-005', otp: '1234');

      expect(result.success, isTrue);
      expect(dio.postPaths, ['/v1/deliveries/delivery-005/otp/verify']);
      expect(dio.postPaths.single, startsWith('/v1/deliveries'));
      expect(dio.lastPostData?['code'], '1234');
    });

    // ─────────────────────────────────────────────────────────────────────
    // SECURITY-CRITICAL error mapping (TEST-INTEGRITY-AUDIT #2 — ZERO prior
    // coverage). The whole VALUE of this repository is its status→error
    // mapping: a wrong door code (401) must surface as `invalidOtp`, and a
    // 3-strike lockout (423) as `locked`. Before these tests the `_RecordingDio`
    // only ever returned 200, so a regression that let a wrong code "succeed"
    // (or a lockout fail open) turned NO test red. The backend proves these
    // server-side (delivery-otp.test.ts); these prove the CLIENT maps them.
    // ─────────────────────────────────────────────────────────────────────
    test('submitOtp maps 401 → OtpHandoverErrorKind.invalidOtp (wrong code)',
        () async {
      final dio = _RecordingDio()..nextPostError = _httpError(401);
      final repo = DioOtpHandoverRepository(dio);

      await expectLater(
        repo.submitOtp(deliveryId: 'delivery-005', otp: '0000'),
        throwsA(
          isA<OtpHandoverException>().having(
            (e) => e.kind,
            'kind',
            OtpHandoverErrorKind.invalidOtp,
          ),
        ),
      );
    });

    test('submitOtp maps 423 → OtpHandoverErrorKind.locked (3-strike lockout)',
        () async {
      final dio = _RecordingDio()..nextPostError = _httpError(423);
      final repo = DioOtpHandoverRepository(dio);

      await expectLater(
        repo.submitOtp(deliveryId: 'delivery-005', otp: '0000'),
        throwsA(
          isA<OtpHandoverException>().having(
            (e) => e.kind,
            'kind',
            OtpHandoverErrorKind.locked,
          ),
        ),
      );
    });
  });

  group('DioActiveDeliveryRepository.verifyDoorOtp — /v1/deliveries contract',
      () {
    test('issues then verifies, both under /v1/deliveries, flips to Done',
        () async {
      final dio = _RecordingDio()
        ..nextGetData = {'code': '1234'}
        ..nextPostData = {'verified': true, 'status': 'Done'};
      final repo = DioActiveDeliveryRepository(
      dio,
      cdnAssetGateway: const _UnusedCdnAssetGateway(),
    );

      final status =
          await repo.verifyDoorOtp(deliveryId: 'delivery-005', code: '1234');

      expect(status, JeeberDeliveryStatus.done);
      // Issue-on-demand GET uses the versioned path.
      expect(dio.getPaths, ['/v1/deliveries/delivery-005/otp']);
      // Verify POST uses the versioned path so the rewrite key catches it.
      expect(dio.postPaths, ['/v1/deliveries/delivery-005/otp/verify']);
      expect(dio.postPaths.single, startsWith('/v1/deliveries'));
      expect(dio.lastPostData?['code'], '1234');
    });

    // Same security gate, the jeeber-side repository. verifyDoorOtp issues the
    // OTP on demand (GET, best-effort) then POSTs the verify; the GET succeeds
    // and the verify POST carries the error status under test.
    test('verifyDoorOtp maps 401 → ActiveDeliveryFailure.invalidOtp', () async {
      final dio = _RecordingDio()
        ..nextGetData = {'code': '1234'}
        ..nextPostError = _httpError(401);
      final repo = DioActiveDeliveryRepository(
      dio,
      cdnAssetGateway: const _UnusedCdnAssetGateway(),
    );

      await expectLater(
        repo.verifyDoorOtp(deliveryId: 'delivery-005', code: '0000'),
        throwsA(
          isA<ActiveDeliveryException>().having(
            (e) => e.failure,
            'failure',
            ActiveDeliveryFailure.invalidOtp,
          ),
        ),
      );
    });

    test('verifyDoorOtp maps 423 → ActiveDeliveryFailure.otpLocked', () async {
      final dio = _RecordingDio()
        ..nextGetData = {'code': '1234'}
        ..nextPostError = _httpError(423);
      final repo = DioActiveDeliveryRepository(
      dio,
      cdnAssetGateway: const _UnusedCdnAssetGateway(),
    );

      await expectLater(
        repo.verifyDoorOtp(deliveryId: 'delivery-005', code: '0000'),
        throwsA(
          isA<ActiveDeliveryException>().having(
            (e) => e.failure,
            'failure',
            ActiveDeliveryFailure.otpLocked,
          ),
        ),
      );
    });
  });
}
