import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';
import 'package:jeeb_mobile/features/tier_selection/domain/tier.dart';

Dio _dioWith(Object? body, {int status = 200}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response(
            data: body,
            statusCode: status,
            requestOptions: options,
          ),
        );
      },
    ),
  );
  return dio;
}

Dio _dioError(DioExceptionType type, {int? status}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.reject(
          DioException(
            requestOptions: options,
            type: type,
            response: status != null
                ? Response(
                    data: null,
                    statusCode: status,
                    requestOptions: options,
                  )
                : null,
          ),
        );
      },
    ),
  );
  return dio;
}

void main() {
  group('DioTierRepository — T-MOB-010 endpoint contract', () {
    test('parses mock :3055 items-wrapped response', () async {
      final dio = _dioWith({
        'items': [
          {
            'id': 'flash',
            'name': 'Flash',
            'slaHours': 1,
            'radiusKm': 3.0,
            'priceHint': r'$$$',
          },
          {
            'id': 'express',
            'name': 'Express',
            'slaHours': 2,
            'radiusKm': 10.0,
            'priceHint': r'$$',
          },
          {
            'id': 'standard',
            'name': 'Standard',
            'slaHours': 8,
            'radiusKm': 25.0,
            'priceHint': r'$',
          },
        ],
      });
      final repo = DioTierRepository(dio);

      final tiers = await repo.fetchTiers();

      expect(tiers.length, 3);
      expect(tiers[0].id, TierId.flash);
      expect(tiers[0].slaMinutes, 60);
      expect(tiers[0].recommended, isTrue);
      expect(tiers[1].id, TierId.express);
      expect(tiers[1].slaMinutes, 120);
      expect(tiers[2].id, TierId.standard);
      expect(tiers[2].slaMinutes, 480);
    });

    test('accepts bare array response', () async {
      final dio = _dioWith([
        {'id': 'flash', 'slaHours': 1, 'priceHint': r'$$$'},
      ]);
      final repo = DioTierRepository(dio);

      final tiers = await repo.fetchTiers();
      expect(tiers.length, 1);
      expect(tiers[0].id, TierId.flash);
    });

    test('throws TierLoadException.network on connection error', () async {
      final dio = _dioError(DioExceptionType.connectionError);
      final repo = DioTierRepository(dio);

      await expectLater(
        repo.fetchTiers(),
        throwsA(
          predicate<TierLoadException>(
            (e) => e.failure == TierLoadFailure.network,
          ),
        ),
      );
    });

    test('throws TierLoadException.server for unexpected response shape',
        () async {
      final dio = _dioWith('unexpected_string');
      final repo = DioTierRepository(dio);

      await expectLater(
        repo.fetchTiers(),
        throwsA(
          predicate<TierLoadException>(
            (e) => e.failure == TierLoadFailure.server,
          ),
        ),
      );
    });

    test('skips entries missing id field', () async {
      final dio = _dioWith({
        'items': [
          {'id': 'flash', 'slaHours': 1, 'priceHint': r'$$$'},
          {'name': 'Broken entry, no id'},
        ],
      });
      final repo = DioTierRepository(dio);

      final tiers = await repo.fetchTiers();
      expect(tiers.length, 1);
    });

    test('uses /tiers path (verified against Mockoon :3055)', () async {
      String? capturedPath;
      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedPath = options.path;
            handler.resolve(
              Response(
                data: {'items': <dynamic>[]},
                statusCode: 200,
                requestOptions: options,
              ),
            );
          },
        ),
      );
      await DioTierRepository(dio).fetchTiers();
      expect(capturedPath, '/tiers');
    });
  });
}
