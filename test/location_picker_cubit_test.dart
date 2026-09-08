import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/location/cubit/location_picker_cubit.dart';
import 'package:jeeb_mobile/features/location/cubit/location_picker_state.dart';
import 'package:jeeb_mobile/features/location/data/location_repository.dart';

class _MockRepository extends Mock implements LocationRepository {}

class _FakePoint extends Fake implements LocationPoint {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePoint());
  });

  late _MockRepository repo;

  setUp(() {
    repo = _MockRepository();
  });

  LocationPickerCubit build() => LocationPickerCubit(
        repository: repo,
        // Zero-debounce so search assertions don't need fakeAsync plumbing.
        searchDebounce: Duration.zero,
      );

  const beirut = LocationPoint(
    latitude: 33.8938,
    longitude: 35.5018,
    address: 'Downtown, Beirut',
  );
  const hamra = LocationPoint(
    latitude: 33.8889,
    longitude: 35.4955,
    address: 'Hamra, Beirut',
  );

  group('detectCurrentLocation', () {
    blocTest<LocationPickerCubit, LocationPickerState>(
      'populates the draft with the resolved GPS point',
      build: build,
      setUp: () => when(() => repo.resolveCurrentGps())
          .thenAnswer((_) async => beirut),
      act: (c) => c.detectCurrentLocation(),
      expect: () => [
        predicate<LocationPickerState>((s) => s.isLocatingGps && s.error == null),
        predicate<LocationPickerState>(
          (s) => !s.isLocatingGps && s.draftSelection == beirut,
        ),
      ],
    );

    blocTest<LocationPickerCubit, LocationPickerState>(
      'maps a permission failure into a one-shot error',
      build: build,
      setUp: () => when(() => repo.resolveCurrentGps()).thenThrow(
        const LocationFailure(LocationFailureKind.gpsPermissionDenied),
      ),
      act: (c) => c.detectCurrentLocation(),
      expect: () => [
        predicate<LocationPickerState>((s) => s.isLocatingGps),
        predicate<LocationPickerState>(
          (s) =>
              !s.isLocatingGps &&
              s.error == LocationPickerError.gpsPermissionDenied,
        ),
      ],
    );

    // R6 connectivity honesty: a NETWORK failure is not a GPS failure.
    blocTest<LocationPickerCubit, LocationPickerState>(
      'a network failure is networkUnavailable, never gpsUnavailable',
      build: () => LocationPickerCubit(repository: repo),
      setUp: () => when(() => repo.resolveCurrentGps())
          .thenThrow(const NetworkFailure(offline: true)),
      act: (c) => c.detectCurrentLocation(),
      skip: 1,
      expect: () => [
        predicate<LocationPickerState>(
          (s) =>
              s.error == LocationPickerError.networkUnavailable &&
              s.appFailure is NetworkFailure,
        ),
      ],
    );

    // F45: the enum code alone could not tell a 403 from a dead sensor.
    blocTest<LocationPickerCubit, LocationPickerState>(
      'a non-network failure keeps gpsUnavailable AND carries the kind',
      build: () => LocationPickerCubit(repository: repo),
      setUp: () => when(() => repo.resolveCurrentGps())
          .thenThrow(const ServerFailure(status: 500)),
      act: (c) => c.detectCurrentLocation(),
      skip: 1,
      expect: () => [
        predicate<LocationPickerState>(
          (s) =>
              s.error == LocationPickerError.gpsUnavailable &&
              s.appFailure is ServerFailure,
        ),
      ],
    );
  });

  group('searchAddress', () {
    blocTest<LocationPickerCubit, LocationPickerState>(
      'clears results immediately on empty query',
      build: build,
      seed: () => const LocationPickerState(
        searchQuery: 'foo',
        searchResults: [hamra],
      ),
      act: (c) => c.searchAddress(''),
      expect: () => [
        predicate<LocationPickerState>(
          (s) => s.searchQuery == '' && s.error == null,
        ),
        predicate<LocationPickerState>(
          (s) => s.searchResults.isEmpty && !s.isSearching,
        ),
      ],
    );

    blocTest<LocationPickerCubit, LocationPickerState>(
      'debounced lookup emits results',
      build: build,
      setUp: () => when(() => repo.searchAddress('hamra'))
          .thenAnswer((_) async => const [hamra]),
      act: (c) async {
        c.searchAddress('hamra');
        // Zero-debounce; wait one microtask for the timer to fire.
        await Future<void>.delayed(const Duration(milliseconds: 1));
      },
      expect: () => [
        predicate<LocationPickerState>((s) => s.searchQuery == 'hamra'),
        predicate<LocationPickerState>((s) => s.isSearching),
        predicate<LocationPickerState>(
          (s) => !s.isSearching && s.searchResults.contains(hamra),
        ),
      ],
    );

    blocTest<LocationPickerCubit, LocationPickerState>(
      'surfaces a search-failed error on repository throw',
      build: build,
      setUp: () => when(() => repo.searchAddress(any())).thenThrow(Exception('boom')),
      act: (c) async {
        c.searchAddress('hamra');
        await Future<void>.delayed(const Duration(milliseconds: 1));
      },
      skip: 2,
      expect: () => [
        predicate<LocationPickerState>(
          (s) =>
              !s.isSearching &&
              s.error == LocationPickerError.searchFailed &&
              s.appFailure != null,
        ),
      ],
    );
  });

  group('selectSearchResult', () {
    blocTest<LocationPickerCubit, LocationPickerState>(
      'commits the picked suggestion and clears the dropdown',
      build: build,
      seed: () => const LocationPickerState(
        searchQuery: 'ham',
        searchResults: [hamra, beirut],
      ),
      act: (c) => c.selectSearchResult(hamra),
      expect: () => [
        predicate<LocationPickerState>(
          (s) =>
              s.draftSelection == hamra &&
              s.searchResults.isEmpty &&
              s.searchQuery == hamra.address,
        ),
      ],
    );
  });

  group('onPinDragged', () {
    blocTest<LocationPickerCubit, LocationPickerState>(
      'updates draft eagerly and reverse-geocodes in the background',
      build: build,
      setUp: () => when(
        () => repo.reverseGeocode(
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
        ),
      ).thenAnswer((_) async => 'Resolved address'),
      act: (c) async {
        c.onPinDragged(latitude: 33.5, longitude: 35.5);
        // Let the unawaited reverse-geocode complete.
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [
        predicate<LocationPickerState>(
          (s) =>
              s.draftSelection?.latitude == 33.5 &&
              s.draftSelection?.longitude == 35.5 &&
              s.draftSelection?.address == null &&
              s.isResolvingAddress,
        ),
        predicate<LocationPickerState>(
          (s) =>
              !s.isResolvingAddress &&
              s.draftSelection?.address == 'Resolved address',
        ),
      ],
    );
  });

  group('confirmAndContinue', () {
    blocTest<LocationPickerCubit, LocationPickerState>(
      'advances from pickup to dropoff and seeds the draft',
      build: build,
      seed: () => const LocationPickerState(draftSelection: beirut),
      act: (c) => c.confirmAndContinue(),
      expect: () => [
        predicate<LocationPickerState>(
          (s) =>
              s.step == LocationPickerStep.dropoff &&
              s.pickup == beirut &&
              s.draftSelection == beirut,
        ),
      ],
    );

    blocTest<LocationPickerCubit, LocationPickerState>(
      'saves the pair on dropoff confirm and lands on done',
      build: build,
      setUp: () => when(
        () => repo.saveDeliveryLocations(
          pickup: any(named: 'pickup'),
          dropoff: any(named: 'dropoff'),
        ),
      ).thenAnswer(
        (_) async => const DeliveryLocations(pickup: beirut, dropoff: hamra),
      ),
      seed: () => const LocationPickerState(
        step: LocationPickerStep.dropoff,
        pickup: beirut,
        draftSelection: hamra,
      ),
      act: (c) => c.confirmAndContinue(),
      expect: () => [
        predicate<LocationPickerState>((s) => s.isSaving),
        predicate<LocationPickerState>(
          (s) =>
              !s.isSaving &&
              s.step == LocationPickerStep.done &&
              s.pickup == beirut &&
              s.dropoff == hamra &&
              s.isComplete,
        ),
      ],
    );

    blocTest<LocationPickerCubit, LocationPickerState>(
      'surfaces a save-failed error and keeps the user on dropoff',
      build: build,
      setUp: () => when(
        () => repo.saveDeliveryLocations(
          pickup: any(named: 'pickup'),
          dropoff: any(named: 'dropoff'),
        ),
      ).thenThrow(Exception('network')),
      seed: () => const LocationPickerState(
        step: LocationPickerStep.dropoff,
        pickup: beirut,
        draftSelection: hamra,
      ),
      act: (c) => c.confirmAndContinue(),
      expect: () => [
        predicate<LocationPickerState>((s) => s.isSaving),
        predicate<LocationPickerState>(
          (s) =>
              !s.isSaving &&
              s.error == LocationPickerError.saveFailed &&
              s.appFailure != null &&
              s.step == LocationPickerStep.dropoff,
        ),
      ],
    );
  });

  group('goBack', () {
    blocTest<LocationPickerCubit, LocationPickerState>(
      'rewinds from dropoff to pickup with the prior pickup as draft',
      build: build,
      seed: () => const LocationPickerState(
        step: LocationPickerStep.dropoff,
        pickup: beirut,
        draftSelection: hamra,
      ),
      act: (c) => c.goBack(),
      expect: () => [
        predicate<LocationPickerState>(
          (s) =>
              s.step == LocationPickerStep.pickup &&
              s.draftSelection == beirut &&
              s.searchResults.isEmpty,
        ),
      ],
    );

    blocTest<LocationPickerCubit, LocationPickerState>(
      'is a no-op on the pickup step',
      build: build,
      seed: () => const LocationPickerState(draftSelection: beirut),
      act: (c) => c.goBack(),
      expect: () => const <LocationPickerState>[],
    );
  });

  group('rehydrate', () {
    blocTest<LocationPickerCubit, LocationPickerState>(
      'lands the user on done when both locations are already saved',
      build: build,
      setUp: () => when(() => repo.loadSavedLocations()).thenAnswer(
        (_) async => const DeliveryLocations(pickup: beirut, dropoff: hamra),
      ),
      act: (c) => c.rehydrate(),
      expect: () => [
        predicate<LocationPickerState>(
          (s) =>
              s.step == LocationPickerStep.done &&
              s.pickup == beirut &&
              s.dropoff == hamra,
        ),
      ],
    );

    blocTest<LocationPickerCubit, LocationPickerState>(
      'is a no-op when nothing has been saved',
      build: build,
      setUp: () =>
          when(() => repo.loadSavedLocations()).thenAnswer((_) async => null),
      act: (c) => c.rehydrate(),
      expect: () => const <LocationPickerState>[],
    );
  });

  group('InMemoryLocationRepository', () {
    test('search filters the catalogue case-insensitively', () async {
      final memRepo = InMemoryLocationRepository();
      final results = await memRepo.searchAddress('HAMRA');
      expect(results.any((p) => (p.address ?? '').contains('Hamra')), isTrue);
      expect(await memRepo.searchAddress(''), isEmpty);
    });

    test('round-trips saveDeliveryLocations through loadSavedLocations', () async {
      final memRepo = InMemoryLocationRepository();
      final saved = await memRepo.saveDeliveryLocations(
        pickup: beirut,
        dropoff: hamra,
      );
      expect(saved, const DeliveryLocations(pickup: beirut, dropoff: hamra));
      expect(await memRepo.loadSavedLocations(), saved);
    });

    test('reverseGeocode returns the nearest catalogue address', () async {
      final memRepo = InMemoryLocationRepository();
      final address = await memRepo.reverseGeocode(
        latitude: hamra.latitude + 0.0001,
        longitude: hamra.longitude + 0.0001,
      );
      expect(address, contains('Hamra'));
    });
  });
}
