import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/notifications/data/dio_notifications_repository.dart';
import 'package:jeeb_mobile/features/notifications/domain/notifications_repository.dart';

/// These gateway-projection wires are explicitly constructed literal fixtures:
/// FM-1 cannot deploy its gateway branch to capture that boundary. The source
String _fixture(String name) =>
    File('test/features/notifications/fixtures/fm1/$name').readAsStringSync();

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

void main() {
  test(
    'FM1 R19 constructed gateway wire rejects degenerate ref and type shapes',
    () async {
      final missingRef = await _parseSingle(
        _fixture('constructed-projected-offer-no-ref.json'),
      );
      expect(missingRef.ref, isNull);
      expect(missingRef.kind, NotificationKind.offer);

      final emptyRef = await _parseSingle(
        _fixture('constructed-projected-offer-empty-ref.json'),
      );
      expect(emptyRef.ref, isNull);

      final huskedRef = await _parseSingle(
        _fixture('constructed-projected-offer-husk-ref.json'),
      );
      expect(huskedRef.ref, isNull);

      final unknownType = await _parseSingle(
        _fixture('constructed-projected-unknown-type.json'),
      );
      expect(unknownType.kind, NotificationKind.unknown);

      final absentType = await _parseSingle(
        _fixture('constructed-projected-absent-type.json'),
      );
      expect(absentType.kind, NotificationKind.unknown);
    },
  );

  test(
    'FM1 constructed gateway wire accepts offer and order ref aliases',
    () async {
      const aliases = <String, String>{
        'constructed-projected-offer-id-camel.json': 'offer-camel',
        'constructed-projected-offer-id-snake.json': 'offer-snake',
        'constructed-projected-order-id-camel.json': 'order-camel',
      };

      for (final entry in aliases.entries) {
        final item = await _parseSingle(_fixture(entry.key));
        expect(item.ref, entry.value);
      }
    },
  );
}
