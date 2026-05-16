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
    expiresAt: clock.add(ttl),
  );
}

void main() {
  late _MockRepo repo;
  late StreamController<DeliveryRequest> requests;
  late StreamController<String> cancellations;
  late StreamController<FeedTransportUpdate> transport;

  setUp(() {
    repo = _MockRepo();
    requests = StreamController<DeliveryRequest>.broadcast();
    cancellations = StreamController<String>.broadcast();
    transport = StreamController<FeedTransportUpdate>.broadcast();
    when(() => repo.requests).thenAnswer((_) => requests.stream);
    when(() => repo.cancellations).thenAnswer((_) => cancellations.stream);
    when(() => repo.transport).thenAnswer((_) async* {
      yield const FeedTransportUpdate(FeedTransport.webSocket);
      yield* transport.stream;
    });
    when(() => repo.refresh()).thenAnswer((_) async => const <DeliveryRequest>[]);
    when(() => repo.dispose()).thenAnswer((_) async {});
  });

  tearDown(() async {
    await requests.close();
    await cancellations.close();
    await transport.close();
  });

  RequestFeedCubit build({
    Duration timeout = const Duration(seconds: 60),
    DateTime Function()? clock,
    void Function()? onSound,
  }) {
    return RequestFeedCubit(
      repository: repo,
      requestTimeout: timeout,
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
        final cubit = build(onSound: () => sounds += 1);
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

    blocTest<RequestFeedCubit, RequestFeedState>(
      'cancellations from the gateway pop matching cards off the feed',
      build: () {
        when(() => repo.refresh()).thenAnswer((_) async => [_req(id: 'x1')]);
        return build();
      },
      act: (c) async {
        await c.start();
        cancellations.add('x1');
        await Future<void>.delayed(const Duration(milliseconds: 20));
      },
      verify: (c) {
        expect(c.state.requests, isEmpty);
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

  group('auto-dismiss / expiry sweep', () {
    test('retires cards whose client-side timeout has elapsed', () async {
      var now = DateTime(2026, 5, 17, 12);
      when(() => repo.refresh()).thenAnswer(
        (_) async => [_req(id: 'r1', ttl: const Duration(seconds: 300), now: now)],
      );
      final cubit = build(
        timeout: const Duration(seconds: 10),
        clock: () => now,
      );
      await cubit.start();
      expect(cubit.state.requests.length, 1);
      // Advance the clock past the client-side timeout (10s), but before
      // the server-side TTL (300s) — the sweep should still retire the card
      // because the cubit uses the earlier deadline.
      now = now.add(const Duration(seconds: 11));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(cubit.state.requests, isEmpty);
      await cubit.close();
    });

    test('retires cards whose server expiresAt is sooner than the client timeout', () async {
      var now = DateTime(2026, 5, 17, 12);
      when(() => repo.refresh()).thenAnswer(
        (_) async => [_req(id: 'r1', ttl: const Duration(seconds: 5), now: now)],
      );
      final cubit = build(
        timeout: const Duration(seconds: 60),
        clock: () => now,
      );
      await cubit.start();
      now = now.add(const Duration(seconds: 6));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(cubit.state.requests, isEmpty);
      await cubit.close();
    });
  });
}
