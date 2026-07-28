import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/client_offers/application/client_offers_cubit.dart';
import 'package:jeeb_mobile/features/client_offers/domain/jeeber_vehicle.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offer.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offers_repository.dart';

/// b02 wave C — N8. The "Choose a Jeeber" list used to re-read
/// `GET /v1/offers?requestId` + `GET /v1/requests/{id}` every 5s through a raw
/// `Stream.periodic` with ZERO gate tokens, so it kept firing while the app was
/// BACKGROUNDED. The replacement is the existing payload-less push bus: the
/// gateway already emits `type=offer` to `request.ClientId`
/// (`jeeb-gateway/src/JeebGateway/Notifications/OfferPushNotifier.cs:227`, sent
/// at `:399-402` from `Controllers/RequestOffersController.cs:326`), which the
/// mobile handler buckets as `NotificationCategory.newOffer` and routes through
/// the id-guarded `orderish` branch of
/// `PushNotificationHandler._maybeSignalStatusChange` (`requestId`/`request_id`
/// are both stamped on that payload).
class _FakeOffersRepository implements OffersRepository {
  // `requestIsOpen` is a mutable FIELD, not a constructor parameter: no test
  // seeds it (they flip it mid-run), and a never-supplied optional parameter
  // is an `unused_element_parameter` warning, which CI treats as fatal.
  bool requestIsOpen = true;
  int fetchCount = 0;

  @override
  Future<OffersSnapshot> fetchOffers(String requestId) async {
    fetchCount++;
    return OffersSnapshot(
      offers: <Offer>[
        Offer(
          id: 'offer-$fetchCount',
          jeeberId: 'jeeber-$fetchCount',
          jeeberName: 'Jeeber $fetchCount',
          fee: (10 + fetchCount).toDouble(),
          currency: 'USD',
          etaMinutes: 12,
          vehicle: JeeberVehicle.motorcycle,
          rating: 4.5,
          ratingCount: 3,
          submittedAt: DateTime.utc(2026, 7, 26, 12, fetchCount),
        ),
      ],
      windowExpiresAt: DateTime.utc(2026, 7, 26, 13),
      requestIsOpen: requestIsOpen,
    );
  }

  @override
  Future<OfferAcceptResult> acceptOffer({
    required String requestId,
    required String offerId,
  }) async =>
      const OfferAcceptResult(deliveryId: 'del-1');
}

void main() {
  group('N8 client offers — push-driven, no wall-clock poll', () {
    test('a push on the refresh bus triggers exactly one re-read', () async {
      final repo = _FakeOffersRepository();
      final bus = StreamController<void>.broadcast();
      addTearDown(bus.close);

      final cubit = ClientOffersCubit(
        repository: repo,
        requestId: 'req-1',
        refreshSignals: bus.stream,
        clockTicks: const Stream<void>.empty(),
      );
      addTearDown(cubit.close);

      await cubit.load();
      expect(repo.fetchCount, 1, reason: 'cold load is one read');
      expect(cubit.debugPushRefreshWired, isTrue,
          reason: 'the subscription must be armed once the request is open');

      bus.add(null);
      await Future<void>.delayed(Duration.zero);

      expect(repo.fetchCount, 2, reason: 'one push → exactly one re-read');
      expect(cubit.state.offers.single.id, 'offer-2');
    });

    test('no push and no user action ⇒ no second read after 30 virtual seconds',
        () {
      fakeAsync((async) {
        final repo = _FakeOffersRepository();
        final cubit = ClientOffersCubit(
          repository: repo,
          requestId: 'req-1',
          refreshSignals: const Stream<void>.empty(),
          clockTicks: const Stream<void>.empty(),
        );
        cubit.load();
        async.flushMicrotasks();
        expect(repo.fetchCount, 1);

        async.elapse(const Duration(seconds: 30));
        async.flushMicrotasks();

        expect(repo.fetchCount, 1,
            reason: 'the 5s Stream.periodic poll must be GONE — 30s of wall '
                'clock with no push and no user action is zero extra reads');
        cubit.close();
      });
    });

    test('the bus subscription is torn down once the request closes', () async {
      final repo = _FakeOffersRepository();
      final bus = StreamController<void>.broadcast();
      addTearDown(bus.close);

      final cubit = ClientOffersCubit(
        repository: repo,
        requestId: 'req-1',
        refreshSignals: bus.stream,
        clockTicks: const Stream<void>.empty(),
      );
      addTearDown(cubit.close);

      await cubit.load();
      repo.requestIsOpen = false;

      // A push arrives; the snapshot now says the request is closed, which must
      // retire the subscription so a later push drives nothing.
      bus.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(repo.fetchCount, 2);
      expect(cubit.state.requestIsOpen, isFalse);
      expect(cubit.debugPushRefreshWired, isFalse);

      bus.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(repo.fetchCount, 2, reason: 'closed request takes no more reads');
    });

    test('two pushes inside one in-flight read collapse to one re-read',
        () async {
      final repo = _GatedOffersRepository();
      final bus = StreamController<void>.broadcast();
      addTearDown(bus.close);

      final cubit = ClientOffersCubit(
        repository: repo,
        requestId: 'req-1',
        refreshSignals: bus.stream,
        clockTicks: const Stream<void>.empty(),
      );
      addTearDown(cubit.close);

      repo.release();
      await cubit.load();
      expect(repo.fetchCount, 1);

      repo.hold();
      bus.add(null);
      await Future<void>.delayed(Duration.zero);
      bus.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(repo.fetchCount, 2,
          reason: 'the second push must be dropped while the first read is on '
              'the wire — otherwise the later response can paint the OLDER '
              'snapshot');
      repo.release();
      await Future<void>.delayed(Duration.zero);
    });
  });
}

/// Offers repository whose reads can be held open, to exercise the in-flight
/// latch on the push path.
class _GatedOffersRepository implements OffersRepository {
  Completer<void>? _gate;
  int fetchCount = 0;

  void hold() => _gate = Completer<void>();
  void release() {
    final g = _gate;
    _gate = null;
    if (g != null && !g.isCompleted) g.complete();
  }

  @override
  Future<OffersSnapshot> fetchOffers(String requestId) async {
    fetchCount++;
    await _gate?.future;
    return const OffersSnapshot(
      offers: <Offer>[],
      windowExpiresAt: null,
      requestIsOpen: true,
    );
  }

  @override
  Future<OfferAcceptResult> acceptOffer({
    required String requestId,
    required String offerId,
  }) async =>
      const OfferAcceptResult(deliveryId: 'del-1');
}
