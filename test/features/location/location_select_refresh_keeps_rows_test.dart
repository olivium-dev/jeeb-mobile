// R6 "refresh() never flips to loading/failed" — `refresh()` flipped `status`
// to `failed`, blanking a loaded saved-address list; and `load()` returned
// early unless `status == initial`, so after a failure it could never retry.

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/location/application/location_select_cubit.dart';
import 'package:jeeb_mobile/features/location/application/location_select_state.dart';
import 'package:jeeb_mobile/features/location/domain/location_select_repository.dart';
import 'package:jeeb_mobile/features/location/domain/saved_location.dart';

const List<SavedLocation> _rows = <SavedLocation>[
  SavedLocation(
    id: 'addr-1',
    label: 'Home',
    latitude: 33.8869,
    longitude: 35.5131,
    category: SavedLocationCategory.home,
  ),
];

/// Serves [_rows] on the reads in [okCalls]; throws [failure] on the rest.
class _Scripted implements LocationSelectRepository {
  _Scripted({required this.okCalls, this.failure = const ServerFailure(status: 500)});

  final Set<int> okCalls;
  final AppFailure failure;
  int calls = 0;

  @override
  Future<List<SavedLocation>> fetchSavedAddresses(String userId) async {
    calls++;
    if (okCalls.contains(calls)) return _rows;
    throw failure;
  }
}

LocationSelectCubit _cubit(LocationSelectRepository repo) =>
    LocationSelectCubit(repository: repo, userId: 'u1');

void main() {
  group('LocationSelectCubit · refresh keeps the rows', () {
    test('a failed refresh over a LOADED list keeps status and rows', () async {
      final repo = _Scripted(okCalls: <int>{1});
      final cubit = _cubit(repo);

      await cubit.load();
      expect(cubit.state.savedAddresses, _rows);

      await cubit.refresh();

      expect(cubit.state.status, LocationSelectStatus.loaded);
      expect(cubit.state.savedAddresses, _rows);
      expect(cubit.state.refreshError, isA<ServerFailure>());
      await cubit.close();
    });

    test('a failed refresh over an EMPTY list DOES flip to failed', () async {
      final repo = _Scripted(okCalls: const <int>{});
      final cubit = _cubit(repo);

      await cubit.refresh();

      expect(cubit.state.status, LocationSelectStatus.failed);
      expect(cubit.state.appFailure, isA<ServerFailure>());
      await cubit.close();
    });

    test('acknowledgeError clears the warm-failure note, keeping the rows',
        () async {
      final repo = _Scripted(okCalls: <int>{1});
      final cubit = _cubit(repo);

      await cubit.load();
      await cubit.refresh();
      expect(cubit.state.refreshError, isNotNull);

      cubit.acknowledgeError();

      expect(cubit.state.refreshError, isNull);
      expect(cubit.state.savedAddresses, _rows);
      await cubit.close();
    });

    test('a SUCCESSFUL refresh clears a standing note', () async {
      final repo = _Scripted(okCalls: <int>{1, 3});
      final cubit = _cubit(repo);

      await cubit.load();
      await cubit.refresh();
      expect(cubit.state.refreshError, isNotNull);

      await cubit.refresh();

      expect(cubit.state.refreshError, isNull);
      expect(cubit.state.status, LocationSelectStatus.loaded);
      await cubit.close();
    });
  });

  group('LocationSelectCubit · load can retry after a failure', () {
    test('load() after a FAILED status actually refetches', () async {
      final repo = _Scripted(okCalls: <int>{2});
      final cubit = _cubit(repo);

      await cubit.load();
      expect(cubit.state.status, LocationSelectStatus.failed);

      await cubit.load();

      expect(repo.calls, 2);
      expect(cubit.state.status, LocationSelectStatus.loaded);
      expect(cubit.state.savedAddresses, _rows);
      await cubit.close();
    });

    test('the in-flight guard is on `loading`, not on `initial`', () async {
      final repo = _Scripted(okCalls: <int>{1, 2});
      final cubit = _cubit(repo);

      // Two concurrent loads: the second observes `loading` and bails.
      final Future<void> first = cubit.load();
      final Future<void> second = cubit.load();
      await Future.wait(<Future<void>>[first, second]);

      expect(repo.calls, 1);
      await cubit.close();
    });

    test('a cold-load failure carries BOTH the legacy enum and the kind',
        () async {
      final repo = _Scripted(
        okCalls: const <int>{},
        failure: const NetworkFailure(offline: true),
      );
      final cubit = _cubit(repo);

      await cubit.load();

      expect(cubit.state.error, LocationSelectFailure.network);
      expect(cubit.state.appFailure, const NetworkFailure(offline: true));
      await cubit.close();
    });

    test('a 403 is NOT reported as a connectivity failure', () async {
      final repo = _Scripted(
        okCalls: const <int>{},
        failure: const ForbiddenFailure(),
      );
      final cubit = _cubit(repo);

      await cubit.load();

      expect(cubit.state.error, LocationSelectFailure.unknown);
      expect(cubit.state.appFailure, isA<ForbiddenFailure>());
      await cubit.close();
    });
  });
}
