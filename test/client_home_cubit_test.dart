import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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

    test('drops re-entrant calls while a load is in flight', () async {
      var calls = 0;
      when(() => repo.loadSnapshot()).thenAnswer((_) async {
        calls += 1;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return const ClientHomeSnapshot();
      });
      final cubit = build();
      final first = cubit.load();
      // refresh fires while load is mid-flight; should be dropped
      await cubit.refresh();
      await first;
      expect(calls, 1);
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

    // b02 wave D: the poll and the push bus are two INDEPENDENTLY-timed
    test('SINGLE FLIGHT: two signals inside one round trip produce one read',
        () async {
      final gate = Completer<void>();
      var calls = 0;
      when(() => repo.loadSnapshot()).thenAnswer((_) async {
        calls++;
        await gate.future;
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
      signals.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1, reason: 'the second signal must collapse onto the first');

      gate.complete();
      await Future<void>.delayed(Duration.zero);
      // ...and the latch RELEASES: a later signal still reads.
      signals.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 2);
      await cubit.close();
    });

    // b02 wave D: the poll and the push bus are two INDEPENDENTLY-timed
    // triggers on one cubit, and only the poller ever coordinated with itself
    // (LifecyclePoller skips a tick while the previous one is outstanding).
    // `state.status == loading` is not this guard either — refresh() is the
    // SILENT path and never sets `loading`, so it could not see itself.
    test('SINGLE FLIGHT: two signals inside one round trip produce one read',
        () async {
      final gate = Completer<void>();
      var calls = 0;
      when(() => repo.loadSnapshot()).thenAnswer((_) async {
        calls++;
        await gate.future;
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
      signals.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1, reason: 'the second signal must collapse onto the first');

      gate.complete();
      await Future<void>.delayed(Duration.zero);
      // ...and the latch RELEASES: a later signal still reads.
      signals.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 2);
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
}
