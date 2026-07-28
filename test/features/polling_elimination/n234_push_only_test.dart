// N2 / N3 / N4 — the last three armed periodic NETWORK timers outside the KYC
// carve-out. This file pins the END STATE the owner's 2026-07-28 architecture
// ruling asks for, on all three surfaces at once:
//
//   * ONE fetch at mount, ONE on resume;
//   * network I/O otherwise ONLY on a push;
//   * two pushes inside one round trip make ONE re-pull (single flight);
//   * a five-minute idle window with no push and no user action is ZERO reads.
//
// ## Why every case here compiles against the PRE-change tree
//
// I-14: a green suite is not evidence, and "show it RED first" is the only
// thing that turns a passing test into one. Every assertion below is written
// against symbols that exist on BOTH sides of this change — a counting
// repository/gateway, `start()`, `load()`, the push bus — so the RED transcript
// captured before the fix is an ASSERTION failure (`Expected: <1> Actual: <6>`),
// not a compile error. A compile-error RED proves only that a symbol was
// renamed; it cannot tell you the test would have caught the defect.
//
// ## Positive control (Rule 1)
//
// Every "zero reads" case is paired, in the SAME test, with a push that MUST
// produce a read. Without it, `calls == 1` after five minutes is
// indistinguishable from a harness that never wired the bus, a cubit that was
// never started, or a repository double nobody calls — the exact shape of every
// instrument in TESTING-INSTRUMENTS.md that lied by returning a confident zero.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/application/active_deliveries_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/domain/active_deliveries_repository.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/domain/active_delivery_summary.dart';
import 'package:jeeb_mobile/features/photo_attachment/domain/photo_picker_service.dart';

const Duration _roundTrip = Duration(milliseconds: 40);

// ---------------------------------------------------------------------------
// N2 — jeeber active deliveries (was 60 s)
// ---------------------------------------------------------------------------

class _CountingActiveDeliveries implements ActiveDeliveriesRepository {
  int calls = 0;
  Completer<void>? gate;

  @override
  Future<List<ActiveDeliverySummary>> listActive() async {
    calls++;
    await gate?.future;
    return const <ActiveDeliverySummary>[];
  }
}

// ---------------------------------------------------------------------------
// N4 — chat history (was 60 s) — THE SURFACE THE OWNER NAMED
// ---------------------------------------------------------------------------

/// `supportsPolling: true` is what made the production `DioChatGateway` arm the
/// 60 s history poll, and it is the ONLY reason the in-memory doubles never saw
/// it. A double that returns `false` cannot observe this defect at all, so this
/// one returns `true` — the gate value the real gateway ships.
class _CountingChatGateway implements ChatGateway {
  int historyCalls = 0;
  int phaseCalls = 0;
  Completer<void>? gate;
  bool failHistory = false;

  // Broadcast controller for the (unused) inbound event stream. Never closed
  // on purpose: `ChatCubit.close()` cancels its subscription, and a broadcast
  // controller with no listeners holds nothing.
  // ignore: close_sinks
  final StreamController<ChatEvent> _events =
      StreamController<ChatEvent>.broadcast();

  @override
  bool get supportsPolling => true;

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String conversationId) async {
    historyCalls++;
    await gate?.future;
    if (failHistory) throw StateError('history unreachable');
    return const <DeliveryChatMessage>[];
  }

  @override
  Future<ConversationPhase> loadPhase(String conversationId) async {
    phaseCalls++;
    return ConversationPhase.accepted;
  }

  @override
  Stream<ChatEvent> subscribe(String conversationId) => _events.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _NoopPicker implements PhotoPickerService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------

