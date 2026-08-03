// §6B jeeber re-capture (S22) — DEFECT-A & DEFECT-B regression locks.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/features/order_history/data/dio_order_repository.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_summary.dart';
import 'package:jeeb_mobile/features/earnings/data/dio_earnings_repository.dart';
import 'package:jeeb_mobile/features/earnings/domain/earnings_repository.dart';

class _MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> _ok(Map<String, dynamic> data) =>
    Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: ''),
      data: data,
      statusCode: 200,
    );

void main() {
  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  late _MockDio dio;

  setUp(() => dio = _MockDio());

  group('DEFECT-A — jeeber order-history hits /v1/requests (not /api/requests)',
      () {
    test('GET path is /v1/requests', () async {
      String? capturedPath;
      // DioOrderRepository calls `dio.get<dynamic>` (it parses the envelope
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((inv) async {
        capturedPath = inv.positionalArguments.first as String;
        // A non-empty page so fetchPage completes (the repo treats an empty
        return _ok({
          'items': [
            {'id': 'r-1', 'status': 'pending'},
          ],
          'page': 1,
          'pageSize': 20,
        });
      });

      await DioOrderRepository(dio).fetchPage(
        tab: OrderHistoryTab.active,
        page: 1,
        pageSize: 20,
      );

      expect(capturedPath, '/v1/requests');
      expect(capturedPath, isNot(contains('/api/requests')));
    });
  });

  group('DEFECT-B — jeeber earnings omits the hardcoded jeeberId param', () {
    test('no jeeberId query param when caller supplies none', () async {
      Map<String, dynamic>? capturedQuery;
      when(() => dio.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((inv) async {
        capturedQuery = (inv.namedArguments[const Symbol('queryParameters')]
            as Map<String, dynamic>);
        return _ok({'totalNet': 91.37, 'rowCount': 2, 'currency': 'USD'});
      });

      await DioEarningsRepository(dio)
          .fetchEarnings(period: EarningsPeriod.today);

      expect(capturedQuery, isNotNull);
      expect(capturedQuery!.containsKey('jeeberId'), isFalse,
          reason: 'live gateway scopes to the token; no client id is sent');
      expect(capturedQuery!['period'], 'today');
      // NOTE: binding the response tiles (totalNet/rowCount/entries) is fixed by
    });

    test('jeeberId IS sent when a caller explicitly supplies one (mock/tests)',
        () async {
      Map<String, dynamic>? capturedQuery;
      when(() => dio.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((inv) async {
        capturedQuery = (inv.namedArguments[const Symbol('queryParameters')]
            as Map<String, dynamic>);
        return _ok({'totalNet': 0, 'rowCount': 0, 'currency': 'USD'});
      });

      await DioEarningsRepository(dio)
          .fetchEarnings(jeeberId: 'seam-jeeber', period: EarningsPeriod.week);

      expect(capturedQuery!['jeeberId'], 'seam-jeeber');
    });
  });
}
