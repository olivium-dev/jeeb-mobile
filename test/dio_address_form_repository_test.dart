import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/location/data/dio_address_form_repository.dart';
import 'package:jeeb_mobile/features/location/domain/address_form_repository.dart';
import 'package:jeeb_mobile/features/location/domain/saved_location.dart';

/// Captures the outbound request (path/method/body) and replies with a fixed
/// response, so the iter6 D-ADDRESS-SAVE repoint can be asserted without a live
/// gateway. Mirrors the capturing-Dio helper in
/// `dio_saved_location_repository_test.dart`.
String? _capturedPath;
String? _capturedMethod;
Object? _capturedBody;

Dio _capturingDio(Object? responseBody, {int status = 200}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        _capturedPath = options.path;
        _capturedMethod = options.method;
        _capturedBody = options.data;
        handler.resolve(
          Response(
            data: responseBody,
            statusCode: status,
            requestOptions: options,
          ),
        );
      },
    ),
  );
  return dio;
}

Dio _dioThrowing(DioExceptionType type) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.reject(
          DioException(requestOptions: options, type: type),
        );
      },
    ),
  );
  return dio;
}

AddressFormDraft _draft() => const AddressFormDraft(
      label: 'HomeQA',
      latitude: 33.8869,
      longitude: 35.5131,
      category: SavedLocationCategory.home,
      address: 'Sassine Square, Ashrafieh',
      // Extended (non-gateway-DTO) fields — must NOT be sent (A-CALL-2):
      building: 'Sahar Building',
      floorApt: '4th floor, Apt 12',
      deliveryNotes: 'Ring twice; blue door.',
      codPhone: '+96170000001',
      isDefault: true,
    );

void main() {
  group('DioAddressFormRepository — iter6 me-scoped live route', () {
    // iter6 D-ADDRESS-SAVE: the form save must hit the LIVE gateway's
    // `me`-scoped Saved-Locations BFF — NOT the legacy mock path
    // `/users/<id>/saved-locations`, and with NO hardcoded `user-client-001`.
    test('create POSTs /api/users/me/saved-locations (no userId, no mock path)',
        () async {
      _capturedPath = null;
      final repo = DioAddressFormRepository(
        _capturingDio(<String, dynamic>{
          'id': 'addr-1',
          'label': 'HomeQA',
          'latitude': 33.8869,
          'longitude': 35.5131,
          'isDefault': true,
          'address': 'Sassine Square, Ashrafieh',
        }, status: 201),
      );

      final saved = await repo.create(
        // userId is now a test seam only — it must NOT appear in the path.
        userId: 'd1000000-0000-4000-8000-000000000001',
        draft: _draft(),
      );

      expect(_capturedPath, '/api/users/me/saved-locations');
      expect(_capturedMethod, 'POST');
      // No hardcoded mock id, no legacy `/users/<id>/...` path segment.
      expect(_capturedPath, isNot(contains('user-client-001')));
      expect(_capturedPath, isNot(contains('d1000000')));
      expect(_capturedPath, isNot(startsWith('/users/')));

      // Response parses round-trip.
      expect(saved.id, 'addr-1');
      expect(saved.label, 'HomeQA');
      expect(saved.latitude, closeTo(33.8869, 1e-6));
      expect(saved.isDefault, isTrue);
    });

    test('create sends the gateway-required fields with correct values',
        () async {
      // Contract note: the repo intentionally submits the FULL address-detail
      // field set (label/coords/isDefault/address + building/floorApt/
      // deliveryNotes/codPhone) — this body was VERIFIED 201 on the live gateway
      // (:10090, 2026-06-30, see dio_address_form_repository.dart). This test
      // locks the REQUIRED gateway CreateSavedLocationRequest fields are present
      // and correctly valued; whether the live DTO also persists the extended
      // delivery-detail fields is an open product question (see report flag).
      _capturedBody = null;
      final repo = DioAddressFormRepository(
        _capturingDio(<String, dynamic>{'id': 'addr-1', 'label': 'HomeQA'}),
      );

      await repo.create(userId: 'ignored', draft: _draft());

      final body = _capturedBody as Map<String, dynamic>;
      // Required by the live gateway CreateSavedLocationRequest DTO.
      expect(body.keys,
          containsAll(<String>['label', 'latitude', 'longitude', 'isDefault']));
      expect(body['label'], 'HomeQA');
      expect(body['latitude'], closeTo(33.8869, 1e-6));
      expect(body['longitude'], closeTo(35.5131, 1e-6));
      expect(body['address'], 'Sassine Square, Ashrafieh');
      expect(body['isDefault'], isTrue);
    });

    test('update PUTs /api/users/me/saved-locations/<id> (no userId segment)',
        () async {
      _capturedPath = null;
      final repo = DioAddressFormRepository(
        _capturingDio(<String, dynamic>{
          'id': 'addr-9',
          'label': 'HomeQA',
          'latitude': 33.8869,
          'longitude': 35.5131,
        }),
      );

      await repo.update(
        userId: 'ignored',
        id: 'addr-9',
        draft: _draft(),
      );

      expect(_capturedPath, '/api/users/me/saved-locations/addr-9');
      expect(_capturedMethod, 'PUT');
      expect(_capturedPath, isNot(contains('user-client-001')));
    });

    test('maps connection errors to AddressFormFailure.network', () async {
      final repo =
          DioAddressFormRepository(_dioThrowing(DioExceptionType.connectionError));

      expect(
        () => repo.create(userId: 'ignored', draft: _draft()),
        throwsA(
          isA<AddressFormException>().having(
            (e) => e.failure,
            'failure',
            AddressFormFailure.network,
          ),
        ),
      );
    });
  });
}
