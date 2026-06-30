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

    // FIX-TIERS-FIVE — addressability/regression lock for the live mock
    // contract. On-device only 3 tier cards rendered (Flash/Express/Standard)
    // because the Mockoon :3055 `GET /tiers` route served only 3 rows from the
    // s05-order-prohibited-items bucket, even though TierId has 5 values and
    // the screen/_tierIcon resolver cover all 5. The unit suite stayed green
    // because every screen test injects FakeTierRepository (5 rows). This test
    // closes that gap: it feeds DioTierRepository the EXACT payload the mock
    // now serves (verified `curl localhost:3055/tiers`) — 5 items including the
    // snake_case `on_the_way` id and a null slaHours on the opportunistic tier
    // — and asserts all five parse, in Figma display order, with the correct
    // TierId mapping. It would go red if the mock regresses to the 3-row list.
    test('parses the full 5-tier mock contract (Flash→Express→Standard→'
        'On-the-way→Eco), mapping snake_case on_the_way + null SLA', () async {
      final dio = _dioWith({
        'items': [
          {'id': 'flash', 'name': 'Flash', 'slaHours': 1, 'radiusKm': 3.0, 'commissionRate': 0.15, 'priceHint': r'$$$'},
          {'id': 'express', 'name': 'Express', 'slaHours': 2, 'radiusKm': 10.0, 'commissionRate': 0.12, 'priceHint': r'$$'},
          {'id': 'standard', 'name': 'Standard', 'slaHours': 8, 'radiusKm': 25.0, 'commissionRate': 0.10, 'priceHint': r'$'},
          {'id': 'on_the_way', 'name': 'On-the-way', 'slaHours': null, 'radiusKm': 40.0, 'commissionRate': 0.08, 'priceHint': r'$'},
          {'id': 'eco', 'name': 'Eco', 'slaHours': 48, 'radiusKm': 40.0, 'commissionRate': 0.06, 'priceHint': r'$'},
        ],
      });
      final repo = DioTierRepository(dio);

      final tiers = await repo.fetchTiers();

      expect(
        tiers.map((t) => t.id).toList(),
        const [
          TierId.flash,
          TierId.express,
          TierId.standard,
          TierId.onTheWay,
          TierId.eco,
        ],
        reason: 'all five TierId values must round-trip from the live mock',
      );
      // Opportunistic tier carries no SLA (null slaHours → null slaMinutes).
      final onTheWay = tiers.firstWhere((t) => t.id == TierId.onTheWay);
      expect(onTheWay.slaMinutes, isNull);
      // Eco's 48h SLA survives the hours→minutes conversion.
      final eco = tiers.firstWhere((t) => t.id == TierId.eco);
      expect(eco.slaMinutes, 48 * 60);
    });

    // P0 REGRESSION (BUG-tier-parse) — the LIVE jeeb-gateway
    // (192.168.2.39:10090 GET /tiers) returns 200 with items shaped
    // {"id":"<uuid>","name":"Flash", ...} — the label is in `name`, the `id`
    // is a UUID, and `priceHint` is free text ("Within 30 minutes"). The old
    // `_parseId` switched on the `id` slug only, so every live row fell through
    // to null → `.whereType<Tier>()` dropped all 3 → empty tier list → ZERO
    // tier cards on "Choose your request" → Continue disabled → no order could
    // be created. This test feeds the EXACT live payload and asserts all 3
    // tiers parse, resolved by `name`, with the gateway UUID preserved on
    // `serverId` for the create-request RPC. It is RED on the pre-fix code
    // (returns 0 tiers) and GREEN on the fix.
    test('parses LIVE gateway shape (uuid id + name label + free-text '
        'priceHint), mapping by name and preserving the uuid', () async {
      final dio = _dioWith({
        'items': [
          {
            'id': '0be308ce-01b5-5cb9-a3e8-9adb60668d9c',
            'name': 'Flash',
            'slaHours': 1,
            'radiusKm': 3,
            'commissionRate': 0.25,
            'priceHint': 'Within 30 minutes',
          },
          {
            'id': 'efe0629b-0b50-555c-b182-4bd41fcd6507',
            'name': 'Express',
            'slaHours': 2,
            'radiusKm': 10,
            'commissionRate': 0.2,
            'priceHint': 'Within 2 hours',
          },
          {
            'id': '2bd0d5df-db76-5d14-9e4d-741d60b2fa12',
            'name': 'Standard',
            'slaHours': 24,
            'radiusKm': 25,
            'commissionRate': 0.15,
            'priceHint': 'Same-day delivery',
          },
        ],
      });
      final repo = DioTierRepository(dio);

      final tiers = await repo.fetchTiers();

      // The bug: this was 0 before the fix.
      expect(tiers.length, 3, reason: 'all 3 live tiers must parse by name');
      expect(
        tiers.map((t) => t.id).toList(),
        const [TierId.flash, TierId.express, TierId.standard],
      );
      // SLA still converts hours → minutes off the live payload.
      expect(tiers[0].slaMinutes, 60);
      expect(tiers[2].slaMinutes, 24 * 60);
      // The gateway UUID is preserved verbatim for POST /requests → tierId.
      expect(tiers[0].serverId, '0be308ce-01b5-5cb9-a3e8-9adb60668d9c');
      expect(tiers[1].serverId, 'efe0629b-0b50-555c-b182-4bd41fcd6507');
      expect(tiers[0].recommended, isTrue);
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
