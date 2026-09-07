import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_state.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';
import 'package:jeeb_mobile/features/home_client/domain/recent_delivery_summary.dart';

class _MockRepo extends Mock implements ClientHomeRepository {}

class _Boom implements Exception {
  const _Boom();
}

ClientHomeRequest _req(String id, ClientRequestStatus s, {int? eta}) {
  return ClientHomeRequest(
    id: id,
    title: 'Pharmacy → Ashrafieh',
    destinationLabel: 'Ashrafieh, Beirut',
    status: s,
    etaMinutes: eta,
  );
}

RecentDeliverySummary _recent(String id) {
  return RecentDeliverySummary(
    id: id,
    title: 'Mini-market run',
    destinationLabel: 'Hamra, Beirut',
    completedAt: DateTime.utc(2026, 5, 16, 10, 30),
  );
}

void main() {
  late _MockRepo repo;
  String? greeting;

  setUp(() {
    repo = _MockRepo();
    greeting = null;
  });

  ClientHomeCubit build({String? name}) {
    greeting = name;
    return ClientHomeCubit(
      repository: repo,
      greetingNameProvider: () => greeting,
    );
  }

  group('load', () {
    blocTest<ClientHomeCubit, ClientHomeState>(
      'emits loading then ready with the snapshot',
      build: () => build(name: 'Layla'),
      setUp: () => when(() => repo.loadSnapshot()).thenAnswer(
        (_) async => ClientHomeSnapshot(
          inProgress: [_req('r-1', ClientRequestStatus.searching)],
          recentDeliveries: [_recent('o-1')],
        ),
      ),
      act: (c) => c.load(),
      expect: () => [
        predicate<ClientHomeState>(
          (s) =>
              s.status == ClientHomeStatus.loading &&
              s.greetingName == 'Layla',
        ),
        predicate<ClientHomeState>(
          (s) =>
              s.status == ClientHomeStatus.ready &&
              s.activeRequests.length == 1 &&
              s.recentDeliveries.length == 1 &&
              s.greetingName == 'Layla',
        ),
      ],
    );

    blocTest<ClientHomeCubit, ClientHomeState>(
      'caps recent deliveries to 1 even if repo returns many',
      build: () => build(),
      setUp: () => when(() => repo.loadSnapshot()).thenAnswer(
        (_) async => ClientHomeSnapshot(
          recentDeliveries: [
            _recent('o-1'),
            _recent('o-2'),
            _recent('o-3'),
          ],
        ),
      ),
      act: (c) => c.load(),
      skip: 1, // ignore loading frame
      expect: () => [
        predicate<ClientHomeState>(
          (s) =>
              s.status == ClientHomeStatus.ready &&
              s.recentDeliveries.length == 1 &&
              s.recentDeliveries.first.id == 'o-1',
        ),
      ],
    );

    blocTest<ClientHomeCubit, ClientHomeState>(
      'surfaces failed when the repository throws',
      build: () => build(),
      setUp: () =>
          when(() => repo.loadSnapshot()).thenThrow(const _Boom()),
      act: (c) => c.load(),
      skip: 1, // ignore loading frame
      expect: () => [
        predicate<ClientHomeState>(
          (s) => s.status == ClientHomeStatus.failed,
        ),
      ],
    );

    test('isEmpty reflects an empty active list after a successful load',
        () async {
      when(() => repo.loadSnapshot()).thenAnswer(
        (_) async => const ClientHomeSnapshot(),
      );
      final cubit = build(name: 'Tarek');
      await cubit.load();
      expect(cubit.state.status, ClientHomeStatus.ready);
      expect(cubit.state.isEmpty, isTrue);
      expect(cubit.state.greetingName, 'Tarek');
      await cubit.close();
    });
  });

  group('refresh', () {
    test('keeps prior data visible while re-fetching', () async {
      when(() => repo.loadSnapshot()).thenAnswer(
        (_) async => ClientHomeSnapshot(
          inProgress: [_req('r-1', ClientRequestStatus.enRoute, eta: 8)],
        ),
      );
      final cubit = build();
      await cubit.load();
      expect(cubit.state.activeRequests, hasLength(1));

      when(() => repo.loadSnapshot()).thenAnswer(
        (_) async => ClientHomeSnapshot(
          inProgress: [
            _req('r-1', ClientRequestStatus.enRoute, eta: 5),
            _req('r-2', ClientRequestStatus.searching),
          ],
        ),
      );
      await cubit.refresh();
      expect(cubit.state.status, ClientHomeStatus.ready);
      expect(cubit.state.activeRequests, hasLength(2));
      await cubit.close();
    });

    // F9 rewrote this contract: a re-entrant refresh is DEFERRED, not dropped
    // — dropping it is how a landed cancel lost its only re-read.
    test('defers re-entrant calls while a load is in flight and pays them '
        'exactly once', () async {
      var calls = 0;
      when(() => repo.loadSnapshot()).thenAnswer((_) async {
        calls += 1;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return const ClientHomeSnapshot();
      });
      final cubit = build();
      final first = cubit.load();
      await cubit.refresh();
      await cubit.refresh();
      await cubit.refresh();
      expect(calls, 1, reason: 'none of them fans out mid-load');
      await first;
      expect(calls, 2, reason: 'one follow-up read, not three and not zero');
      await cubit.close();
    });
  });

  group('live refresh — push signal (Lane C; N3 retired the poll)', () {
    // The two cases that stood here — "startPolling re-pulls the snapshot on
    test('no amount of wall-clock time re-pulls the snapshot', () async {
      when(() => repo.loadSnapshot())
          .thenAnswer((_) async => const ClientHomeSnapshot());
      final bus = StreamController<void>.broadcast();
      final cubit = ClientHomeCubit(
        repository: repo,
        greetingNameProvider: () => null,
        refreshSignals: bus.stream,
      );
      await cubit.load(); // the mount one-shot
      verify(() => repo.loadSnapshot()).called(1);

      await Future<void>.delayed(const Duration(milliseconds: 250));
      verifyNever(() => repo.loadSnapshot());

      // POSITIVE CONTROL: the wiring is live, so the silence above is silence.
      bus.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      verify(() => repo.loadSnapshot()).called(1);

      await bus.close();
      await cubit.close();
    });

    // F9: the second signal is DEBT, not noise. Pre-fix `_refreshInFlight`
    // dropped it outright, which is how a landed cancel lost its only re-read.
    test('a signal arriving mid-read produces exactly ONE follow-up read',
        () async {
      final gate = Completer<void>();
      var calls = 0;
      when(() => repo.loadSnapshot()).thenAnswer((_) async {
        calls++;
        if (calls == 1) await gate.future;
        return const ClientHomeSnapshot();
      });
      final signals = StreamController<void>.broadcast();
      addTearDown(signals.close);
      final cubit = ClientHomeCubit(
        repository: repo,
        greetingNameProvider: () => null,
        refreshSignals: signals.stream,
      );

      signals.add(null);
      await Future<void>.delayed(Duration.zero);
      for (var i = 0; i < 4; i++) {
        signals.add(null);
      }
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1, reason: 'four more signals must not fan out mid-read');

      gate.complete();
      await pumpEventQueue();
      expect(
        calls,
        2,
        reason: 'the deferred signals collapse into ONE follow-up read',
      );
      await cubit.close();
    });

    test('a push refresh signal triggers a silent re-pull', () async {
      when(() => repo.loadSnapshot())
          .thenAnswer((_) async => const ClientHomeSnapshot());
      final signals = StreamController<void>.broadcast();
      addTearDown(signals.close);
      final cubit = ClientHomeCubit(
        repository: repo,
        greetingNameProvider: () => null,
        refreshSignals: signals.stream,
      );
      await cubit.load(); // 1
      signals.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      verify(() => repo.loadSnapshot()).called(greaterThan(1));
      await cubit.close();
    });
  });

  group('per-bucket failures and the warm band (WP-3)', () {
    test('a partial failure emits READY with only that bucket marked',
        () async {
      final repo = _MockRepo();
      when(repo.loadSnapshot).thenAnswer(
        (_) async => const ClientHomeSnapshot(
          inProgressFailure: NetworkFailure(offline: true),
        ),
      );
      final cubit = ClientHomeCubit(
        repository: repo,
        greetingNameProvider: () => null,
      );
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.status, ClientHomeStatus.ready);
      expect(cubit.state.inProgressError, isA<NetworkFailure>());
      expect(cubit.state.repliesError, isNull);
    });

    test('a warm failure sets refreshError and keeps the rows', () async {
      final repo = _MockRepo();
      var calls = 0;
      when(repo.loadSnapshot).thenAnswer((_) async {
        if (calls++ == 0) {
          return ClientHomeSnapshot(
            inProgress: [_req('a', ClientRequestStatus.accepted)],
          );
        }
        throw const _Boom();
      });
      final cubit = ClientHomeCubit(
        repository: repo,
        greetingNameProvider: () => null,
      );
      addTearDown(cubit.close);

      await cubit.load();
      await cubit.refresh();

      expect(cubit.state.status, ClientHomeStatus.ready);
      expect(cubit.state.inProgress, hasLength(1));
      expect(cubit.state.refreshError, isA<UnknownFailure>());
      cubit.acknowledgeRefreshError();
      expect(cubit.state.refreshError, isNull);
    });

    test('rateLimited alone never reaches FAILED', () async {
      final repo = _MockRepo();
      when(repo.loadSnapshot)
          .thenAnswer((_) async => const ClientHomeSnapshot(rateLimited: true));
      final cubit = ClientHomeCubit(
        repository: repo,
        greetingNameProvider: () => null,
      );
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.status, isNot(ClientHomeStatus.failed));
    });
  });

  group('F9 — cancel is local truth, and no refresh is ever dropped', () {
    test('removeRequest drops exactly one row and keeps the rest', () async {
      when(() => repo.loadSnapshot()).thenAnswer(
        (_) async => ClientHomeSnapshot(
          pending: [
            _req('p-1', ClientRequestStatus.searching),
            _req('p-2', ClientRequestStatus.searching),
          ],
          replies: [_req('r-9', ClientRequestStatus.searching)],
          offerStatusRequests: [_req('p-1', ClientRequestStatus.searching)],
        ),
      );
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.load();

      cubit.removeRequest('p-1');

      expect(cubit.state.pending.map((r) => r.id), ['p-2']);
      expect(cubit.state.replies.map((r) => r.id), ['r-9']);
      expect(cubit.state.offerStatusRequests, isEmpty);
      expect(cubit.state.inProgress, isEmpty);
    });

    test('removeRequest for an unknown id emits nothing', () async {
      when(() => repo.loadSnapshot()).thenAnswer(
        (_) async => ClientHomeSnapshot(
          pending: [_req('p-1', ClientRequestStatus.searching)],
        ),
      );
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.load();
      final before = cubit.state;

      cubit.removeRequest('nope');

      expect(cubit.state, same(before));
    });

    test('a cancelled row is not resurrected by a read that was already in '
        'flight', () async {
      final gate = Completer<void>();
      var calls = 0;
      when(() => repo.loadSnapshot()).thenAnswer((_) async {
        calls++;
        if (calls == 2) await gate.future;
        return ClientHomeSnapshot(
          pending: [_req('p-1', ClientRequestStatus.searching)],
        );
      });
      final cubit = build();
      addTearDown(cubit.close);

      await cubit.load();
      unawaited(cubit.refresh());
      await pumpEventQueue();
      expect(calls, 2);

      cubit.removeRequest('p-1');
      expect(cubit.state.pending, isEmpty);

      gate.complete();
      await pumpEventQueue();
      expect(
        cubit.state.pending,
        isEmpty,
        reason: 'the stale snapshot must not put the cancelled row back',
      );
    });

    test('a refresh requested while one is in flight runs exactly once '
        'afterwards', () async {
      final gate = Completer<void>();
      var calls = 0;
      when(() => repo.loadSnapshot()).thenAnswer((_) async {
        calls++;
        if (calls == 2) await gate.future;
        return const ClientHomeSnapshot();
      });
      final cubit = build();
      addTearDown(cubit.close);

      await cubit.load();
      unawaited(cubit.refresh());
      await pumpEventQueue();
      expect(calls, 2);

      await cubit.refresh();
      await cubit.refresh();
      expect(calls, 2, reason: 'both are deferred behind the in-flight read');

      gate.complete();
      await pumpEventQueue();
      expect(calls, 3, reason: 'exactly one follow-up read, not two');
    });

    test('a refresh requested during load() is not swallowed', () async {
      final gate = Completer<void>();
      var calls = 0;
      when(() => repo.loadSnapshot()).thenAnswer((_) async {
        calls++;
        if (calls == 1) await gate.future;
        return const ClientHomeSnapshot();
      });
      final cubit = build();
      addTearDown(cubit.close);

      unawaited(cubit.load());
      await pumpEventQueue();
      await cubit.refresh();
      expect(calls, 1, reason: 'deferred behind the cold load');

      gate.complete();
      await pumpEventQueue();
      expect(calls, 2);
    });

    test('a refresh requested inside the rate-limit window runs when the '
        'window expires', () async {
      var calls = 0;
      when(() => repo.loadSnapshot()).thenAnswer((_) async {
        calls++;
        return const ClientHomeSnapshot(
          rateLimited: true,
          retryAfter: Duration(milliseconds: 60),
        );
      });
      final cubit = build();
      addTearDown(cubit.close);

      await cubit.load();
      expect(calls, 1);

      await cubit.refresh();
      expect(calls, 1, reason: 'the open backoff window still suppresses it');

      await Future<void>.delayed(const Duration(milliseconds: 140));
      await pumpEventQueue();
      expect(
        calls,
        greaterThanOrEqualTo(2),
        reason: 'the suppressed refresh must be rescheduled, not dropped',
      );
    });
  });
}
