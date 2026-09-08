import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/location/domain/saved_location.dart';
import 'package:jeeb_mobile/features/location/domain/saved_location_repository.dart';
import 'package:jeeb_mobile/features/location/presentation/cubit/saved_locations_cubit.dart';
import 'package:jeeb_mobile/features/location/presentation/cubit/saved_locations_state.dart';

/// Test seam — scriptable saved location responses.
class _FakeRepo implements SavedLocationRepository {
  _FakeRepo({
    this.list = const [],
    this.capError = false,
    this.failDelete = false,
  });

  final List<SavedLocation> list;
  final bool capError;
  final bool failDelete;

  int fetchCalls = 0;

  @override
  Future<List<SavedLocation>> fetchSavedLocations() async {
    fetchCalls++;
    return list;
  }

  @override
  Future<SavedLocation> saveLocation({
    required double latitude,
    required double longitude,
    required String label,
    required SavedLocationCategory category,
    String? address,
  }) async {
    if (capError) throw const SavedLocationCapReachedException();
    return SavedLocation(
      id: 'new-${label.toLowerCase()}',
      label: label,
      latitude: latitude,
      longitude: longitude,
      category: category,
      address: address,
    );
  }

  @override
  Future<SavedLocation> updateLocation({
    required String id,
    required double latitude,
    required double longitude,
    required String label,
    required SavedLocationCategory category,
    String? address,
  }) async {
    return SavedLocation(
      id: id,
      label: label,
      latitude: latitude,
      longitude: longitude,
      category: category,
      address: address,
    );
  }

  @override
  Future<void> deleteLocation(String id) async {
    if (failDelete) throw const SavedLocationException('delete failed');
  }
}

/// Serves once, then fails — the warm-failure path.
class _FlakyAfterFirstRepo extends _FakeRepo {
  _FlakyAfterFirstRepo({super.list});

  @override
  Future<List<SavedLocation>> fetchSavedLocations() async {
    fetchCalls++;
    if (fetchCalls == 1) return list;
    throw const ServerFailure(status: 500);
  }
}

/// Serves the list, but every delete throws.
class _DeleteFailsRepo extends _FakeRepo {
  _DeleteFailsRepo({super.list});

  @override
  Future<void> deleteLocation(String id) async =>
      throw const ServerFailure(status: 500);
}

class _FailingRepo implements SavedLocationRepository {
  @override
  Future<List<SavedLocation>> fetchSavedLocations() async {
    throw Exception('network error');
  }

  @override
  Future<SavedLocation> saveLocation({
    required double latitude,
    required double longitude,
    required String label,
    required SavedLocationCategory category,
    String? address,
  }) async {
    throw Exception('network error');
  }

  @override
  Future<SavedLocation> updateLocation({
    required String id,
    required double latitude,
    required double longitude,
    required String label,
    required SavedLocationCategory category,
    String? address,
  }) async {
    throw Exception('network error');
  }

  @override
  Future<void> deleteLocation(String id) async {
    throw Exception('network error');
  }
}

const _home = SavedLocation(
  id: 'loc-home',
  label: 'Home',
  latitude: 33.89,
  longitude: 35.50,
  category: SavedLocationCategory.home,
  address: '123 Main St',
);

const _work = SavedLocation(
  id: 'loc-work',
  label: 'Office',
  latitude: 33.90,
  longitude: 35.51,
  category: SavedLocationCategory.work,
);

