import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/notifications/data/dio_notifications_repository.dart';
import 'package:jeeb_mobile/features/notifications/domain/notifications_repository.dart';

/// Gateway projection of the real notification-service row captured from MSI
/// receiver `FM1-PROBE-b02-20260726` on 2026-07-26.
///
/// Source notification id, copy, and timestamp match the raw captured fixture in
/// `JeebNotificationsProjectionTests.cs`. The wire stays a JSON string until
/// [jsonDecode], so every case crosses the same serialization boundary as Dio.
const _capturedProjectedWire = '''
{"items":[{"id":"00468148-d722-445a-97a1-4e39b87dafb3","type":"jeeb.offer_received","title":"probe3","body":"FM-1 probe3 - safe to delete","ts":"2026-07-26T00:00:00.0000000","read":false}],"page":1,"pageSize":20,"totalCount":3,"totalPages":1}
''';

Dio _dioRespondingWithWire(String wire) {
  final dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response<dynamic>(
            data: jsonDecode(wire),
            statusCode: 200,
            requestOptions: options,
          ),
        );
      },
    ),
  );
  return dio;
}

Future<NotificationItem> _parseSingle(String wire) async {
  final repository = DioNotificationsRepository(
    dio: _dioRespondingWithWire(wire),
  );
  final items = await repository.fetchNotifications();
  expect(items, hasLength(1));
  return items.single;
}

String _withField(String fieldJson) => _capturedProjectedWire.replaceFirst(
  '"read":false',
  '"read":false,$fieldJson',
);

void main() {
  test('R19 captured wire rejects degenerate ref and type shapes', () async {
    final missingRef = await _parseSingle(_capturedProjectedWire);
    expect(missingRef.ref, isNull);
    expect(missingRef.kind, NotificationKind.offer);

    final emptyRef = await _parseSingle(_withField('"ref":""'));
    expect(emptyRef.ref, isNull);

    final huskedRef = await _parseSingle(_withField('"ref":{"valueKind":1}'));
    expect(huskedRef.ref, isNull);

    final unknownType = await _parseSingle(
      _capturedProjectedWire.replaceFirst(
        '"type":"jeeb.offer_received",',
        '"type":"future_notification",',
      ),
    );
    expect(unknownType.kind, NotificationKind.unknown);

    final absentType = await _parseSingle(
      _capturedProjectedWire.replaceFirst('"type":"jeeb.offer_received",', ''),
    );
    expect(absentType.kind, NotificationKind.unknown);
  });

  test('captured wire accepts offer and order ref aliases', () async {
    const aliases = <String, String>{
      'offerId': 'offer-camel',
      'offer_id': 'offer-snake',
      'orderId': 'order-camel',
    };

    for (final entry in aliases.entries) {
      final item = await _parseSingle(
        _withField('"${entry.key}":"${entry.value}"'),
      );
      expect(item.ref, entry.value);
    }
  });
}
