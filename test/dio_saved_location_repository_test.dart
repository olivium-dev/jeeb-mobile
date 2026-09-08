import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/features/location/data/dio_saved_location_repository.dart';
import 'package:jeeb_mobile/features/location/domain/saved_location.dart';
import 'package:jeeb_mobile/features/location/domain/saved_location_repository.dart';

/// In-memory [AuthTokenStore] so the repo's userId resolution is deterministic
/// without the secure-storage platform channel (mirrors the W1 seam stores).
class _FakeTokenStore implements AuthTokenStore {
  _FakeTokenStore(this._userId);
  final String? _userId;

  @override
  Future<String?> get userId async => _userId;

  @override
  Future<String?> get accessToken async => null;
  @override
  Future<String?> get refreshToken async => null;
  @override
  Future<bool> get hasToken async => false;
  @override
  Future<void> clear() async {}
  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
    String? userId,
  }) async {}
}

Dio _dioWith(Object? body, {int status = 200}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response(data: body, statusCode: status, requestOptions: options),
        );
      },
    ),
  );
  return dio;
}

Dio _dioThrowing(int status) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.reject(
          DioException(
            requestOptions: options,
            response: Response(statusCode: status, requestOptions: options),
            type: DioExceptionType.badResponse,
          ),
        );
      },
    ),
  );
  return dio;
}

String? _capturedPath;
String? _capturedMethod;

Dio _capturingDio(Object? responseBody) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        _capturedPath = options.path;
        _capturedMethod = options.method;
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
  group('DioSavedLocationRepository — JM-049 W1 endpoint contract', () {
    // The repo resolves its path via MockGatewayClient.savedLocationsPath. In
    test('GET uses the live /api/users/me/saved-locations contract', () async {
      _capturedPath = null;
      final repo = DioSavedLocationRepository(
        _capturingDio(<dynamic>[]),
        tokenStore: _FakeTokenStore('user-client-001'),
      );

      await repo.fetchSavedLocations();

      expect(_capturedPath, '/api/users/me/saved-locations');
      expect(_capturedMethod, 'GET');
    });

    test('POST uses the live /api/users/me/saved-locations contract', () async {
      _capturedPath = null;
      final repo = DioSavedLocationRepository(
        _capturingDio(<String, dynamic>{
          'id': 'loc-1',
          'label': 'Home',
          'latitude': 33.88,
          'longitude': 35.5,
          'category': 'home',
        }),
        tokenStore: _FakeTokenStore('user-client-001'),
      );

      await repo.saveLocation(
        latitude: 33.88,
        longitude: 35.5,
        label: 'Home',
        category: SavedLocationCategory.home,
      );

      expect(_capturedPath, '/api/users/me/saved-locations');
      expect(_capturedMethod, 'POST');
    });

    // GEN-01: a null session id used to fall back to `user-client-001`, which
    // reads ANOTHER account's saved-locations path. It must refuse instead.
    test('null persisted userId throws UnauthorizedFailure and issues no call',
        () async {
      _capturedPath = null;
      final repo = DioSavedLocationRepository(
        _capturingDio(<dynamic>[]),
        tokenStore: _FakeTokenStore(null),
      );

      await expectLater(
        repo.fetchSavedLocations(),
        throwsA(isA<UnauthorizedFailure>()),
      );
      expect(_capturedPath, isNull);
    });

    test('parses array response correctly', () async {
      final dio = _dioWith([
        {
          'id': 'loc-1',
          'label': 'Home',
          'latitude': 33.8938,
          'longitude': 35.5018,
          'category': 'home',
          'address': 'Downtown, Beirut',
        },
      ]);
      final repo = DioSavedLocationRepository(
        dio,
        tokenStore: _FakeTokenStore('user-client-001'),
      );

      final locations = await repo.fetchSavedLocations();

      expect(locations.length, 1);
      expect(locations[0].id, 'loc-1');
      expect(locations[0].category, SavedLocationCategory.home);
      expect(locations[0].latitude, closeTo(33.8938, 1e-6));
    });

    test('parses items-wrapped response', () async {
      final dio = _dioWith({
        'items': [
          {
            'id': 'loc-2',
            'label': 'Work',
            'latitude': 33.89,
            'longitude': 35.51,
            'category': 'work',
          },
        ],
      });
      final repo = DioSavedLocationRepository(
        dio,
        tokenStore: _FakeTokenStore('user-client-001'),
      );

      final locations = await repo.fetchSavedLocations();

      expect(locations.length, 1);
      expect(locations[0].category, SavedLocationCategory.work);
    });

    // JM-049: the `has_saved_addresses` seam shape — nested geo + isDefault /
    test('parses seam shape (geo, isDefault, form fields)', () async {
      final dio = _dioWith({
        'items': [
          {
            'id': 'addr-client-001-home',
            'label': 'Home',
            'isDefault': true,
            'is_default': true,
            'building': 'Sahar Building',
            'floorApt': '4th floor, Apt 12',
            'deliveryNotes': 'Ring twice; blue door.',
            'codPhone': '+96170000001',
            'geo': {'lat': 33.8869, 'lng': 35.5131},
            'address': 'Sassine Square, Ashrafieh',
          },
          {
            'id': 'addr-client-001-office',
            'label': 'Office',
            'isDefault': false,
            'geo': {'lat': 33.8938, 'lng': 35.5018},
            'address': 'Downtown Beirut',
          },
        ],
      });
      final repo = DioSavedLocationRepository(
        dio,
        tokenStore: _FakeTokenStore('user-client-001'),
      );

      final locations = await repo.fetchSavedLocations();

      expect(locations.length, 2);
      final home = locations[0];
      expect(home.id, 'addr-client-001-home');
      expect(home.isDefault, isTrue);
      expect(home.latitude, closeTo(33.8869, 1e-6));
      expect(home.longitude, closeTo(35.5131, 1e-6));
      expect(home.building, 'Sahar Building');
      expect(home.floorApt, '4th floor, Apt 12');
      expect(home.deliveryNotes, 'Ring twice; blue door.');
      expect(home.codPhone, '+96170000001');
      expect(home.category, SavedLocationCategory.home);
      expect(locations[1].isDefault, isFalse);
    });

    test('returns empty list for unexpected response shape', () async {
      final dio = _dioWith(null);
      final repo = DioSavedLocationRepository(
        dio,
        tokenStore: _FakeTokenStore('user-client-001'),
      );

      final locations = await repo.fetchSavedLocations();

      expect(locations, isEmpty);
    });

    test('maps 422 limit_reached to SavedLocationCapReachedException', () async {
      final repo = DioSavedLocationRepository(
        _dioThrowing(422),
        tokenStore: _FakeTokenStore('user-client-001'),
      );

      expect(
        () => repo.saveLocation(
          latitude: 0,
          longitude: 0,
          label: 'x',
          category: SavedLocationCategory.other,
        ),
        throwsA(isA<SavedLocationCapReachedException>()),
      );
    });

    test('maps 409 to SavedLocationCapReachedException (legacy gateway)',
        () async {
      final repo = DioSavedLocationRepository(
        _dioThrowing(409),
        tokenStore: _FakeTokenStore('user-client-001'),
      );

      expect(
        () => repo.saveLocation(
          latitude: 0,
          longitude: 0,
          label: 'x',
          category: SavedLocationCategory.other,
        ),
        throwsA(isA<SavedLocationCapReachedException>()),
      );
    });
  });
}
