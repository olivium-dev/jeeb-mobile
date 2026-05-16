import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/background_gps/data/http_location_uploader.dart';
import 'package:jeeb_mobile/features/background_gps/domain/gps_sample.dart';
import 'package:jeeb_mobile/features/background_gps/domain/location_uploader.dart';

/// Captures the last request and returns scripted responses so we don't
/// need a real HTTP server. Interceptor-based — no mocktail needed.
class _ScriptedAdapter extends Interceptor {
  _ScriptedAdapter(this._respond);

  final void Function(RequestOptions options, ResponseHandler responder)
      _respond;
  RequestOptions? lastRequest;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    lastRequest = options;
    _respond(options, ResponseHandler(options, handler));
  }
}

class ResponseHandler {
  ResponseHandler(this._options, this._handler);
  final RequestOptions _options;
  final RequestInterceptorHandler _handler;

  void respondWith(int status, {Object? body}) {
    _handler.resolve(Response<Object?>(
      requestOptions: _options,
      statusCode: status,
      data: body,
    ));
  }

  void fail(DioExceptionType type, {int? status}) {
    _handler.reject(DioException(
      requestOptions: _options,
      type: type,
      response: status == null
          ? null
          : Response<Object?>(
              requestOptions: _options,
              statusCode: status,
            ),
    ));
  }
}

GpsSample _sample() => GpsSample(
      latitude: 33.88,
      longitude: 35.5,
      accuracyMeters: 12,
      speedMps: 5,
      headingDegrees: 92,
      capturedAt: DateTime.utc(2026, 5, 17, 14, 23, 11),
    );

Dio _scriptedDio(_ScriptedAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  dio.interceptors.add(adapter);
  return dio;
}

void main() {
  group('HttpLocationUploader', () {
    test('sends the expected JSON body to /api/location/update', () async {
      final adapter = _ScriptedAdapter((options, responder) {
        responder.respondWith(204);
      });
      final uploader = HttpLocationUploader(dio: _scriptedDio(adapter));

      final outcome = await uploader.upload(
        deliveryId: 'delivery-1',
        sample: _sample(),
      );

      expect(outcome, LocationUploadOutcome.accepted);
      expect(adapter.lastRequest?.path, '/api/location/update');
      expect(adapter.lastRequest?.method, 'POST');
      final body = adapter.lastRequest?.data as Map<String, dynamic>;
      expect(body['delivery_id'], 'delivery-1');
      expect(body['latitude'], closeTo(33.88, 1e-9));
      expect(body['longitude'], closeTo(35.5, 1e-9));
      expect(body['accuracy_m'], 12);
      expect(body['speed_mps'], 5);
      expect(body['heading_deg'], 92);
      expect(body['recorded_at'], '2026-05-17T14:23:11.000Z');
    });

    test('maps 5xx to a transient failure so the cubit retries', () async {
      final adapter = _ScriptedAdapter((options, responder) {
        responder.respondWith(503);
      });
      final uploader = HttpLocationUploader(dio: _scriptedDio(adapter));

      final outcome = await uploader.upload(
        deliveryId: 'd',
        sample: _sample(),
      );
      expect(outcome, LocationUploadOutcome.transientFailure);
    });

    test('maps 4xx to a permanent failure so the cubit stops the loop',
        () async {
      final adapter = _ScriptedAdapter((options, responder) {
        responder.respondWith(404);
      });
      final uploader = HttpLocationUploader(dio: _scriptedDio(adapter));

      final outcome = await uploader.upload(
        deliveryId: 'd',
        sample: _sample(),
      );
      expect(outcome, LocationUploadOutcome.permanentFailure);
    });

    test('connection errors map to transient', () async {
      final adapter = _ScriptedAdapter((options, responder) {
        responder.fail(DioExceptionType.connectionError);
      });
      final uploader = HttpLocationUploader(dio: _scriptedDio(adapter));

      final outcome = await uploader.upload(
        deliveryId: 'd',
        sample: _sample(),
      );
      expect(outcome, LocationUploadOutcome.transientFailure);
    });

    test('badResponse with 4xx maps to permanent failure', () async {
      final adapter = _ScriptedAdapter((options, responder) {
        responder.fail(DioExceptionType.badResponse, status: 401);
      });
      final uploader = HttpLocationUploader(dio: _scriptedDio(adapter));

      final outcome = await uploader.upload(
        deliveryId: 'd',
        sample: _sample(),
      );
      expect(outcome, LocationUploadOutcome.permanentFailure);
    });
  });
}
