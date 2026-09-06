// JM-024 — location-select data wiring (LocationSelectCubit +

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/location/application/location_select_cubit.dart';
import 'package:jeeb_mobile/features/location/application/location_select_state.dart';
import 'package:jeeb_mobile/features/location/data/dio_location_select_repository.dart';
import 'package:jeeb_mobile/features/location/data/fake_location_select_repository.dart';
import 'package:jeeb_mobile/features/location/domain/current_location_resolver.dart';
import 'package:jeeb_mobile/features/location/domain/location_select_repository.dart';
import 'package:jeeb_mobile/features/location/domain/saved_location.dart';

import '../../support/fake_current_location_resolver.dart';

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
    // JEBV4-176 (Q-060): the default fake resolves a REAL (non-Beirut) fix, so
    LocationSelectCubit buildCubit({
      LocationSelectRepository repository = const FakeLocationSelectRepository(),
      CurrentLocationResult gps = const CurrentLocationResult.resolved(
        33.8959,
        35.4797,
      ),
    }) =>
        LocationSelectCubit(
          repository: repository,
          userId: 'user-client-001',
          currentLocationResolver: FakeCurrentLocationResolver(result: gps),
        );

    test('load() → loaded + resolves a REAL current-GPS fix', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.status, LocationSelectStatus.loaded);
      expect(cubit.state.hasSavedAddresses, isTrue);
      expect(cubit.state.savedAddresses.length, 2);
      expect(cubit.state.choiceKind, LocationChoiceKind.current);
      // Confirm is reachable ONLY because a real fix resolved (not Beirut).
      expect(cubit.state.currentGpsStatus, CurrentGpsStatus.resolved);
      expect(cubit.state.gpsLat, 33.8959);
      expect(cubit.state.gpsLng, 35.4797);
      expect(cubit.state.canConfirm, isTrue);
    });

    test('load() → failed saved-fetch still resolves current GPS + confirmable',
        () async {
      final cubit = buildCubit(
        repository: const FakeLocationSelectRepository(
          failWith: LocationSelectFailure.network,
        ),
      );
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.status, LocationSelectStatus.failed);
      expect(cubit.state.error, LocationSelectFailure.network);
      // A failed saved-addresses fetch (offline / 5xx) must NOT block the flow:
      expect(cubit.state.choiceKind, LocationChoiceKind.current);
      expect(cubit.state.hasCurrentGps, isTrue);
      expect(cubit.state.canConfirm, isTrue,
          reason: 'a resolved current GPS fix stays confirmable after a saved-'
              'load failure');
    });

    // D1 (screen 09): the OS reports a horizontal accuracy radius on every fix
    // and it used to be dropped at the resolver boundary. It now threads
    // resolver → state so the address card can say HOW precise the pin is.
    test('accuracy radius threads resolver → state, and clearGps nulls it',
        () async {
      final cubit = buildCubit(
        gps: const CurrentLocationResult.resolved(
          33.8959,
          35.4797,
          accuracyMeters: 8,
        ),
      );
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.currentGpsStatus, CurrentGpsStatus.resolved);
      expect(cubit.state.gpsAccuracyMeters, 8);

      // `clearGps` drops the radius with the coordinate — a stale accuracy on
      // a cleared fix would claim precision the app no longer has.
      final cleared = cubit.state.copyWith(clearGps: true);
      expect(cleared.gpsLat, isNull);
      expect(cleared.gpsLng, isNull);
      expect(cleared.gpsAccuracyMeters, isNull);
    });

    test('a fix with no accuracy radius leaves the field null', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.currentGpsStatus, CurrentGpsStatus.resolved);
      expect(cubit.state.gpsAccuracyMeters, isNull);
    });

    test(
        'current option is NOT confirmable until a real fix resolves '
        '(permission denied → recovery, no Beirut)', () async {
      final cubit = buildCubit(
        gps: const CurrentLocationResult.permissionDenied(),
      );
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.choiceKind, LocationChoiceKind.current);
      expect(
          cubit.state.currentGpsStatus, CurrentGpsStatus.permissionDenied);
      expect(cubit.state.gpsLat, isNull);
      expect(cubit.state.gpsLng, isNull);
      // The old silent Beirut fallback made this `true`; now Confirm is gated.
      expect(cubit.state.canConfirm, isFalse);
    });

    test('services-off and failed map to their recovery states', () async {
      final off = buildCubit(
        gps: const CurrentLocationResult.serviceDisabled(),
      );
      addTearDown(off.close);
      await off.load();
      expect(off.state.currentGpsStatus, CurrentGpsStatus.serviceDisabled);
      expect(off.state.canConfirm, isFalse);

      final failed = buildCubit(gps: const CurrentLocationResult.failed());
      addTearDown(failed.close);
      await failed.load();
      expect(failed.state.currentGpsStatus, CurrentGpsStatus.failed);
      expect(failed.state.canConfirm, isFalse);
    });

    test('retry (resolveCurrentGps) re-attempts the fix', () async {
      final resolver = FakeCurrentLocationResolver(
        result: const CurrentLocationResult.serviceDisabled(),
      );
      final cubit = LocationSelectCubit(
        repository: const FakeLocationSelectRepository(),
        userId: 'user-client-001',
        currentLocationResolver: resolver,
      );
      addTearDown(cubit.close);
      await cubit.load();
      expect(resolver.resolveCount, 1);

      await cubit.resolveCurrentGps();
      expect(resolver.resolveCount, 2);
    });

    test('failed + explicitly-selected saved address is NOT confirmable',
        () async {
      final cubit = buildCubit(
        repository: const FakeLocationSelectRepository(
          failWith: LocationSelectFailure.network,
        ),
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
      final cubit = buildCubit();
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
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.load();
      final snapshot = cubit.state;
      await cubit.load(); // no-op (status != initial)
      expect(cubit.state, snapshot);
    });
  });

  group('DioLocationSelectRepository', () {
    test('uses the live /api/users/me/saved-locations contract', () async {
      _capturedPath = null;
      final repo = DioLocationSelectRepository(_dioReplying(<dynamic>[]));
      await repo.fetchSavedAddresses('user-client-001');
      // useMockPrefixes is false under `flutter test`, so the helper emits the
      expect(_capturedPath, '/api/users/me/saved-locations');
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

    test('maps a transport failure to a NetworkFailure', () async {
      final repo = DioLocationSelectRepository(
        _dioThrowing(DioException.connectionError(
          requestOptions: RequestOptions(path: '/api/users/me/saved-locations'),
          reason: 'offline',
        )),
      );
      expect(
        () => repo.fetchSavedAddresses('u'),
        throwsA(isA<NetworkFailure>()),
      );
    });

    // A body we cannot read is NOT "this customer has no saved addresses":
    // swallowing it to `const []` renders the empty state over a failed read.
    test('throws UnknownFailure(parse) on a malformed body', () async {
      final repo =
          DioLocationSelectRepository(_dioReplying({'unexpected': true}));
      expect(
        () => repo.fetchSavedAddresses('u'),
        throwsA(predicate<UnknownFailure>((UnknownFailure f) => f.parse)),
      );
    });
  });
}
