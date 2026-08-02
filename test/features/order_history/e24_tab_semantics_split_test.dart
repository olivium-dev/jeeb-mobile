// JEBV4-219 / E24 — Tab semantics (Q-086 RATIFIED, verbatim: "Requests are

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/order_history/data/dio_order_repository.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_summary.dart';

void main() {
  late _RecordingAdapter adapter;
  late Dio dio;

  setUp(() {
    adapter = _RecordingAdapter();
    dio = Dio(BaseOptions(baseUrl: 'http://gw.test'))
      ..httpClientAdapter = adapter;
  });

  group('OrderRequestStatus.isOnHold', () {
    test('pending is on-hold; every other status is accepted-onward', () {
      expect(OrderRequestStatus.pending.isOnHold, isTrue);
      for (final status in OrderRequestStatus.values) {
        if (status == OrderRequestStatus.pending) continue;
        expect(
          status.isOnHold,
          isFalse,
          reason: '$status must be accepted-onward, not on-hold',
        );
      }
    });
  });

  group('E24 — Delivery tab never lists on-hold (not-yet-accepted) items', () {
    test(
      'a pending/searching row returned under the advisory status=active '
      'filter is dropped, not shown on the Active tab',
      () async {
        adapter.body = {
          'items': [
            {
              'id': 'r-onhold',
              'status': 'pending',
              'createdAt': '2026-07-11T09:00:00Z',
              'pickup': {'address': 'Pickup A'},
              'dropoff': {'address': 'Dropoff A'},
            },
            {
              'id': 'r-accepted',
              'status': 'accepted',
              'createdAt': '2026-07-11T09:05:00Z',
              'pickup': {'address': 'Pickup B'},
              'dropoff': {'address': 'Dropoff B'},
            },
          ],
        };

        final active = await DioOrderRepository(
          dio,
        ).fetchPage(tab: OrderHistoryTab.active, page: 1, pageSize: 20);

        expect(active.items.map((o) => o.id), ['r-accepted']);
        expect(
          active.items.any((o) => o.status.isOnHold),
          isFalse,
          reason: 'no on-hold row may ever render on the Delivery tab',
        );
      },
    );

    test(
      'an on-hold row never leaks onto Completed or Cancelled either',
      () async {
        adapter.body = {
          'items': [
            {
              'id': 'r-searching',
              'status': 'searching',
              'createdAt': '2026-07-11T09:00:00Z',
            },
          ],
        };

        final completed = await DioOrderRepository(
          dio,
        ).fetchPage(tab: OrderHistoryTab.completed, page: 1, pageSize: 20);
        final cancelled = await DioOrderRepository(
          dio,
        ).fetchPage(tab: OrderHistoryTab.cancelled, page: 1, pageSize: 20);

        expect(completed.items, isEmpty);
        expect(cancelled.items, isEmpty);
      },
    );
  });
}

/// Stub [HttpClientAdapter] that records the outgoing request and replies
/// with a fixed JSON [body]. Mirrors the harness in
/// `dio_order_repository_role_aware_test.dart`.
class _RecordingAdapter implements HttpClientAdapter {
  Map<String, Object?> body = const {'items': <Object?>[]};

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
