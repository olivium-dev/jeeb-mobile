import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/lifecycle/app_lifecycle_gate.dart';
import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';

const _pollInterval = Duration(seconds: 5);

class _CountingPollingGateway extends ChatGateway {
  int loadHistoryCalls = 0;

  @override
  bool get supportsPolling => true;

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String conversationId) async {
    loadHistoryCalls++;
    if (loadHistoryCalls == 1) {
      throw StateError('initial history unavailable');
    }
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

  test('root-free: the chat history poll keeps its unconditional lifecycle '
      'degrade when no gate is installed', () {
    FakeAsync().run((async) {
      final gateway = _CountingPollingGateway();
      final cubit = ChatCubit(
        deliveryId: 'conversation-1',
        gateway: gateway,
        pickerService: StubPhotoPickerService(),
        pollInterval: _pollInterval,
      );
      var loaded = false;
      cubit.load().then((_) => loaded = true);
      async.flushMicrotasks();

      expect(loaded, isTrue);
      expect(gateway.loadHistoryCalls, 1, reason: 'initial load attempt only');
      expect(cubit.debugHistoryTickCount, isZero);
      expect(cubit.debugHistoryPollerRunning, isTrue);

      for (var i = 0; i < 3; i++) {
        async.elapse(_pollInterval);
        async.flushMicrotasks();
      }

      expect(cubit.debugHistoryTickCount, 3);
      expect(gateway.loadHistoryCalls, 4);
      expect(cubit.debugHistoryPollerRunning, isTrue);

      var closed = false;
      cubit.close().then((_) => closed = true);
      async.flushMicrotasks();

      expect(closed, isTrue);
      expect(cubit.debugHistoryPollerRunning, isFalse);
      expect(AppLifecycleGate.debugListenerCount, isZero);
      expect(async.periodicTimerCount, isZero);
    });
  });
}
