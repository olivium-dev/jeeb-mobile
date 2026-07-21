import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
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
}) =>
    OffersSnapshot(
      offers: offers,
      windowExpiresAt: deadline ?? kBaseTime.add(const Duration(minutes: 15)),
      requestIsOpen: requestIsOpen,
    );

ClientOffersCubit _buildCubit({
  required ScriptedOffersRepository repository,
  Stream<void>? pollTicks,
  Stream<void>? clockTicks,
  DateTime Function()? now,
}) {
  final cubit = ClientOffersCubit(
    repository: repository,
    requestId: 'req-1',
    now: now ?? () => kBaseTime,
    pollTicks: pollTicks ?? const Stream.empty(),
    clockTicks: clockTicks ?? const Stream.empty(),
  );
  addTearDown(cubit.close);
  return cubit;
}

void main() {
  group('ClientOffersCubit — initial load', () {
    test('emits loaded snapshot sorted by price (default)', () async {
      final offers = [
        buildOffer(id: 'a', fee: 30),
        buildOffer(id: 'b', fee: 10),
        buildOffer(id: 'c', fee: 20),
      ];
      final repo = ScriptedOffersRepository(snapshots: [_snapshot(offers)]);
      final cubit = _buildCubit(repository: repo);

      await cubit.load();

      expect(cubit.state.status, OffersScreenStatus.loaded);
      expect(cubit.state.sortMode, OfferSortMode.byPrice);
      expect(
        cubit.state.offers.map((o) => o.id).toList(),
        ['b', 'c', 'a'],
        reason: 'price asc',
      );
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
      expect(
        cubit.state.offers.map((o) => o.id).toList(),
        ['b', 'c', 'a'],
      );
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
      expect(
        cubit.state.offers.map((o) => o.id).toList(),
        ['newer', 'older'],
      );
    });

    test('setSortMode is a no-op when called with the current mode',
        () async {
      final repo = ScriptedOffersRepository(
        snapshots: [_snapshot([buildOffer(id: 'a')])],
      );
      final cubit = _buildCubit(repository: repo);
      await cubit.load();
      final snapshot = cubit.state;

      cubit.setSortMode(OfferSortMode.byPrice);
      expect(cubit.state, snapshot);
    });
  });

  group('ClientOffersCubit — accept flow', () {
    test('accept emits in-flight then succeeded and closes the request',
        () async {
      final repo = ScriptedOffersRepository(
        snapshots: [_snapshot([buildOffer(id: 'pick-me')])],
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
    });

    test('accept failure returns to idle and surfaces classified error',
        () async {
      final repo = ScriptedOffersRepository(
        snapshots: [_snapshot([buildOffer(id: 'pick-me')])],
        acceptFailure: OffersFailure.offerNotPending,
      );
      final cubit = _buildCubit(repository: repo);
      await cubit.load();

      await cubit.acceptOffer('pick-me');

      expect(cubit.state.acceptStatus, AcceptStatus.idle);
      expect(cubit.state.error, OffersFailure.offerNotPending);
      expect(cubit.state.requestIsOpen, isTrue);
    });

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
        pollTicks: const Stream.empty(),
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
        pollTicks: pollTrigger.stream,
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
        snapshots: [_snapshot([buildOffer(id: 'a')])],
      );
      final pollTrigger = StreamController<void>();
      final cubit = _buildCubit(
        repository: repo,
        pollTicks: pollTrigger.stream,
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
        pollTicks: pollTrigger.stream,
      );
      addTearDown(pollTrigger.close);
      await cubit.load();
      await cubit.acceptOffer('a');

      pollTrigger.add(null);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // First fetch from load() — the poll after accept never reaches the
      // repository because the subscription was cancelled.
      expect(repo.fetchCalls, 1);
    });
  });

  group('ClientOffersCubit — countdown', () {
    test('tick advances "now" and flips windowExpired past the deadline',
        () async {
      var fakeNow = kBaseTime;
      final repo = ScriptedOffersRepository(snapshots: [
        OffersSnapshot(
          offers: [buildOffer(id: 'a')],
          windowExpiresAt: kBaseTime.add(const Duration(seconds: 10)),
          requestIsOpen: true,
        ),
      ]);
      final cubit = ClientOffersCubit(
        repository: repo,
        requestId: 'req-1',
        now: () => fakeNow,
        pollTicks: const Stream.empty(),
        clockTicks: const Stream.empty(),
      );
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.windowRemaining, const Duration(seconds: 10));
      expect(cubit.state.windowExpired, isFalse);

      fakeNow = kBaseTime.add(const Duration(seconds: 5));
      cubit.tick();
      expect(cubit.state.windowRemaining, const Duration(seconds: 5));

      fakeNow = kBaseTime.add(const Duration(seconds: 15));
      cubit.tick();
      expect(cubit.state.windowRemaining, Duration.zero);
      expect(cubit.state.windowExpired, isTrue);
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
