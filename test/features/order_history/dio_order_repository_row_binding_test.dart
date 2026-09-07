// X1 / F4b binding locks for the row parser, keyed to the wire the device
// actually returned (fault-proxy/S06/logcat.txt, GET /v1/requests body).
// `title` and `displayId` were dropped on the floor, and the price binding
// read only `amount` — the wire's own price token is `fee` (GET /v1/offers).

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/order_history/data/dio_order_repository.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_summary.dart';

void main() {
  late _StubAdapter adapter;
  late Dio dio;

  setUp(() {
    adapter = _StubAdapter();
    dio = Dio(BaseOptions(baseUrl: 'http://gw.test'))
      ..httpClientAdapter = adapter;
  });

  Future<OrderSummary> firstCancelled() async {
    final OrderPage page = await DioOrderRepository(dio).fetchPage(
      tab: OrderHistoryTab.cancelled,
      page: 1,
      pageSize: 20,
    );
    return page.items.first;
  }

  group('F4b — identity fields carried off the wire', () {
    test('the device row keeps its displayId and title', () async {
      adapter.body = <String, Object?>{
        'items': <Object?>[
          <String, Object?>{
            'id': 'defb1f07-efa5-4b8f-bc1a-09d6fcd1140b',
            'displayId': 'defb1f07',
            'status': 'Cancelled',
            'title': 'F8-resolve-probe-parcel',
            'tier': 'scheduled',
            'pickup': <String, Object?>{'address': 'Current location'},
            'dropoff': <String, Object?>{'address': 'Current location'},
            'createdAt': '2026-09-05T11:21:56.422151+00:00',
          },
        ],
      };

      final OrderSummary order = await firstCancelled();

      expect(order.displayId, 'defb1f07');
      expect(order.title, 'F8-resolve-probe-parcel');
      expect(order.referenceLabel, 'defb1f07');
    });

    test('the ORD- display form is carried verbatim, never synthesized', () async {
      adapter.body = <String, Object?>{
        'items': <Object?>[
          <String, Object?>{
            'id': '8a87f41f-0aee-4163-8890-bee34765a836',
            'displayId': 'ORD-65A836',
            'status': 'cancelled',
            'createdAt': '2026-09-05T07:29:23.594971+00:00',
          },
        ],
      };

      final OrderSummary order = await firstCancelled();

      expect(order.referenceLabel, 'ORD-65A836');
    });

    test('a row with no displayId falls back to the id, not an empty label', () async {
      adapter.body = <String, Object?>{
        'items': <Object?>[
          <String, Object?>{
            'id': 'bare-row',
            'status': 'cancelled',
            'createdAt': '2026-09-05T07:29:23Z',
          },
        ],
      };

      final OrderSummary order = await firstCancelled();

      expect(order.displayId, isEmpty);
      expect(order.referenceLabel, 'bare-row');
      expect(order.title, isEmpty);
    });
  });

  group('X1 — price binding accepts the wire vocabulary', () {
    test('`fee` (major units, as GET /v1/offers sends it) binds the amount', () async {
      adapter.body = <String, Object?>{
        'items': <Object?>[
          <String, Object?>{
            'id': 'fee-row',
            'status': 'cancelled',
            'createdAt': '2026-09-05T07:29:23Z',
            'fee': 2,
          },
        ],
      };

      final OrderSummary order = await firstCancelled();

      expect(order.amountMinor, 200);
      expect(order.hasKnownAmount, isTrue);
    });

    test('a `price` object with minorUnits binds too', () async {
      adapter.body = <String, Object?>{
        'items': <Object?>[
          <String, Object?>{
            'id': 'price-row',
            'status': 'cancelled',
            'createdAt': '2026-09-05T07:29:23Z',
            'price': <String, Object?>{'minorUnits': 1250, 'currency': 'LBP'},
          },
        ],
      };

      final OrderSummary order = await firstCancelled();

      expect(order.amountMinor, 1250);
      expect(order.currency, 'LBP');
    });

    test('`amount` still wins when both are present', () async {
      adapter.body = <String, Object?>{
        'items': <Object?>[
          <String, Object?>{
            'id': 'both-row',
            'status': 'cancelled',
            'createdAt': '2026-09-05T07:29:23Z',
            'amount': 9,
            'fee': 2,
          },
        ],
      };

      expect((await firstCancelled()).amountMinor, 900);
    });

    test('the device row carries NO price token → still unknown, never \$0', () async {
      adapter.body = <String, Object?>{
        'items': <Object?>[
          <String, Object?>{
            'id': 'defb1f07-efa5-4b8f-bc1a-09d6fcd1140b',
            'displayId': 'defb1f07',
            'status': 'Cancelled',
            'title': 'F8-resolve-probe-parcel',
            'createdAt': '2026-09-05T11:21:56.422151+00:00',
          },
        ],
      };

      final OrderSummary order = await firstCancelled();

      expect(order.amountMinor, isNull);
      expect(order.hasKnownAmount, isFalse);
    });
  });
}

/// Stub [HttpClientAdapter] replying with a fixed JSON [body].
class _StubAdapter implements HttpClientAdapter {
  Map<String, Object?> body = const <String, Object?>{'items': <Object?>[]};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}
