// N4 (b02 polling→push). This file used to assert that the 60 s chat history
// poll "keeps its unconditional lifecycle degrade when no gate is installed" —
// i.e. that with no `AppLifecycleGate` on the root, a started poller ticks
// exactly like a bare `Timer.periodic`.
//
// That poll is DELETED. The property worth keeping from the original is the
// root-free one: `ChatCubit` must behave identically with and without a gate
// installed, because bare `test()` bodies and fixture hosts have no root. What
// it must now do in BOTH cases is arm NOTHING.
//
// The inverted assertion is deliberate and is the point: `async.periodicTimerCount`
// is checked WHILE THE THREAD IS HEALTHY, not only after `close()`. A check that
// only runs post-dispose cannot tell "there was never a timer" from "the timer
// was cleaned up properly", and leg 1 of the four-leg bar asks for the first.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/lifecycle/app_lifecycle_gate.dart';
import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';

/// Five minutes: long enough to swallow the retired 60 s cadence five times.
const _idleWindow = Duration(minutes: 5);

class _CountingPollingGateway extends ChatGateway {
  int loadHistoryCalls = 0;

  @override
  bool get supportsPolling => true;

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String conversationId) async {
    loadHistoryCalls++;
    return const <DeliveryChatMessage>[];
  }

  @override
  Future<DeliveryChatMessage> send(
    String conversationId,
    DeliveryChatMessage message,
  ) async => message;

  @override
  Stream<ChatEvent> subscribe(String conversationId) =>
      const Stream<ChatEvent>.empty();
}

void main() {
  setUp(AppLifecycleGate.debugReset);
  tearDown(AppLifecycleGate.debugReset);

  test('root-free: a HEALTHY chat thread arms no periodic timer at all, with '
      'no gate installed', () {
    FakeAsync().run((async) {
      final gateway = _CountingPollingGateway();
      final bus = StreamController<void>.broadcast();
      final cubit = ChatCubit(
        deliveryId: 'conversation-1',
        gateway: gateway,
        pickerService: StubPhotoPickerService(),
        refreshSignals: bus.stream,
      );
      var loaded = false;
      cubit.load().then((_) => loaded = true);
      async.elapse(Duration.zero);
      async.flushMicrotasks();

      expect(loaded, isTrue);
      expect(gateway.loadHistoryCalls, 1, reason: 'the mount one-shot');
      expect(
        async.periodicTimerCount,
        isZero,
        reason: 'leg 1: no periodic timer exists while the thread is rendering',
      );
      expect(cubit.debugHistoryRetryArmed, isFalse);

      async.elapse(_idleWindow);
      async.flushMicrotasks();
      expect(
        gateway.loadHistoryCalls,
        1,
        reason: 'five idle minutes with no push must be ZERO reads',
      );

      // POSITIVE CONTROL — the harness can still observe a read, so the zero
      // above is silence and not a dead double.
      bus.add(null);
      async.flushMicrotasks();
      expect(gateway.loadHistoryCalls, 2);

      unawaited(cubit.close());
      unawaited(bus.close());
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();

      expect(AppLifecycleGate.debugListenerCount, isZero);
      expect(async.periodicTimerCount, isZero);
    });
  });
}
