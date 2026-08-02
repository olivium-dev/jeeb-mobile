// BUG-8 (sprint-008 run-5) regression guard — customer live-tracking read route.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/live_tracking/data/dio_live_tracking_repository.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';

const _deliveryId = 'req-uuid-0001';

void main() {
  late _RecordingAdapter adapter;
  late Dio dio;

  setUp(() {
    adapter = _RecordingAdapter();
    // ORIGIN-ONLY base (ARCH-01): host is irrelevant to the contract — the
    dio = Dio(BaseOptions(baseUrl: 'http://origin.test'))
      ..httpClientAdapter = adapter;
  });

  DioLiveTrackingRepository originRepo() =>
      DioLiveTrackingRepository(dio, originGateway: true);
  DioLiveTrackingRepository mockRepo() =>
      DioLiveTrackingRepository(dio, originGateway: false);

  group('Origin :10090 (Contract 8c) — plural delivery read (BUG-8 fix)', () {
    test('fetchDeliveryStatus reads the PLURAL GET /v1/deliveries/{id} — NOT '
        'the singular /v1/delivery/{id} that 404s on the live gateway',
        () async {
      adapter.onGet = (path) => _json({
            'id': _deliveryId,
            'status': 'InTransit',
            'tier': 'express',
            'jeeberName': 'Sami',
            'amount': {'value': 9.0, 'currency': 'USD'},
            'title': 'Documents',
          });

      final info = await originRepo().fetchDeliveryStatus(
        deliveryId: _deliveryId,
      );

      // The load-bearing assertion: the plural aggregate route, exactly.
      expect(adapter.lastGetPath, '/v1/deliveries/$_deliveryId');
      expect(
        adapter.lastGetPath,
        isNot('/v1/delivery/$_deliveryId'),
        reason: 'BUG-8: the singular route 404s on the live origin gateway',
      );

      // The plural aggregate parses through the existing fromDeliveryJson path.
      expect(info.currentStage, TrackingStage.inTransit);
      expect(info.deliveryId, _deliveryId);
      expect(info.tier, 'express');
      expect(info.jeeberName, 'Sami');
      expect(info.price, 9.0);
      expect(info.currency, 'USD');
      expect(info.itemSummary, 'Documents');
    });

    test('a 404 on the plural route maps to LiveTrackingErrorKind.notFound',
        () async {
      adapter.onGet = (path) => _json(
            const {'error': 'Delivery not found'},
            status: 404,
          );

      Object? caught;
      try {
        await originRepo().fetchDeliveryStatus(deliveryId: _deliveryId);
      } catch (e) {
        caught = e;
      }

      expect(adapter.lastGetPath, '/v1/deliveries/$_deliveryId');
      expect(caught, isA<LiveTrackingException>());
      expect(
        (caught! as LiveTrackingException).kind,
        LiveTrackingErrorKind.notFound,
      );
    });
  });

  group('Legacy :4010 mock route — PRESERVED (no regression)', () {
    test('fetchDeliveryStatus keeps the singular GET /v1/delivery/{id} alias '
        'when originGateway:false', () async {
      adapter.onGet = (path) => _json({
            'id': _deliveryId,
            'status': 'Ordered',
          });

      await mockRepo().fetchDeliveryStatus(deliveryId: _deliveryId);

      expect(adapter.lastGetPath, '/v1/delivery/$_deliveryId');
    });
  });
}

ResponseBody _json(Map<String, Object?> body, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

class _RecordingAdapter implements HttpClientAdapter {
  ResponseBody Function(String path)? onGet;

  String? lastGetPath;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'GET') {
      lastGetPath = options.path;
      return onGet?.call(options.path) ?? _json(const {});
    }
    return _json(const {});
  }
}