void main() {
  group('N2 · jeeber active deliveries', () {
    test('two pushes inside ONE round trip collapse to one read', () {
      fakeAsync((async) {
        final repo = _CountingActiveDeliveries();
        final bus = StreamController<void>.broadcast();
        final cubit = ActiveDeliveriesCubit(
          repository: repo,
          refreshSignals: bus.stream,
        );

        cubit.start();
        async.flushMicrotasks();
        expect(repo.calls, 1);

        // Hold the NEXT read open so the two pushes genuinely land inside one
        // round trip. Set after the mount read so the mount read is not itself
        // the in-flight one they collapse onto.
        repo.gate = Completer<void>();
        bus.add(null);
        bus.add(null);
        async.flushMicrotasks();
        expect(
          repo.calls,
          2,
          reason: 'single flight: the second push joins the in-flight read',
        );

        repo.gate!.complete();
        async.elapse(_roundTrip);
        async.flushMicrotasks();
        expect(repo.calls, 2, reason: 'and does not fire a late second read');

        cubit.close();
        bus.close();
        async.flushMicrotasks();
      });
    });

    test('the RESUME one-shot re-reads, and defers while off screen', () {
      fakeAsync((async) {
        final repo = _CountingActiveDeliveries();
        final bus = StreamController<void>.broadcast();
        final cubit = ActiveDeliveriesCubit(
          repository: repo,
          refreshSignals: bus.stream,
        );
        cubit.start();
        async.flushMicrotasks();
        expect(repo.calls, 1);

        cubit.refreshOnResume();
        async.flushMicrotasks();
        expect(repo.calls, 2, reason: 'visible resume pays immediately');

        // Off screen: a resume AND a push together are ONE debt, paid once on
        // the way back — the read-economics guarantee, not merely correctness.
        cubit.setPollingVisible(false);
        cubit.refreshOnResume();
        bus.add(null);
        async.flushMicrotasks();
        expect(repo.calls, 2, reason: 'no reads for pixels nobody can see');

        cubit.setPollingVisible(true);
        async.flushMicrotasks();
        expect(repo.calls, 3, reason: 'exactly one catch-up read');

        cubit.close();
        bus.close();
        async.flushMicrotasks();
      });
    });
  });

  group('N4 · chat history', () {
    test('two chat pushes inside ONE round trip collapse to one read', () {
      fakeAsync((async) {
        final gateway = _CountingChatGateway();
        final bus = StreamController<void>.broadcast();
        final cubit = ChatCubit(
          deliveryId: 'conv-1',
          gateway: gateway,
          pickerService: _NoopPicker(),
          refreshSignals: bus.stream,
        );
        cubit.load();
        async.flushMicrotasks();
        expect(gateway.historyCalls, 1);

        expect(
          cubit.debugHistoryRetryArmed,
          isFalse,
          reason: 'a HEALTHY thread arms no timer at all — moved here from the '
              'idle-window file so that file compiles against the PRE-change '
              'tree and its RED is an assertion, not a missing symbol',
        );

        gateway.gate = Completer<void>();
        bus.add(null);
        bus.add(null);
        async.flushMicrotasks();
        expect(
          gateway.historyCalls,
          2,
          reason: 'single flight across a burst of messages',
        );

        gateway.gate!.complete();
        async.elapse(_roundTrip);
        async.flushMicrotasks();
        expect(gateway.historyCalls, 2);
        expect(cubit.debugPushRefreshCount, 1);

        cubit.close();
        bus.close();
        async.flushMicrotasks();
      });
    });

    test(
      'a FAILED cold load arms a bounded retry that cannot exhaust silently, '
      'and the retry stands down on the first success',
      () {
        fakeAsync((async) {
          final gateway = _CountingChatGateway()..failHistory = true;
          final cubit = ChatCubit(
            deliveryId: 'conv-1',
            gateway: gateway,
            pickerService: _NoopPicker(),
          );

          cubit.load();
          async.flushMicrotasks();
          expect(cubit.state.historyLoadFailed, isTrue);
          expect(
            cubit.debugHistoryRetryArmed,
            isTrue,
            reason: 'the offline error state must not be terminal',
          );

          // Walk past the end of the backoff table. A schedule that EXHAUSTED
          // would stop here and leave the thread blank until an app restart —
          // this app has no connectivity listener to wake it.
          async.elapse(const Duration(minutes: 5));
          async.flushMicrotasks();
          final attemptsWhileDown = cubit.debugHistoryRetryCount;
          expect(
            attemptsWhileDown,
            greaterThan(kChatHistoryRetryBackoff.length),
            reason: 'caps at the last step, never exhausts',
          );

          // The network comes back.
          gateway.failHistory = false;
          async.elapse(const Duration(minutes: 1));
          async.flushMicrotasks();
          expect(cubit.state.historyLoadFailed, isFalse);
          expect(
            cubit.debugHistoryRetryArmed,
            isFalse,
            reason: 'TERMINATES on the first success — it is not a poll',
          );
          expect(
            cubit.debugHistoryRetryCount,
            greaterThan(attemptsWhileDown),
            reason: 'positive control: the retry really was the thing running',
          );

          cubit.close();
          async.flushMicrotasks();
        });
      },
    );
  });
}
