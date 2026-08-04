// JEBV4-280 regression locks for the shared "Delivery" tab repository.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/order_history/data/dio_order_repository.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_repository.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_summary.dart';

void main() {
  late _RecordingAdapter adapter;
  late Dio dio;

  setUp(() {
    adapter = _RecordingAdapter();
    dio = Dio(BaseOptions(baseUrl: 'http://gw.test'))
      ..httpClientAdapter = adapter;
  });

  group('D1 — role-aware endpoint', () {
    test(
      'serializes the local half-open date range without UTC conversion',
      () async {
        adapter.body = {'items': const <Object?>[]};
        final range = OrderDateRange.forInclusiveDays(
          from: DateTime(2026, 10, 25),
          to: DateTime(2026, 10, 25),
        );

        await DioOrderRepository(dio).fetchPage(
          tab: OrderHistoryTab.active,
          page: 1,
          pageSize: 20,
          range: range,
        );

        expect(adapter.lastQuery['fromDate'], '2026-10-25T00:00:00.000');
        expect(adapter.lastQuery['toDate'], '2026-10-26T00:00:00.000');
      },
    );

    test(
      'customer (default) hits /v1/requests with the status filter',
      () async {
        adapter.body = {'items': const <Object?>[]};

        await DioOrderRepository(
          dio,
        ).fetchPage(tab: OrderHistoryTab.active, page: 1, pageSize: 20);

        expect(adapter.lastPath, '/v1/requests');
        expect(adapter.lastQuery['role'], isNull);
        expect(adapter.lastQuery['status'], 'active');
      },
    );

    test(
      'jeeber hits /v1/deliveries?role=jeeber and sends the per-tab status bucket',
      () async {
        adapter.body = {'items': const <Object?>[]};

        await DioOrderRepository(
          dio,
          asJeeber: true,
        ).fetchPage(tab: OrderHistoryTab.active, page: 1, pageSize: 20);

        expect(adapter.lastPath, '/v1/deliveries');
        expect(adapter.lastQuery['role'], 'jeeber');
        // JEBV4-307: the delivery endpoint honours the `status=` bucket token
        expect(adapter.lastQuery['status'], 'active');
        expect(adapter.lastQuery['page'], 1);
        expect(adapter.lastQuery['pageSize'], 20);
      },
    );

    test(
      'jeeber Completed/Cancelled tabs request the delivered/cancelled buckets',
      () async {
        adapter.body = {'items': const <Object?>[]};

        await DioOrderRepository(
          dio,
          asJeeber: true,
        ).fetchPage(tab: OrderHistoryTab.completed, page: 1, pageSize: 20);
        // JEBV4-307 regression lock: the jeeber Completed tab must ask the
        expect(adapter.lastPath, '/v1/deliveries');
        expect(adapter.lastQuery['role'], 'jeeber');
        expect(adapter.lastQuery['status'], 'delivered');

        await DioOrderRepository(
          dio,
          asJeeber: true,
        ).fetchPage(tab: OrderHistoryTab.cancelled, page: 1, pageSize: 20);
        expect(adapter.lastQuery['status'], 'cancelled');
      },
    );

    test(
      'jeeber delivery rows map + bucket via the delivery vocabulary',
      () async {
        // The gateway OrderListItem shape (no `amount` for a delivery job → the
        adapter.body = {
          'items': [
            {
              'id': 'd-ordered',
              'status': 'Ordered',
              'createdAt': '2026-07-11T09:00:00Z',
              'pickup': {'address': 'Pickup A'},
              'dropoff': {'address': 'Dropoff A'},
            },
            {
              'id': 'd-intransit',
              'status': 'InTransit',
              'createdAt': '2026-07-11T09:05:00Z',
            },
            {
              'id': 'd-done',
              'status': 'Done',
              'createdAt': '2026-07-11T08:00:00Z',
            },
          ],
        };

        final active = await DioOrderRepository(
          dio,
          asJeeber: true,
        ).fetchPage(tab: OrderHistoryTab.active, page: 1, pageSize: 20);

        expect(active.items.map((o) => o.id), ['d-ordered', 'd-intransit']);
        final ordered = active.items.first;
        expect(ordered.status, OrderRequestStatus.matched);
        expect(ordered.pickupAddress, 'Pickup A');
        // Absent amount → null (no crash, card shows "—").
        expect(active.items[1].amountMinor, isNull);

        final completed = await DioOrderRepository(
          dio,
          asJeeber: true,
        ).fetchPage(tab: OrderHistoryTab.completed, page: 1, pageSize: 20);
        expect(completed.items.map((o) => o.id), ['d-done']);
      },
    );
  });

  group('D2 — empty envelope is a valid empty page (not a parse error)', () {
    for (final asJeeber in [false, true]) {
      final label = asJeeber ? 'jeeber' : 'customer';
      test('$label: {"items":[]} → empty page, no throw', () async {
        adapter.body = {'items': const <Object?>[]};

        final page = await DioOrderRepository(
          dio,
          asJeeber: asJeeber,
        ).fetchPage(tab: OrderHistoryTab.active, page: 1, pageSize: 20);

        expect(page.items, isEmpty);
        expect(page.hasMore, isFalse);
      });
    }

    test('a Map with NO items list is still a parse error', () async {
      adapter.body = {'totalCount': 0};

      expect(
        () => DioOrderRepository(
          dio,
        ).fetchPage(tab: OrderHistoryTab.active, page: 1, pageSize: 20),
        throwsA(
          isA<OrderRepositoryException>().having(
            (e) => e.kind,
            'kind',
            OrderRepositoryErrorKind.parse,
          ),
        ),
      );
    });
  });
}

/// Stub [HttpClientAdapter] that records the outgoing request path + query and
/// replies with a fixed JSON [body].
class _RecordingAdapter implements HttpClientAdapter {
  Map<String, Object?> body = const {'items': <Object?>[]};

  String? lastPath;
  Map<String, dynamic> lastQuery = const {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastPath = options.path;
    lastQuery = Map<String, dynamic>.from(options.queryParameters);
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
