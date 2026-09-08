import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/client_offers/application/client_offers_cubit.dart';
import 'package:jeeb_mobile/features/client_offers/application/client_offers_state.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offer.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offers_repository.dart';

import 'support/offers_fixtures.dart';
import 'support/scripted_offers_repository.dart';

OffersSnapshot _snapshot(
  List<Offer> offers, {
  DateTime? deadline,
  bool requestIsOpen = true,
}) => OffersSnapshot(
  offers: offers,
  windowExpiresAt: deadline ?? kBaseTime.add(const Duration(minutes: 15)),
  requestIsOpen: requestIsOpen,
);

ClientOffersCubit _buildCubit({
  required ScriptedOffersRepository repository,
  Stream<void>? refreshSignals,
  Stream<void>? clockTicks,
  DateTime Function()? now,
}) {
  final cubit = ClientOffersCubit(
    repository: repository,
    requestId: 'req-1',
    now: now ?? () => kBaseTime,
    refreshSignals: refreshSignals ?? const Stream.empty(),
    clockTicks: clockTicks ?? const Stream.empty(),
  );
  addTearDown(cubit.close);
  return cubit;
}

void main() {
  group('ClientOffersCubit — initial load', () {
    // PRODUCT CHANGE (redesign-2026-08 screen 11): the default sort is the
    // composite `best` ranking, not `byPrice`. This test is the documentation
    // of that change. The ORDER below is unchanged because these three offers
    // tie on rating and ETA, which leaves fee as the only discriminator — the
    // new default degrades to the old one exactly when nothing else differs.
    test('emits loaded snapshot sorted by best value (default)', () async {
      final offers = [
        buildOffer(id: 'a', fee: 30),
        buildOffer(id: 'b', fee: 10),
        buildOffer(id: 'c', fee: 20),
      ];
      final repo = ScriptedOffersRepository(snapshots: [_snapshot(offers)]);
      final cubit = _buildCubit(repository: repo);

      await cubit.load();

      expect(cubit.state.status, OffersScreenStatus.loaded);
      expect(cubit.state.sortMode, OfferSortMode.best);
      expect(cubit.state.offers.map((o) => o.id).toList(), [
        'b',
        'c',
        'a',
      ], reason: 'rating and ETA tie, so the composite falls back to fee asc');
      expect(cubit.state.requestIsOpen, isTrue);
    });

    test('failure during cold load surfaces as failed status', () async {
      final repo = ScriptedOffersRepository(
        snapshots: [_snapshot([])],
        fetchFailure: OffersFailure.network,
      );
      final cubit = _buildCubit(repository: repo);

      await cubit.load();

      expect(cubit.state.status, OffersScreenStatus.failed);
      expect(cubit.state.error, OffersFailure.network);
    });

    test(
      'successful refetch clears load errors but preserves accept errors',
      () async {
        final repo = ScriptedOffersRepository(
          snapshots: [
            _snapshot([buildOffer(id: 'a')]),
          ],
        );
        final cubit = _buildCubit(repository: repo);
        await cubit.load();

        repo.scriptFetchFailure(OffersFailure.network);
        await cubit.refresh();
        expect(cubit.state.error, OffersFailure.network);
        expect(cubit.state.errorSource, OffersErrorSource.load);

        await cubit.refresh();
        expect(cubit.state.error, isNull);
        expect(cubit.state.errorSource, isNull);

        repo.scriptAcceptFailure(OffersFailure.offerNotPending);
        await cubit.acceptOffer('a');
        expect(cubit.state.error, OffersFailure.offerNotPending);
        expect(cubit.state.errorSource, OffersErrorSource.accept);

        await cubit.refresh();
        expect(cubit.state.error, OffersFailure.offerNotPending);
        expect(cubit.state.errorSource, OffersErrorSource.accept);
      },
    );
  });

  group('ClientOffersCubit — sorting', () {
    test('setSortMode(byRating) re-orders to rating desc', () async {
      final offers = [
        buildOffer(id: 'a', fee: 10, rating: 4.1),
        buildOffer(id: 'b', fee: 20, rating: 4.9),
        buildOffer(id: 'c', fee: 30, rating: 4.5),
      ];
      final repo = ScriptedOffersRepository(snapshots: [_snapshot(offers)]);
      final cubit = _buildCubit(repository: repo);
      await cubit.load();

      cubit.setSortMode(OfferSortMode.byRating);

      expect(cubit.state.sortMode, OfferSortMode.byRating);
      expect(cubit.state.offers.map((o) => o.id).toList(), ['b', 'c', 'a']);
    });

    test('equal price ties break newest-first', () async {
      final offers = [
        buildOffer(
          id: 'older',
          fee: 10,
          submittedAt: kBaseTime.subtract(const Duration(minutes: 2)),
        ),
        buildOffer(
          id: 'newer',
          fee: 10,
          submittedAt: kBaseTime.subtract(const Duration(seconds: 5)),
        ),
      ];
      final repo = ScriptedOffersRepository(snapshots: [_snapshot(offers)]);
      final cubit = _buildCubit(repository: repo);
      await cubit.load();
      expect(cubit.state.offers.map((o) => o.id).toList(), ['newer', 'older']);
    });

    test('setSortMode is a no-op when called with the current mode', () async {
      final repo = ScriptedOffersRepository(
        snapshots: [
          _snapshot([buildOffer(id: 'a')]),
        ],
      );
      final cubit = _buildCubit(repository: repo);
      await cubit.load();
      final snapshot = cubit.state;

      cubit.setSortMode(OfferSortMode.best);
      expect(cubit.state, snapshot);
    });
  });

  group('ClientOffersCubit — accept flow', () {
    test(
      'accept emits in-flight then succeeded and closes the request',
      () async {
        final repo = ScriptedOffersRepository(
          snapshots: [
            _snapshot([buildOffer(id: 'pick-me')]),
          ],
        );
        final cubit = _buildCubit(repository: repo);
        await cubit.load();

        final emitted = <AcceptStatus>[];
        final sub = cubit.stream.listen((s) => emitted.add(s.acceptStatus));

        await cubit.acceptOffer('pick-me');
        await sub.cancel();

        expect(repo.lastAcceptedRequestId, 'req-1');
        expect(repo.lastAcceptedOfferId, 'pick-me');
        expect(cubit.state.acceptedOfferId, 'pick-me');
        expect(cubit.state.acceptStatus, AcceptStatus.succeeded);
        expect(cubit.state.requestIsOpen, isFalse);
        expect(emitted, [AcceptStatus.inFlight, AcceptStatus.succeeded]);
      },
    );

    test(
      'accept failure returns to idle and surfaces classified error',
      () async {
        final repo = ScriptedOffersRepository(
          snapshots: [
            _snapshot([buildOffer(id: 'pick-me')]),
          ],
          acceptFailure: OffersFailure.offerNotPending,
        );
        final cubit = _buildCubit(repository: repo);
        await cubit.load();

        await cubit.acceptOffer('pick-me');

        expect(cubit.state.acceptStatus, AcceptStatus.idle);
        expect(cubit.state.error, OffersFailure.offerNotPending);
        expect(cubit.state.requestIsOpen, isTrue);
      },
    );

    test('concurrent accept is rejected while in-flight', () async {
      final completer = Completer<void>();
      final repo = _SuspendingRepository(
        snapshot: _snapshot([buildOffer(id: 'pick-me')]),
        acceptGate: completer.future,
      );
      final cubit = ClientOffersCubit(
        repository: repo,
        requestId: 'req-1',
        now: () => kBaseTime,
        refreshSignals: const Stream.empty(),
        clockTicks: const Stream.empty(),
      );
      addTearDown(cubit.close);
      await cubit.load();

      final first = cubit.acceptOffer('pick-me');
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.acceptStatus, AcceptStatus.inFlight);

      await cubit.acceptOffer('pick-me'); // returns immediately
      expect(repo.acceptCalls, 1);

      completer.complete();
      await first;
      expect(cubit.state.acceptStatus, AcceptStatus.succeeded);
    });
  });

  group('ClientOffersCubit — polling', () {
    test('poll tick merges new offers into the sorted list', () async {
      final initial = [buildOffer(id: 'a', fee: 30)];
      final updated = [
        buildOffer(id: 'a', fee: 30),
        buildOffer(id: 'b', fee: 5),
      ];
      final repo = ScriptedOffersRepository(
        snapshots: [_snapshot(initial), _snapshot(updated)],
      );
      final pollTrigger = StreamController<void>();
      final cubit = _buildCubit(
        repository: repo,
        refreshSignals: pollTrigger.stream,
      );
      addTearDown(pollTrigger.close);
      await cubit.load();
      expect(cubit.state.offers.map((o) => o.id).toList(), ['a']);

      pollTrigger.add(null);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.offers.map((o) => o.id).toList(), ['b', 'a']);
      expect(repo.fetchCalls, 2);
    });

    test('poll failures are swallowed and do not flip status', () async {
      final repo = ScriptedOffersRepository(
        snapshots: [
          _snapshot([buildOffer(id: 'a')]),
        ],
      );
      final pollTrigger = StreamController<void>();
      final cubit = _buildCubit(
        repository: repo,
        refreshSignals: pollTrigger.stream,
      );
      addTearDown(pollTrigger.close);
      await cubit.load();
      repo.scriptFetchFailure(OffersFailure.network);

      pollTrigger.add(null);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.status, OffersScreenStatus.loaded);
      expect(cubit.state.error, isNull);
    });

    test('poll stops once the request has been accepted', () async {
      final repo = ScriptedOffersRepository(
        snapshots: [
          _snapshot([buildOffer(id: 'a')]),
          _snapshot([buildOffer(id: 'a')]),
        ],
      );
      final pollTrigger = StreamController<void>();
      final cubit = _buildCubit(
        repository: repo,
        refreshSignals: pollTrigger.stream,
      );
      addTearDown(pollTrigger.close);
      await cubit.load();
      await cubit.acceptOffer('a');

      pollTrigger.add(null);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // First fetch from load() — the poll after accept never reaches the
      expect(repo.fetchCalls, 1);
    });

    test(
      'terminal server emission closes immediately and stops later polls',
      () async {
        final repo = ScriptedOffersRepository(
          snapshots: [
            _snapshot([
              buildOffer(id: 'a'),
            ], deadline: kBaseTime.add(const Duration(minutes: 1))),
            OffersSnapshot(
              offers: [buildOffer(id: 'a')],
              windowExpiresAt: null,
              requestIsOpen: false,
              requestIsExpired: true,
            ),
          ],
        );
        final pollTrigger = StreamController<void>();
        final cubit = _buildCubit(
          repository: repo,
          refreshSignals: pollTrigger.stream,
        );
        addTearDown(pollTrigger.close);
        await cubit.load();

        pollTrigger.add(null);
        await pumpEventQueue();

        expect(cubit.state.requestIsOpen, isFalse);
        expect(cubit.state.requestIsExpired, isTrue);
        expect(cubit.state.windowExpiresAt, isNull);

        pollTrigger.add(null);
        await pumpEventQueue();
        expect(repo.fetchCalls, 2);
      },
    );
  });

  group('ClientOffersCubit — countdown', () {
    test(
      'elapsed display deadline never closes a server-live request',
      () async {
        var fakeNow = kBaseTime;
        final repo = ScriptedOffersRepository(
          snapshots: [
            OffersSnapshot(
              offers: [buildOffer(id: 'a')],
              windowExpiresAt: kBaseTime.add(const Duration(seconds: 10)),
              requestIsOpen: true,
            ),
          ],
        );
        final cubit = ClientOffersCubit(
          repository: repo,
          requestId: 'req-1',
          now: () => fakeNow,
          refreshSignals: const Stream.empty(),
          clockTicks: const Stream.empty(),
        );
        addTearDown(cubit.close);

        await cubit.load();
        expect(cubit.state.windowRemaining, const Duration(seconds: 10));
        expect(cubit.state.requestIsOpen, isTrue);
        expect(cubit.state.requestIsExpired, isFalse);

        fakeNow = kBaseTime.add(const Duration(seconds: 5));
        cubit.tick();
        expect(cubit.state.windowRemaining, const Duration(seconds: 5));

        fakeNow = kBaseTime.add(const Duration(seconds: 15));
        cubit.tick();
        expect(cubit.state.windowRemaining, Duration.zero);
        expect(cubit.state.requestIsOpen, isTrue);
        expect(cubit.state.requestIsExpired, isFalse);
      },
    );
  });
  group('the state carries a classified failure (WP-3)', () {
    test('a network load failure lands an AppFailure beside the enum',
        () async {
      final repo = ScriptedOffersRepository(
        snapshots: const <OffersSnapshot>[],
        fetchFailure: OffersFailure.network,
      );
      final cubit = ClientOffersCubit(
        repository: repo,
        requestId: 'req-1',
        retryDelay: (Duration _) async {},
        refreshSignals: const Stream<void>.empty(),
        clockTicks: const Stream<void>.empty(),
      );
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.status, OffersScreenStatus.failed);
      expect(cubit.state.error, OffersFailure.network);
      expect(cubit.state.appFailure, isA<NetworkFailure>());
    });
  });
}

/// Repository used by the "concurrent accept is rejected" test. The accept
/// path blocks on [acceptGate] so the test can assert in-flight state before
/// release.
class _SuspendingRepository implements OffersRepository {
  _SuspendingRepository({required this.snapshot, required this.acceptGate});

  final OffersSnapshot snapshot;
  final Future<void> acceptGate;
  int acceptCalls = 0;

  @override
  Future<OffersSnapshot> fetchOffers(String requestId) async => snapshot;

  @override
  Future<OfferAcceptResult> acceptOffer({
    required String requestId,
    required String offerId,
  }) async {
    acceptCalls++;
    await acceptGate;
    return OfferAcceptResult.empty;
  }
}
