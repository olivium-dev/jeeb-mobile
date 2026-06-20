// §6B jeeber re-capture (S22) — DEFECT-A & DEFECT-B regression locks.
//
// DEFECT-A: the jeeber order-history (Delivery tab) repository must call the
//   gateway-contract `GET /v1/requests` — NOT the dead `/api/requests` prefix
//   (which 404'd, showing "Couldn't load orders"). The CUSTOMER list already
//   uses `/v1/requests`; this proves the shared repo now matches.
//
// DEFECT-B: the jeeber Earnings repository must NOT send a hardcoded
//   `jeeberId=user-jeeber-002` query param — the live gateway resolves the
//   owner from the bearer token and ignores any client-supplied id. When the
//   caller passes no id, no `jeeberId` key is on the request.

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
      when(() => dio.get<Map<String, dynamic>>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((inv) async {
        capturedPath = inv.positionalArguments.first as String;
        return _ok({'items': const [], 'page': 1, 'pageSize': 20});
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
      // PR #57's EarningsSummary parser + its own tests; this file only locks the
      // param-omission half of DEFECT-B (the part this PR adds).
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
