// JM-024 — location-select data wiring (LocationSelectCubit +
// DioLocationSelectRepository). Pins (a) the cubit lifecycle (load → loaded /
// failed, selection transitions), and (b) the Dio repo parsing the
// journey-honest `GET /users/:userId/saved-locations` shape — including the
// seeded nested `geo:{lat,lng}` form (42_GUARDRAILS_MOCK §4 / `has_saved_addresses`).
//
// Dio is mocked with the repo-standard `InterceptorsWrapper` resolve/reject
// pattern (see dio_saved_location_repository_test.dart) — no extra dependency.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/location/application/location_select_cubit.dart';
import 'package:jeeb_mobile/features/location/application/location_select_state.dart';
import 'package:jeeb_mobile/features/location/data/dio_location_select_repository.dart';
import 'package:jeeb_mobile/features/location/data/fake_location_select_repository.dart';
import 'package:jeeb_mobile/features/location/domain/location_select_repository.dart';
import 'package:jeeb_mobile/features/location/domain/saved_location.dart';

String? _capturedPath;

Dio _dioReplying(Object? body, {int status = 200}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        _capturedPath = options.path;
        handler.resolve(
          Response(data: body, statusCode: status, requestOptions: options),
        );
      },
    ),
  );
  return dio;
}

Dio _dioThrowing(DioException error) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.reject(error),
    ),
  );
  return dio;
}

