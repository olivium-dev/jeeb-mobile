import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/order_history/data/dio_order_repository.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_repository.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_summary.dart';

Dio _capturingDio(
  Object? responseBody, {
  void Function(RequestOptions options)? onRequest,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        onRequest?.call(options);
        handler.resolve(
          Response(
            data: responseBody,
            statusCode: 200,
            requestOptions: options,
          ),
        );
      },
    ),
  );
  return dio;
}

void main() {
  group('DioOrderRepository', () {
    test('uses the live deliveries list contract for the active tab', () async {
      late RequestOptions captured;
      final repo = DioOrderRepository(
        _capturingDio({
          'shipments': <dynamic>[],
          'count': 0,
        }, onRequest: (options) => captured = options),
      );

      final page = await repo.fetchPage(
        tab: OrderHistoryTab.active,
        page: 1,
        pageSize: 20,
      );

      expect(captured.path, '/deliveries');
      expect(captured.queryParameters['stage'], 'active');
      expect(captured.queryParameters['page'], 1);
      expect(captured.queryParameters['limit'], 20);
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test(
      'parses delivery currentStage values from the live contract',
      () async {
        final repo = DioOrderRepository(
          _capturingDio({
            'items': [
              {
                'id': 'delivery-1',
                'createdAt': '2026-06-20T10:00:00Z',
                'currentStage': 'InTransit',
                'tier': 'standard',
                'pickup': {'address': 'Pickup'},
                'dropoff': {'address': 'Dropoff'},
              },
            ],
          }),
        );

        final page = await repo.fetchPage(
          tab: OrderHistoryTab.active,
          page: 1,
          pageSize: 20,
        );

        expect(page.items.single.id, 'delivery-1');
        expect(page.items.single.status, OrderRequestStatus.enRoute);
        expect(page.items.single.pickupAddress, 'Pickup');
        expect(page.items.single.dropoffAddress, 'Dropoff');
      },
    );
  });
}
