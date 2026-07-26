import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/features/jeeber_request_feed/cubit/request_feed_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/cubit/request_feed_state.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_models.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_repository.dart';

class _MockRepo extends Mock implements RequestFeedRepository {}

DeliveryRequest _req({
  String id = 'r1',
  Duration ttl = const Duration(seconds: 90),
  JeeberRequestTier tier = JeeberRequestTier.standard,
  DateTime? now,
  bool hasServerExpiry = true,
}) {
  final clock = now ?? DateTime(2026, 5, 17, 12);
  return DeliveryRequest(
    id: id,
    pickup: const RequestLocation(
      label: 'Pickup',
      latitude: 33.89,
      longitude: 35.48,
    ),
    dropoff: const RequestLocation(
      label: 'Dropoff',
      latitude: 33.87,
      longitude: 35.50,
    ),
    tier: tier,
    estimatedDistanceKm: 3.4,
    potentialEarnings: 5.2,
    currency: 'USD',
    expiresAt: hasServerExpiry ? clock.add(ttl) : null,
  );
}

void main() {
  late _MockRepo repo;
  late StreamController<DeliveryRequest> requests;
  late StreamController<FeedTransportUpdate> transport;

  setUp(() {
    repo = _MockRepo();
    requests = StreamController<DeliveryRequest>.broadcast();
    transport = StreamController<FeedTransportUpdate>.broadcast();
    when(() => repo.requests).thenAnswer((_) => requests.stream);
    when(() => repo.transport).thenAnswer((_) async* {
      yield const FeedTransportUpdate(FeedTransport.webSocket);
      yield* transport.stream;
    });
    when(() => repo.refresh()).thenAnswer((_) async => const <DeliveryRequest>[]);
    when(() => repo.dispose()).thenAnswer((_) async {});
  });

  tearDown(() async {
    await requests.close();
    await transport.close();
  });

  RequestFeedCubit build({
    Duration expiredLinger = const Duration(seconds: 30),
    DateTime Function()? clock,
    void Function()? onSound,
  }) {
    return RequestFeedCubit(
      repository: repo,
      expiredLinger: expiredLinger,
      sweepInterval: const Duration(milliseconds: 50),
      clock: clock,
      onNewRequestSound: onSound,
    );
  }

  group('start + refresh', () {
    blocTest<RequestFeedCubit, RequestFeedState>(
      'transitions initial → loading → ready and seeds requests from snapshot',
      build: () {
        when(() => repo.refresh()).thenAnswer((_) async => [_req()]);
        return build();
      },
      act: (c) => c.start(),
      expect: () => [
        predicate<RequestFeedState>((s) => s.status == RequestFeedStatus.loading),
        predicate<RequestFeedState>(
          (s) => s.status == RequestFeedStatus.ready && s.requests.length == 1,
        ),
      ],
    );

    blocTest<RequestFeedCubit, RequestFeedState>(
      'surfaces an error key when the snapshot fetch throws and feed is empty',
      build: () {
        when(() => repo.refresh()).thenThrow(Exception('boom'));
        return build();
      },
      act: (c) => c.start(),
      expect: () => [
        predicate<RequestFeedState>((s) => s.status == RequestFeedStatus.loading),
        predicate<RequestFeedState>(
          (s) =>
              s.status == RequestFeedStatus.error &&
              s.errorMessageKey == 'requestFeedErrorLoad',
        ),
      ],
    );
  });

  group('realtime incoming requests', () {
    blocTest<RequestFeedCubit, RequestFeedState>(
      'pushed requests merge into the feed and trigger the sound notifier exactly once per new id',
      build: () {
        var sounds = 0;
        final cubit = build(
          clock: () => DateTime(2026, 5, 17, 12),
          onSound: () => sounds += 1,
        );
        addTearDown(() {
          expect(sounds, 1, reason: 'sound should fire once per new request id');
        });
        return cubit;
      },
      act: (c) async {
        await c.start();
        final r = _req(id: 'a1');
        requests.add(r);
        requests.add(r); // duplicate id — should not refire sound
        await Future<void>.delayed(const Duration(milliseconds: 20));
      },
      verify: (c) {
        expect(c.state.requests.map((r) => r.id), ['a1']);
      },
    );

    test('transport updates flip the state field for the UI banner', () async {
      final cubit = build();
      await cubit.start();
      // Give the `yield* transport.stream` inside the mock's async* generator
      // a microtask to actually subscribe before we publish polling.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      transport.add(const FeedTransportUpdate(FeedTransport.polling));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(cubit.state.transport, FeedTransport.polling);
      await cubit.close();
    });
  });

  group('snapshot-authoritative reconcile (Lane C)', () {
    test('refresh drops a stale row the gateway no longer lists', () async {
      final snapshots = <List<DeliveryRequest>>[
        [_req(id: 'a1'), _req(id: 'a2')],
        [_req(id: 'a2')],
      ];
      var call = 0;
      when(() => repo.refresh()).thenAnswer((_) async => snapshots[call++]);
      final cubit = build();
      await cubit.start();
      expect(cubit.state.requests.map((r) => r.id), containsAll(['a1', 'a2']));
      await cubit.refresh();
      expect(cubit.state.requests.map((r) => r.id), ['a2'],
          reason: 'the additive merge would have kept the vanished a1');
      await cubit.close();
    });

    test('refresh preserves an existing row with an action in flight', () async {
      final completer = Completer<RequestActionOutcome>();
      addTearDown(() {
        if (!completer.isCompleted) {
          completer.complete(RequestActionOutcome.accepted);
        }
      });
      final snapshots = <List<DeliveryRequest>>[
        [_req(id: 'r1')],
        const <DeliveryRequest>[],
      ];
      var call = 0;
      when(() => repo.refresh()).thenAnswer((_) async => snapshots[call++]);
      when(() => repo.accept('r1')).thenAnswer((_) => completer.future);
      final cubit = build();
      await cubit.start();
      unawaited(cubit.accept('r1'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(cubit.state.actionStatusFor('r1'), RequestActionStatus.accepting);
      await cubit.refresh();
      expect(cubit.state.requests.map((r) => r.id), ['r1'],
          reason: 'an in-flight row survives a refresh that no longer lists it');
      // Resolve the in-flight accept and let it settle BEFORE close so its
      // terminal emit doesn't land after the cubit is torn down.
      completer.complete(RequestActionOutcome.accepted);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await cubit.close();
    });
  });

  group('accept / decline', () {
    blocTest<RequestFeedCubit, RequestFeedState>(
      'accept marks pending → succeeds → removes the card and emits an accepted effect',
      build: () {
        when(() => repo.refresh()).thenAnswer((_) async => [_req(id: 'r1')]);
        when(() => repo.accept('r1'))
            .thenAnswer((_) async => RequestActionOutcome.accepted);
        return build();
      },
      act: (c) async {
        await c.start();
        await c.accept('r1');
      },
      verify: (c) {
        expect(c.state.requests, isEmpty);
        expect(c.state.lastEffect?.outcome, RequestActionOutcome.accepted);
        expect(c.state.actionStatusFor('r1'), RequestActionStatus.idle);
      },
    );

    blocTest<RequestFeedCubit, RequestFeedState>(
      'network error during accept keeps the card and emits a networkError effect',
      build: () {
        when(() => repo.refresh()).thenAnswer((_) async => [_req(id: 'r1')]);
        when(() => repo.accept('r1'))
            .thenAnswer((_) async => RequestActionOutcome.networkError);
        return build();
      },
      act: (c) async {
        await c.start();
        await c.accept('r1');
      },
      verify: (c) {
        expect(c.state.requests.length, 1);
        expect(c.state.lastEffect?.outcome, RequestActionOutcome.networkError);
      },
    );

    blocTest<RequestFeedCubit, RequestFeedState>(
      'decline removes the card and emits a declined effect',
      build: () {
        when(() => repo.refresh()).thenAnswer((_) async => [_req(id: 'r1')]);
        when(() => repo.decline('r1'))
            .thenAnswer((_) async => RequestActionOutcome.declined);
        return build();
      },
      act: (c) async {
        await c.start();
        await c.decline('r1');
      },
      verify: (c) {
        expect(c.state.requests, isEmpty);
        expect(c.state.lastEffect?.outcome, RequestActionOutcome.declined);
      },
    );

    blocTest<RequestFeedCubit, RequestFeedState>(
      'second concurrent accept is ignored while the first is in-flight',
      build: () {
        when(() => repo.refresh()).thenAnswer((_) async => [_req(id: 'r1')]);
        final completer = Completer<RequestActionOutcome>();
        when(() => repo.accept('r1')).thenAnswer((_) => completer.future);
        addTearDown(() {
          if (!completer.isCompleted) {
            completer.complete(RequestActionOutcome.accepted);
          }
        });
        return build();
      },
      act: (c) async {
        await c.start();
        // Fire two accepts back-to-back; the second is a no-op.
        unawaited(c.accept('r1'));
        unawaited(c.accept('r1'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      },
      verify: (c) {
        verify(() => repo.accept('r1')).called(1);
        expect(c.state.actionStatusFor('r1'), RequestActionStatus.accepting);
      },
    );

    blocTest<RequestFeedCubit, RequestFeedState>(
      'clearEffect zeroes the transient effect so listeners do not re-fire',
      build: () {
        when(() => repo.refresh()).thenAnswer((_) async => [_req(id: 'r1')]);
        when(() => repo.accept('r1'))
            .thenAnswer((_) async => RequestActionOutcome.accepted);
        return build();
      },
      act: (c) async {
        await c.start();
        await c.accept('r1');
        c.clearEffect();
      },
      verify: (c) => expect(c.state.lastEffect, isNull),
    );
  });

  group('honest lifetime — server expiresAt is the ONLY deadline (G3)', () {
    test('a card with no server expiry never self-expires', () async {
      var now = DateTime(2026, 5, 17, 12);
      when(() => repo.refresh()).thenAnswer(
        (_) async => [_req(id: 'r1', now: now, hasServerExpiry: false)],
      );
      final cubit = build(clock: () => now);
      await cubit.start();

      now = now.add(const Duration(days: 1));
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(cubit.state.requests.map((request) => request.id), ['r1']);
      expect(cubit.state.isExpired('r1'), isFalse);
      await cubit.close();
    });

    test('expiry sweep pauses while hidden and reconciles immediately on '
        'visibility resume', () async {
      var now = DateTime(2026, 5, 17, 12);
      when(() => repo.refresh()).thenAnswer(
        (_) async =>
            [_req(id: 'r1', ttl: const Duration(seconds: 5), now: now)],
      );
      final cubit = build(clock: () => now);
      await cubit.start();
      cubit.setPollingVisible(false);

      now = now.add(const Duration(seconds: 6));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(
        cubit.state.isExpired('r1'),
        isFalse,
        reason: 'the 1-second sweep must not run for a hidden Dashboard',
      );

      cubit.setPollingVisible(true);
      expect(
        cubit.state.isExpired('r1'),
        isTrue,
        reason: 'tickOnResume must reconcile expiry without waiting a period',
      );
      await cubit.close();
    });

    // THE G3 regression test. Pre-fix the cubit truncated every card at
    // min(expiresAt, addTime + 60s), so this card (server window 300s)
    // vanished at 60s — FOUR minutes before the request actually died.
    test(
        'card SURVIVES past the old 60s client cap and stays live until '
        'the server expiresAt', () async {
      var now = DateTime(2026, 5, 17, 12);
      when(() => repo.refresh()).thenAnswer(
        (_) async =>
            [_req(id: 'r1', ttl: const Duration(seconds: 300), now: now)],
      );
      final cubit = build(clock: () => now);
      await cubit.start();
      expect(cubit.state.requests.length, 1);
      // Way past the old 60s truncation, well before the server window ends.
      now = now.add(const Duration(seconds: 240));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(cubit.state.requests.length, 1,
          reason: 'the old min(expiresAt, +60s) cap retired this card at 60s '
              'while the server window was still open');
      expect(cubit.state.isExpired('r1'), isFalse);
      await cubit.close();
    });

    test(
        'past expiresAt the card flips to a visible expired state, then '
        'collapses after the linger window — never a silent vanish', () async {
      var now = DateTime(2026, 5, 17, 12);
      when(() => repo.refresh()).thenAnswer(
        (_) async =>
            [_req(id: 'r1', ttl: const Duration(seconds: 300), now: now)],
      );
      final cubit = build(
        expiredLinger: const Duration(seconds: 30),
        clock: () => now,
      );
      await cubit.start();
      // Cross the server deadline → expired-but-still-listed.
      now = now.add(const Duration(seconds: 301));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(cubit.state.requests.length, 1,
          reason: 'expired cards linger visibly instead of vanishing');
      expect(cubit.state.isExpired('r1'), isTrue);
      // Cross the linger window → removed.
      now = now.add(const Duration(seconds: 31));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(cubit.state.requests, isEmpty);
      expect(cubit.state.isExpired('r1'), isFalse);
      await cubit.close();
    });

    test('accept/decline on an expired card is a no-op (dead server-side)',
        () async {
      var now = DateTime(2026, 5, 17, 12);
      when(() => repo.refresh()).thenAnswer(
        (_) async =>
            [_req(id: 'r1', ttl: const Duration(seconds: 5), now: now)],
      );
      final cubit = build(clock: () => now);
      await cubit.start();
      now = now.add(const Duration(seconds: 6));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(cubit.state.isExpired('r1'), isTrue);
      await cubit.accept('r1');
      await cubit.decline('r1');
      verifyNever(() => repo.accept(any()));
      verifyNever(() => repo.decline(any()));
      await cubit.close();
    });

    test(
        'refresh keeps a lingering expired card the snapshot dropped — the '
        'sweep owns its graceful removal', () async {
      var now = DateTime(2026, 5, 17, 12);
      final snapshots = <List<DeliveryRequest>>[
        [_req(id: 'r1', ttl: const Duration(seconds: 5), now: now)],
        const <DeliveryRequest>[],
      ];
      var call = 0;
      when(() => repo.refresh()).thenAnswer((_) async => snapshots[call++]);
      final cubit = build(clock: () => now);
      await cubit.start();
      now = now.add(const Duration(seconds: 6));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(cubit.state.isExpired('r1'), isTrue);
      await cubit.refresh();
      expect(cubit.state.requests.map((r) => r.id), ['r1'],
          reason: 'a refresh must not cut the expired linger short');
      expect(cubit.state.isExpired('r1'), isTrue);
      now = now.add(const Duration(seconds: 31));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(cubit.state.requests, isEmpty);
      await cubit.close();
    });

    test('a re-listed id revives from the expired state (server disagrees)',
        () async {
      var now = DateTime(2026, 5, 17, 12);
      final first = _req(id: 'r1', ttl: const Duration(seconds: 5), now: now);
      when(() => repo.refresh()).thenAnswer((_) async => [first]);
      final cubit = build(clock: () => now);
      await cubit.start();
      now = now.add(const Duration(seconds: 6));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(cubit.state.isExpired('r1'), isTrue);
      // The gateway re-lists r1 with a fresh window → live again.
      when(() => repo.refresh()).thenAnswer(
        (_) async =>
            [_req(id: 'r1', ttl: const Duration(seconds: 300), now: now)],
      );
      await cubit.refresh();
      expect(cubit.state.isExpired('r1'), isFalse);
      expect(cubit.state.requests.length, 1);
      await cubit.close();
    });
  });
}
