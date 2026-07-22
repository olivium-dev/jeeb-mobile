import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/no_offer_timeout/application/waiting_cubit.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/domain/waiting_repository.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/domain/waiting_request.dart';

WaitingRequest _request({
  WaitingRequestPhase phase = WaitingRequestPhase.broadcasting,
  DateTime? deadline,
  int offerCount = 0,
}) => WaitingRequest(
  requestId: 'req-1',
  phase: phase,
  notifiedCount: 3,
  offerCount: offerCount,
  broadcastExpiresAt: deadline,
  title: 'Pharmacy run',
);

class _ScriptedWaitingRepository implements WaitingRepository {
  _ScriptedWaitingRepository({
    required this.initial,
    this.polls = const <WaitingRequest>[],
    this.offerCount,
  });

  final WaitingRequest initial;
  final List<WaitingRequest> polls;
  final Future<int> Function(int fallback)? offerCount;
  final Map<int, Completer<void>> _pollWaiters = {};
  int pollCount = 0;

  Future<void> waitForPoll(int count) {
    if (pollCount >= count) return Future<void>.value();
    return (_pollWaiters[count] ??= Completer<void>()).future;
  }

  @override
  Future<WaitingRequest> fetchRequest(String requestId) async => initial;

  @override
  Future<WaitingRequest> fetchWaiting(String requestId) async {
    final result = polls[pollCount];
    pollCount += 1;
    _pollWaiters.remove(pollCount)?.complete();
    return result;
  }

  @override
  Future<int> fetchOfferCount(String requestId, {int fallback = 0}) =>
      offerCount?.call(fallback) ?? Future<int>.value(fallback);
}

void main() {
  group('WaitingCubit stable countdown', () {
    test('countdown never increases across missing-expiry emissions', () async {
      final pollTicks = StreamController<void>.broadcast();
      addTearDown(pollTicks.close);
      var now = DateTime.utc(2026, 7, 22, 8);
      final repo = _ScriptedWaitingRepository(
        initial: _request(),
        polls: [_request(), _request()],
      );
      final cubit = WaitingCubit(
        repository: repo,
        requestId: 'req-1',
        now: () => now,
        pollTicks: pollTicks.stream,
        clockTicks: const Stream.empty(),
      );
      addTearDown(cubit.close);

      await cubit.load();
      final remaining = <int>[cubit.state.remaining.inSeconds];

      now = now.add(const Duration(seconds: 4));
      cubit.tick();
      remaining.add(cubit.state.remaining.inSeconds);
      pollTicks.add(null);
      await repo.waitForPoll(1);
      await pumpEventQueue();
      remaining.add(cubit.state.remaining.inSeconds);

      now = now.add(const Duration(seconds: 11));
      cubit.tick();
      remaining.add(cubit.state.remaining.inSeconds);
      pollTicks.add(null);
      await repo.waitForPoll(2);
      await pumpEventQueue();
      remaining.add(cubit.state.remaining.inSeconds);

      expect(remaining, [300, 296, 296, 285, 285]);
      for (var i = 1; i < remaining.length; i++) {
        expect(remaining[i], lessThanOrEqualTo(remaining[i - 1]));
      }
    });

    test('re-emission does not reset the anchored fallback deadline', () async {
      final pollTicks = StreamController<void>.broadcast();
      addTearDown(pollTicks.close);
      final startedAt = DateTime.utc(2026, 7, 22, 8);
      var now = startedAt;
      final repo = _ScriptedWaitingRepository(
        initial: _request(),
        polls: [_request()],
      );
      final cubit = WaitingCubit(
        repository: repo,
        requestId: 'req-1',
        now: () => now,
        pollTicks: pollTicks.stream,
        clockTicks: const Stream.empty(),
      );
      addTearDown(cubit.close);

      await cubit.load();
      final anchored = cubit.state.request!.broadcastExpiresAt;
      expect(anchored, startedAt.add(const Duration(minutes: 5)));

      now = now.add(const Duration(seconds: 30));
      pollTicks.add(null);
      await repo.waitForPoll(1);
      await pumpEventQueue();

      expect(cubit.state.request!.broadcastExpiresAt, anchored);
      expect(cubit.state.remaining, const Duration(minutes: 4, seconds: 30));
    });

    test('a later server expiry replaces the fallback verbatim', () async {
      final pollTicks = StreamController<void>.broadcast();
      addTearDown(pollTicks.close);
      var now = DateTime.utc(2026, 7, 22, 8);
      final serverDeadline = DateTime.utc(2026, 7, 22, 8, 17, 23, 456);
      final repo = _ScriptedWaitingRepository(
        initial: _request(),
        polls: [_request(deadline: serverDeadline)],
      );
      final cubit = WaitingCubit(
        repository: repo,
        requestId: 'req-1',
        now: () => now,
        pollTicks: pollTicks.stream,
        clockTicks: const Stream.empty(),
      );
      addTearDown(cubit.close);

      await cubit.load();
      now = now.add(const Duration(seconds: 20));
      pollTicks.add(null);
      await repo.waitForPoll(1);
      await pumpEventQueue();

      expect(cubit.state.request!.broadcastExpiresAt, serverDeadline);
    });

    test('terminal poll stops polling and clock ticks', () async {
      final pollTicks = StreamController<void>.broadcast();
      final clockTicks = StreamController<void>.broadcast();
      addTearDown(pollTicks.close);
      addTearDown(clockTicks.close);
      var now = DateTime.utc(2026, 7, 22, 8);
      final repo = _ScriptedWaitingRepository(
        initial: _request(),
        polls: [
          _request(
            phase: WaitingRequestPhase.expired,
            deadline: now.add(const Duration(hours: 1)),
          ),
        ],
      );
      final cubit = WaitingCubit(
        repository: repo,
        requestId: 'req-1',
        now: () => now,
        pollTicks: pollTicks.stream,
        clockTicks: clockTicks.stream,
      );
      addTearDown(cubit.close);

      await cubit.load();
      expect(pollTicks.hasListener, isTrue);
      expect(clockTicks.hasListener, isTrue);

      pollTicks.add(null);
      await repo.waitForPoll(1);
      await pumpEventQueue();

      expect(cubit.state.isTerminal, isTrue);
      expect(cubit.state.remaining, Duration.zero);
      expect(pollTicks.hasListener, isFalse);
      expect(clockTicks.hasListener, isFalse);

      final terminalState = cubit.state;
      now = now.add(const Duration(seconds: 10));
      clockTicks.add(null);
      await pumpEventQueue();
      expect(cubit.state, terminalState);
    });

    test('late offer enrichment cannot resurrect a terminal poll', () async {
      final pollTicks = StreamController<void>.broadcast();
      final offers = Completer<int>();
      addTearDown(pollTicks.close);
      final repo = _ScriptedWaitingRepository(
        initial: _request(),
        polls: [_request(phase: WaitingRequestPhase.cancelled)],
        offerCount: (_) => offers.future,
      );
      final cubit = WaitingCubit(
        repository: repo,
        requestId: 'req-1',
        now: () => DateTime.utc(2026, 7, 22, 8),
        pollTicks: pollTicks.stream,
        clockTicks: const Stream.empty(),
      );
      addTearDown(cubit.close);

      await cubit.load();
      pollTicks.add(null);
      await repo.waitForPoll(1);
      await pumpEventQueue();
      expect(cubit.state.request!.phase, WaitingRequestPhase.cancelled);

      offers.complete(2);
      await pumpEventQueue();

      expect(cubit.state.request!.phase, WaitingRequestPhase.cancelled);
      expect(cubit.state.hasOffers, isFalse);
    });
  });
}