void main() {
  group('LocationSelectCubit', () {
    test('load() → loaded with the saved addresses', () async {
      final cubit = LocationSelectCubit(
        repository: const FakeLocationSelectRepository(),
        userId: 'user-client-001',
      );
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.status, LocationSelectStatus.loaded);
      expect(cubit.state.hasSavedAddresses, isTrue);
      expect(cubit.state.savedAddresses.length, 2);
      // Default selection is "Current Location" so Confirm is reachable.
      expect(cubit.state.choiceKind, LocationChoiceKind.current);
      expect(cubit.state.canConfirm, isTrue);
    });

    test('load() → failed surfaces the typed failure', () async {
      final cubit = LocationSelectCubit(
        repository: const FakeLocationSelectRepository(
          failWith: LocationSelectFailure.network,
        ),
        userId: 'user-client-001',
      );
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.status, LocationSelectStatus.failed);
      expect(cubit.state.error, LocationSelectFailure.network);
      // P0 REGRESSION (order-create blocker): a failed saved-addresses fetch
      // must NOT block confirming Current Location (the default choice). The
      // live gateway 404s `GET /users/:id/saved-locations` for a customer with
      // no saved addresses; gating Confirm on `loaded` dead-ended order
      // creation (tier → location → Confirm disabled). Current/pinned stay
      // confirmable on `failed`; only an explicit saved choice does not.
      expect(cubit.state.choiceKind, LocationChoiceKind.current);
      expect(
        cubit.state.canConfirm,
        isTrue,
        reason: 'Current Location must remain confirmable after a 404/save-load '
            'failure (JM-024 AC4)',
      );
    });

    test('failed + explicitly-selected saved address is NOT confirmable',
        () async {
      // Guard the other half of the fix: if the user had picked a saved address
      // (which by definition could not have loaded on a failed fetch), Confirm
      // must stay disabled rather than forward a phantom selection.
      final cubit = LocationSelectCubit(
        repository: const FakeLocationSelectRepository(
          failWith: LocationSelectFailure.network,
        ),
        userId: 'user-client-001',
      );
      addTearDown(cubit.close);

      await cubit.load();
      cubit.selectSaved('addr-client-001-home');

      expect(cubit.state.status, LocationSelectStatus.failed);
      expect(cubit.state.choiceKind, LocationChoiceKind.saved);
      expect(cubit.state.canConfirm, isFalse);
    });

    test('selectSaved / selectCurrent / markPinned toggle the choice',
        () async {
      final cubit = LocationSelectCubit(
        repository: const FakeLocationSelectRepository(),
        userId: 'user-client-001',
      );
      addTearDown(cubit.close);
      await cubit.load();

      cubit.selectSaved('addr-client-001-home');
      expect(cubit.state.choiceKind, LocationChoiceKind.saved);
      expect(cubit.state.isSavedSelected('addr-client-001-home'), isTrue);

      cubit.markPinned();
      expect(cubit.state.choiceKind, LocationChoiceKind.pinned);
      expect(cubit.state.selectedSavedId, isNull);

      cubit.selectCurrent();
      expect(cubit.state.choiceKind, LocationChoiceKind.current);
    });

    test('load() is re-entry guarded', () async {
      final cubit = LocationSelectCubit(
        repository: const FakeLocationSelectRepository(),
        userId: 'user-client-001',
      );
      addTearDown(cubit.close);
      await cubit.load();
      final snapshot = cubit.state;
      await cubit.load(); // no-op (status != initial)
      expect(cubit.state, snapshot);
    });
  });

  group('DioLocationSelectRepository', () {
    test('uses the gateway path /users/:userId/saved-locations', () async {
      _capturedPath = null;
      final repo = DioLocationSelectRepository(_dioReplying(<dynamic>[]));
      await repo.fetchSavedAddresses('user-client-001');
      // Rewrites to /user-management/users/... via MockGatewayClient at runtime.
      expect(_capturedPath, '/users/user-client-001/saved-locations');
    });

    test('parses the seeded { items: [...] } with nested geo:{lat,lng}',
        () async {
      final repo = DioLocationSelectRepository(_dioReplying({
        'items': [
          {
            'id': 'addr-client-001-home',
            'label': 'Home',
            'isDefault': true,
            'address': 'Sassine Square, Ashrafieh',
            'geo': {'lat': 33.8886, 'lng': 35.4955},
          },
          {
            'id': 'addr-client-001-office',
            'label': 'Office',
            'address': 'Beirut Tower',
            'geo': {'lat': 33.8938, 'lng': 35.5018},
          },
        ],
      }));

      final result = await repo.fetchSavedAddresses('user-client-001');

      expect(result, hasLength(2));
      final home = result.first;
      expect(home.id, 'addr-client-001-home');
      expect(home.label, 'Home');
      expect(home.latitude, closeTo(33.8886, 1e-6));
      expect(home.longitude, closeTo(35.4955, 1e-6));
      expect(home.address, 'Sassine Square, Ashrafieh');
      // Category inferred from the label hint (no `category` field seeded).
      expect(home.category, SavedLocationCategory.home);
      expect(result[1].category, SavedLocationCategory.work);
    });

    test('tolerates a bare list and top-level latitude/longitude', () async {
      final repo = DioLocationSelectRepository(_dioReplying(<dynamic>[
        {'id': 'a1', 'label': 'Place', 'latitude': 1.0, 'longitude': 2.0},
      ]));
      final result = await repo.fetchSavedAddresses('u');
      expect(result, hasLength(1));
      expect(result.first.latitude, 1.0);
      expect(result.first.longitude, 2.0);
    });

    test('maps a transport failure to LocationSelectException.network',
        () async {
      final repo = DioLocationSelectRepository(
        _dioThrowing(DioException.connectionError(
          requestOptions: RequestOptions(path: '/users/u/saved-locations'),
          reason: 'offline',
        )),
      );
      expect(
        () => repo.fetchSavedAddresses('u'),
        throwsA(isA<LocationSelectException>().having(
          (e) => e.failure,
          'failure',
          LocationSelectFailure.network,
        )),
      );
    });

    test('degrades a malformed body to an empty list', () async {
      final repo =
          DioLocationSelectRepository(_dioReplying({'unexpected': true}));
      expect(await repo.fetchSavedAddresses('u'), isEmpty);
    });
  });
}
