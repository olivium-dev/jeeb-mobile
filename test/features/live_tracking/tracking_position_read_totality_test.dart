// MB1 — "deliberately total" must actually BE total.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/live_tracking/data/dio_live_tracking_repository.dart';

const _deliveryId = 'req-uuid-total';

void main() {
  late _StubAdapter adapter;
  late Dio dio;

  setUp(() {
    adapter = _StubAdapter();
    dio = Dio(BaseOptions(baseUrl: 'http://origin.test'))
      ..httpClientAdapter = adapter;
  });

  DioLiveTrackingRepository repo() =>
      DioLiveTrackingRepository(dio, originGateway: true);

  group('fetchLivePosition is total across malformed 200 bodies', () {
    final cases = <String, Map<String, dynamic>>{
      // `json['position'] as Map<String, dynamic>?` on a LIST.
      'position is a list': {
        'id': _deliveryId,
        'status': 'InTransit',
        'position': <dynamic>[1, 2],
      },
      // `json['position'] as Map<String, dynamic>?` on a STRING.
      'position is a string': {
        'id': _deliveryId,
        'status': 'InTransit',
        'position': 'somewhere',
      },
      // `(posObj['lat'] as num).toDouble()` on a STRING latitude.
      'lat is a string': {
        'id': _deliveryId,
        'status': 'InTransit',
        'position': {'lat': '33.5', 'lng': 36.3},
      },
      // `json['status'] as String?` on a NUMBER.
      'status is a number': {
        'id': _deliveryId,
        'status': 7,
        'position': {'lat': 33.5, 'lng': 36.3},
      },
    };

    cases.forEach((name, body) {
      test('POSITIVE CONTROL: $name returns null instead of throwing',
          () async {
        adapter.body = body;

        // The whole contract in one line: it RETURNS, and it returns null.
        await expectLater(
          repo().fetchLivePosition(deliveryId: _deliveryId),
          completion(isNull),
        );
      });
    });

    test('a WELL-FORMED body still returns the position (the fix does not '
        'swallow the happy path)', () async {
      adapter.body = {
        'id': _deliveryId,
        'status': 'InTransit',
        'position': {'lat': 33.5, 'lng': 36.3},
      };

      final pos = await repo().fetchLivePosition(deliveryId: _deliveryId);

      expect(pos, isNotNull);
      expect(pos!.jeeberPosition?.lat, 33.5);
      expect(pos.jeeberPosition?.lng, 36.3);
    });
  });
}

class _StubAdapter implements HttpClientAdapter {
  Map<String, dynamic> body = const {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