void main() {
  group('SavedLocationsCubit — T-MOB-025', () {
    test('starts in Loading', () {
      final cubit = SavedLocationsCubit(_FakeRepo());
      expect(cubit.state, isA<SavedLocationsLoading>());
    });

    test('AC1: load emits Loaded with 2 locations', () async {
      final cubit = SavedLocationsCubit(
        _FakeRepo(list: [_home, _work]),
      );
      await cubit.load();
      expect(cubit.state, isA<SavedLocationsLoaded>());
      final state = cubit.state as SavedLocationsLoaded;
      expect(state.locations, hasLength(2));
      expect(state.locations.first.label, 'Home');
    });

    test('load emits Error carrying the classified failure', () async {
      final cubit = SavedLocationsCubit(_FailingRepo());
      await cubit.load();
      expect(cubit.state, isA<SavedLocationsError>());
      // F32: `SavedLocationsError('fetch_failed')` was a stringly code the
      // screen could only render as one kind-blind sentence.
      expect((cubit.state as SavedLocationsError).failure, isA<AppFailure>());
    });

    // R6: a refresh must never blank rows already on screen.
    test('a failed REFRESH keeps the rows and rides a refreshError', () async {
      final repo = _FlakyAfterFirstRepo(list: [_home, _work]);
      final cubit = SavedLocationsCubit(repo);

      await cubit.load();
      await cubit.load();

      expect(cubit.state, isA<SavedLocationsLoaded>());
      final state = cubit.state as SavedLocationsLoaded;
      expect(state.locations, hasLength(2));
      expect(state.refreshError, isA<AppFailure>());
    });

    test('a COLD load failure still shows the error page', () async {
      final cubit = SavedLocationsCubit(_FailingRepo());
      await cubit.load();
      expect(cubit.state, isA<SavedLocationsError>());
    });

    test('the in-flight guard drops a concurrent load', () async {
      final repo = _FakeRepo(list: [_home]);
      final cubit = SavedLocationsCubit(repo);

      await Future.wait(<Future<void>>[cubit.load(), cubit.load()]);

      expect(repo.fetchCalls, 1);
    });

    // F32: the three stringly mutation codes are an enum now.
    test('a failed delete names the mutation', () async {
      final cubit = SavedLocationsCubit(_DeleteFailsRepo(list: [_home]));
      await cubit.load();
      await cubit.delete(_home.id);

      final state = cubit.state as SavedLocationsMutationError;
      expect(state.mutation, SavedLocationsMutation.delete);
      expect(state.failure, isA<AppFailure>());
      expect(state.isCapError, isFalse);
    });

    test('AC2: create prepends new location', () async {
      final cubit = SavedLocationsCubit(_FakeRepo(list: [_home]));
      await cubit.load();
      await cubit.create(
        latitude: 33.95,
        longitude: 35.55,
        label: 'Gym',
        category: SavedLocationCategory.other,
      );
      expect(cubit.state, isA<SavedLocationsLoaded>());
      final state = cubit.state as SavedLocationsLoaded;
      // AC2: newly created item at top
      expect(state.locations.first.label, 'Gym');
    });

    test('AC3: create emits MutationError with isCapError when cap hit', () async {
      final cubit = SavedLocationsCubit(
        _FakeRepo(list: [_home, _work], capError: true),
      );
      await cubit.load();
      await cubit.create(
        latitude: 0,
        longitude: 0,
        label: 'Extra',
        category: SavedLocationCategory.other,
      );
      expect(cubit.state, isA<SavedLocationsMutationError>());
      final state = cubit.state as SavedLocationsMutationError;
      expect(state.isCapError, isTrue);
    });

    test('delete removes item from list', () async {
      final cubit = SavedLocationsCubit(
        _FakeRepo(list: [_home, _work]),
      );
      await cubit.load();
      await cubit.delete(_home.id);
      expect(cubit.state, isA<SavedLocationsLoaded>());
      final state = cubit.state as SavedLocationsLoaded;
      expect(state.locations, hasLength(1));
      expect(state.locations.first.id, _work.id);
    });

    test('delete emits MutationError on failure', () async {
      final cubit = SavedLocationsCubit(
        _FakeRepo(list: [_home], failDelete: true),
      );
      await cubit.load();
      await cubit.delete(_home.id);
      expect(cubit.state, isA<SavedLocationsMutationError>());
    });

    test('acknowledgeError returns to Loaded', () async {
      final cubit = SavedLocationsCubit(
        _FakeRepo(list: [_home], capError: true),
      );
      await cubit.load();
      await cubit.create(
        latitude: 0,
        longitude: 0,
        label: 'x',
        category: SavedLocationCategory.other,
      );
      expect(cubit.state, isA<SavedLocationsMutationError>());
      cubit.acknowledgeError();
      expect(cubit.state, isA<SavedLocationsLoaded>());
    });

    test('update replaces location in list', () async {
      final cubit = SavedLocationsCubit(
        _FakeRepo(list: [_home, _work]),
      );
      await cubit.load();
      await cubit.update(
        id: _home.id,
        latitude: 34.0,
        longitude: 36.0,
        label: 'Home Updated',
        category: SavedLocationCategory.home,
      );
      expect(cubit.state, isA<SavedLocationsLoaded>());
      final state = cubit.state as SavedLocationsLoaded;
      expect(state.locations.first.label, 'Home Updated');
    });
  });
}
