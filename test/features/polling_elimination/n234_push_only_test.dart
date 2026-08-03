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

/// `supportsPolling: true` is what made the production `DioChatGateway` arm the
class _CountingChatGateway implements ChatGateway {
  int historyCalls = 0;
  int phaseCalls = 0;
  Completer<void>? gate;
  bool failHistory = false;

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

          async.elapse(const Duration(minutes: 5));
          async.flushMicrotasks();
          final attemptsWhileDown = cubit.debugHistoryRetryCount;
          expect(
            attemptsWhileDown,
            greaterThan(kChatHistoryRetryBackoff.length),
            reason: 'caps at the last step, never exhausts',
          );

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
