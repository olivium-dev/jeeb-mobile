import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/diagnostics/diag.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/application/waiting_cubit.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/application/waiting_state.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/domain/waiting_repository.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/domain/waiting_request.dart';

final DateTime _t0 = DateTime.utc(2026, 7, 22, 8);

/// P7: every snapshot carries the ANCHOR PAIR — the device instant the payload
/// was received plus the server-relative time left at that instant. There is no
/// server-absolute deadline field and no client-side fallback window.
WaitingRequest _request({
  WaitingRequestPhase phase = WaitingRequestPhase.broadcasting,
  DateTime? receivedAt,
  Duration? remainingAtReceipt = const Duration(minutes: 5),
  int offerCount = 0,
}) => WaitingRequest(
  requestId: 'req-1',
  phase: phase,
  notifiedCount: 3,
  offerCount: offerCount,
  receivedAt: receivedAt ?? _t0,
  remainingAtReceipt: remainingAtReceipt,
  title: 'Pharmacy run',
);

class _ScriptedWaitingRepository implements WaitingRepository {
  _ScriptedWaitingRepository({
    required this.initial,
    this.polls = const <WaitingRequest>[],
    this.offerCount,
    this.initialError,
    this.pollErrors = const <int, WaitingException>{},
  });

  /// Snapshot returned by the cold load. Mutable so a retry can be scripted to
  /// recover (T5.4).
  WaitingRequest initial;
  final List<WaitingRequest> polls;
  final Future<int> Function(int fallback)? offerCount;

  /// When set, the cold load throws this instead of returning [initial].
  /// Mutable so T5.4 can clear it before `retry()`.
  WaitingException? initialError;

  /// Poll index → exception to throw instead of returning `polls[index]`.
  final Map<int, WaitingException> pollErrors;

  final Map<int, Completer<void>> _pollWaiters = {};
  int pollCount = 0;

  Future<void> waitForPoll(int count) {
    if (pollCount >= count) return Future<void>.value();
    return (_pollWaiters[count] ??= Completer<void>()).future;
  }

  @override
  Future<WaitingRequest> fetchRequest(String requestId) async {
    final error = initialError;
    if (error != null) throw error;
    return initial;
  }

  @override
  Future<WaitingRequest> fetchWaiting(String requestId) async {
    final index = pollCount;
    pollCount += 1;
    _pollWaiters.remove(pollCount)?.complete();
    final error = pollErrors[index];
    if (error != null) throw error;
    return polls[index];
  }

  @override
  Future<int> fetchOfferCount(String requestId, {int fallback = 0}) =>
      offerCount?.call(fallback) ?? Future<int>.value(fallback);
}

