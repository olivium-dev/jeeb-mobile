import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/location/data/dio_saved_location_repository.dart';
import 'package:jeeb_mobile/features/location/domain/saved_location.dart';

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
  group('DioSavedLocationRepository — T-MOB-012 endpoint contract', () {
    test('GET uses /v1/users/me/saved-locations path (mock :3055 verified)',
        () async {
      _capturedPath = null;
      final repo = DioSavedLocationRepository(_capturingDio(<dynamic>[]));

      await repo.fetchSavedLocations();

      expect(_capturedPath, '/v1/users/me/saved-locations');
      expect(_capturedMethod, 'GET');
    });

    test('POST uses /v1/users/me/saved-locations path', () async {
      _capturedPath = null;
      final repo = DioSavedLocationRepository(
        _capturingDio(<String, dynamic>{
          'id': 'loc-1',
          'label': 'Home',
          'latitude': 33.88,
          'longitude': 35.5,
          'category': 'home',
        }),
      );

      await repo.saveLocation(
        latitude: 33.88,
        longitude: 35.5,
        label: 'Home',
        category: SavedLocationCategory.home,
      );

      expect(_capturedPath, '/v1/users/me/saved-locations');
      expect(_capturedMethod, 'POST');
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
      final repo = DioSavedLocationRepository(dio);

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
      final repo = DioSavedLocationRepository(dio);

      final locations = await repo.fetchSavedLocations();

      expect(locations.length, 1);
      expect(locations[0].category, SavedLocationCategory.work);
    });

    test('returns empty list for unexpected response shape', () async {
      final dio = _dioWith(null);
      final repo = DioSavedLocationRepository(dio);

      final locations = await repo.fetchSavedLocations();

      expect(locations, isEmpty);
    });
  });
}
