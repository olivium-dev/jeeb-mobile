// G3: `new_request` inbox rows must parse to a ROUTABLE typed kind. Before

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/notifications/data/dio_notifications_repository.dart';
import 'package:jeeb_mobile/features/notifications/domain/notifications_repository.dart';

Dio _dioRespond(Object? body) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response(data: body, statusCode: 200, requestOptions: options),
        );
      },
    ),
  );
  return dio;
}

void main() {
  group('DioNotificationsRepository — new_request kind (G3)', () {
    test('type=new_request maps to NotificationKind.newRequest with the '
        'requestId as ref', () async {
      final repo = DioNotificationsRepository(
        dio: _dioRespond({
          'items': [
            {
              'id': 'n-1',
              'type': 'new_request',
              'title': 'New request nearby',
              'body': '2 shawarma + cola from Barbar',
              'createdAt': '2026-07-03T10:00:00Z',
              'read': false,
              'requestId': 'req-42',
            },
          ],
        }),
      );

      final items = await repo.fetchNotifications();

      expect(items, hasLength(1));
      expect(items.single.kind, NotificationKind.newRequest,
          reason: 'pre-fix this fell through to unknown (un-routable)');
      expect(items.single.ref, 'req-42',
          reason: 'requestId must ride the ref chain so the row can route');
    });

    test('camelCase newRequest wire value also maps', () async {
      final repo = DioNotificationsRepository(
        dio: _dioRespond({
          'items': [
            {
              'id': 'n-2',
              'kind': 'newRequest',
              'title': 't',
              'body': 'b',
              'ts': '2026-07-03T10:00:00Z',
              'read': true,
              'ref': 'req-7',
            },
          ],
        }),
      );

      final items = await repo.fetchNotifications();
      expect(items.single.kind, NotificationKind.newRequest);
      expect(items.single.ref, 'req-7',
          reason: 'an explicit ref key still wins over requestId');
    });

    test('an explicit ref/targetId outranks requestId; requestId outranks '
        'deliveryId', () async {
      final repo = DioNotificationsRepository(
        dio: _dioRespond({
          'items': [
            {
              'id': 'n-3',
              'type': 'new_request',
              'title': 't',
              'body': 'b',
              'createdAt': '2026-07-03T10:00:00Z',
              'read': false,
              'requestId': 'req-1',
              'deliveryId': 'dlv-9',
            },
          ],
        }),
      );

      final items = await repo.fetchNotifications();
      expect(items.single.ref, 'req-1');
    });

    test('a truly unknown type still maps to unknown (no regression)',
        () async {
      final repo = DioNotificationsRepository(
        dio: _dioRespond({
          'items': [
            {
              'id': 'n-4',
              'type': 'something_else',
              'title': 't',
              'body': 'b',
              'createdAt': '2026-07-03T10:00:00Z',
              'read': false,
            },
          ],
        }),
      );

      final items = await repo.fetchNotifications();
      expect(items.single.kind, NotificationKind.unknown);
    });
  });
}