void main() {
  group('WaitingCubit stable countdown', () {
    test('countdown never increases across anchored poll emissions', () async {
      final pollTicks = StreamController<void>.broadcast();
      addTearDown(pollTicks.close);
      var now = _t0;
      // Each poll re-anchors on the SERVER's remaining value at the instant it
      // was received — so the derived deadline is stable at t0 + 300s.
      final repo = _ScriptedWaitingRepository(
        initial: _request(),
        polls: [
          _request(
            receivedAt: _t0.add(const Duration(seconds: 4)),
            remainingAtReceipt: const Duration(seconds: 296),
          ),
          _request(
            receivedAt: _t0.add(const Duration(seconds: 15)),
            remainingAtReceipt: const Duration(seconds: 285),
          ),
        ],
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
      final remaining = <int>[cubit.state.remaining!.inSeconds];

      now = now.add(const Duration(seconds: 4));
      cubit.tick();
      remaining.add(cubit.state.remaining!.inSeconds);
      pollTicks.add(null);
      await repo.waitForPoll(1);
      await pumpEventQueue();
      remaining.add(cubit.state.remaining!.inSeconds);

      now = now.add(const Duration(seconds: 11));
      cubit.tick();
      remaining.add(cubit.state.remaining!.inSeconds);
      pollTicks.add(null);
      await repo.waitForPoll(2);
      await pumpEventQueue();
      remaining.add(cubit.state.remaining!.inSeconds);

      expect(remaining, [300, 296, 296, 285, 285]);
      for (var i = 1; i < remaining.length; i++) {
        expect(remaining[i], lessThanOrEqualTo(remaining[i - 1]));
      }
    });

    test('a re-emitted identical snapshot keeps the same anchor pair', () async {
      final pollTicks = StreamController<void>.broadcast();
      addTearDown(pollTicks.close);
      var now = _t0;
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
      final anchored = cubit.state.request!.deadline;
      expect(anchored, _t0.add(const Duration(minutes: 5)));

      now = now.add(const Duration(seconds: 30));
      pollTicks.add(null);
      await repo.waitForPoll(1);
      await pumpEventQueue();

      expect(cubit.state.request!.receivedAt, _t0);
      expect(
        cubit.state.request!.remainingAtReceipt,
        const Duration(minutes: 5),
      );
      expect(cubit.state.request!.deadline, anchored);
      expect(cubit.state.remaining, const Duration(minutes: 4, seconds: 30));
    });

    test('a fresh server anchor pair replaces the previous one', () async {
      final pollTicks = StreamController<void>.broadcast();
      addTearDown(pollTicks.close);
      var now = _t0;
      final polledAt = _t0.add(const Duration(seconds: 20));
      final repo = _ScriptedWaitingRepository(
        initial: _request(),
        polls: [
          _request(
            receivedAt: polledAt,
            remainingAtReceipt: const Duration(seconds: 1043),
          ),
        ],
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
      now = polledAt;
      pollTicks.add(null);
      await repo.waitForPoll(1);
      await pumpEventQueue();

      expect(cubit.state.request!.receivedAt, polledAt);
      expect(
        cubit.state.request!.remainingAtReceipt,
        const Duration(seconds: 1043),
      );
      expect(cubit.state.remaining, const Duration(seconds: 1043));
    });

    test('terminal poll stops polling and clock ticks', () async {
      final pollTicks = StreamController<void>.broadcast();
      final clockTicks = StreamController<void>.broadcast();
      addTearDown(pollTicks.close);
      addTearDown(clockTicks.close);
      var now = _t0;
      final repo = _ScriptedWaitingRepository(
        initial: _request(),
        polls: [
          _request(
            phase: WaitingRequestPhase.expired,
            remainingAtReceipt: const Duration(hours: 1),
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
      // No countdown applies to a terminal row — NOT a fabricated 0:00.
      expect(cubit.state.remaining, isNull);
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
        now: () => _t0,
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

  // ── T5 — contract-violation routing vs network failure ────────────────────
  //
  // A contract violation is NOT transient: retrying re-reads the same broken
  // payload. It must terminate the screen loudly and distinctly. A network blip
  // must do the opposite — leave the painted state alone.
  group('T5 — contract violation vs network failure', () {
    const contractBreak = WaitingException(
      WaitingFailure.contractViolation,
      'offerDeadlineInSeconds absent on a live '
      'WaitingRequestPhase.broadcasting row (req-1)',
    );

    test('T5.1 — a poll violation fails the screen and stops BOTH streams', () async {
      final pollTicks = StreamController<void>.broadcast();
      final clockTicks = StreamController<void>.broadcast();
      addTearDown(pollTicks.close);
      addTearDown(clockTicks.close);
      final repo = _ScriptedWaitingRepository(
        initial: _request(),
        polls: const <WaitingRequest>[],
        pollErrors: const {0: contractBreak},
      );
      final cubit = WaitingCubit(
        repository: repo,
        requestId: 'req-1',
        now: () => _t0,
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

      expect(cubit.state.status, WaitingScreenStatus.failed);
      expect(cubit.state.error, WaitingFailure.contractViolation);
      expect(pollTicks.hasListener, isFalse);
      expect(clockTicks.hasListener, isFalse);
    });

    test('T5.2 — a cold-load violation reaches the same terminal state', () async {
      final pollTicks = StreamController<void>.broadcast();
      final clockTicks = StreamController<void>.broadcast();
      addTearDown(pollTicks.close);
      addTearDown(clockTicks.close);
      final repo = _ScriptedWaitingRepository(
        initial: _request(),
        initialError: contractBreak,
      );
      final cubit = WaitingCubit(
        repository: repo,
        requestId: 'req-1',
        now: () => _t0,
        pollTicks: pollTicks.stream,
        clockTicks: clockTicks.stream,
      );
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.status, WaitingScreenStatus.failed);
      expect(cubit.state.error, WaitingFailure.contractViolation);
      // Streams were never attached on the cold-load path, and _failContract
      // leaves nothing behind.
      expect(pollTicks.hasListener, isFalse);
      expect(clockTicks.hasListener, isFalse);
    });

    test('T5.3 — a network poll failure leaves the state untouched', () async {
      final pollTicks = StreamController<void>.broadcast();
      final clockTicks = StreamController<void>.broadcast();
      addTearDown(pollTicks.close);
      addTearDown(clockTicks.close);
      final repo = _ScriptedWaitingRepository(
        initial: _request(),
        polls: const <WaitingRequest>[],
        pollErrors: const {
          0: WaitingException(WaitingFailure.network, 'connection reset'),
        },
      );
      final cubit = WaitingCubit(
        repository: repo,
        requestId: 'req-1',
        now: () => _t0,
        pollTicks: pollTicks.stream,
        clockTicks: clockTicks.stream,
      );
      addTearDown(cubit.close);

      await cubit.load();
      final loaded = cubit.state;

      pollTicks.add(null);
      await repo.waitForPoll(1);
      await pumpEventQueue();

      expect(cubit.state.status, WaitingScreenStatus.loaded);
      expect(cubit.state.error, isNull);
      expect(cubit.state.request, loaded.request);
      expect(pollTicks.hasListener, isTrue);
      expect(clockTicks.hasListener, isTrue);
    });

    test('T5.4 — retry() after a violation recovers to a real countdown', () async {
      final pollTicks = StreamController<void>.broadcast();
      final clockTicks = StreamController<void>.broadcast();
      addTearDown(pollTicks.close);
      addTearDown(clockTicks.close);
      final repo = _ScriptedWaitingRepository(
        initial: _request(),
        initialError: contractBreak,
      );
      final cubit = WaitingCubit(
        repository: repo,
        requestId: 'req-1',
        now: () => _t0,
        pollTicks: pollTicks.stream,
        clockTicks: clockTicks.stream,
      );
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.error, WaitingFailure.contractViolation);

      // The gateway is fixed: the next read carries the contract.
      repo.initialError = null;
      repo.initial = _request(
        remainingAtReceipt: const Duration(minutes: 30),
      );
      await cubit.retry();

      expect(cubit.state.status, WaitingScreenStatus.loaded);
      expect(cubit.state.error, isNull);
      expect(cubit.state.remaining, const Duration(minutes: 30));
      expect(pollTicks.hasListener, isTrue);
      expect(clockTicks.hasListener, isTrue);
    });

    test('T5.6 — exactly one waiting_contract_violation diag event per violation', () async {
      final lines = <String>[];
      final previousSink = Diag.sink;
      final previousEnabled = Diag.enabledOverride;
      Diag.sink = lines.add;
      Diag.enabledOverride = true;
      addTearDown(() {
        Diag.sink = previousSink;
        Diag.enabledOverride = previousEnabled;
      });

      final repo = _ScriptedWaitingRepository(
        initial: _request(),
        initialError: contractBreak,
      );
      final cubit = WaitingCubit(
        repository: repo,
        requestId: 'req-1',
        now: () => _t0,
        pollTicks: const Stream.empty(),
        clockTicks: const Stream.empty(),
      );
      addTearDown(cubit.close);

      await cubit.load();

      final events = lines
          .where((l) => l.contains('waiting_contract_violation'))
          .toList();
      expect(events, hasLength(1));
      expect(events.single, contains('"requestId":"req-1"'));
      expect(events.single, contains('offerDeadlineInSeconds'));
    });
  });

  // ── T6 — anchor carry-forward through _enrichWithOffers ───────────────────
  //
  // The regression this guards: when an offer landed, the old cubit rebuilt the
  // snapshot and re-stamped the deadline, silently resetting the countdown to
  // full. `copyWith` now exposes NO receivedAt / remainingAtReceipt parameter
  // (T6.4 — the API shape IS the guarantee), so the pair can only be carried.
  group('T6 — anchor survives the offers enrich', () {
    test('T6.1/T6.2/T6.3 — the pair is carried, the countdown does not reset', () async {
      var now = _t0;
      final offers = Completer<int>();
      final repo = _ScriptedWaitingRepository(
        initial: _request(remainingAtReceipt: const Duration(minutes: 30)),
        offerCount: (_) => offers.future,
      );
      final cubit = WaitingCubit(
        repository: repo,
        requestId: 'req-1',
        now: () => now,
        pollTicks: const Stream.empty(),
        clockTicks: const Stream.empty(),
      );
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.remaining, const Duration(minutes: 30));

      // Five minutes pass on the device clock, THEN the offer lands.
      now = _t0.add(const Duration(minutes: 5));
      offers.complete(2);
      await pumpEventQueue();

      // T6.1 — anchor pair carried forward verbatim.
      expect(cubit.state.request!.receivedAt, _t0);
      expect(
        cubit.state.request!.remainingAtReceipt,
        const Duration(minutes: 30),
      );
      // T6.2 — a 30m here would be the reset-to-full regression.
      expect(cubit.state.remaining, const Duration(minutes: 25));
      // T6.3 — the enrich still did its job.
      expect(cubit.state.request!.phase, WaitingRequestPhase.offersArrived);
      expect(cubit.state.request!.offerCount, 2);
      expect(cubit.state.hasOffers, isTrue);
    });
  });
}
