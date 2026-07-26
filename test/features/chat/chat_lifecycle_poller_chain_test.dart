import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/lifecycle/app_lifecycle_gate.dart';
import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';

const _pollInterval = Duration(milliseconds: 100);

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

ChatCubit _buildCubit(_CountingPollingGateway gateway) => ChatCubit(
  deliveryId: 'conversation-1',
  gateway: gateway,
  pickerService: StubPhotoPickerService(),
  pollInterval: _pollInterval,
);

void _driveToBackground(WidgetTester tester) {
  for (final state in <AppLifecycleState>[
    AppLifecycleState.resumed,
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void _driveBackToForeground(WidgetTester tester) {
  for (final state in <AppLifecycleState>[
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

Future<void> _pumpPollIntervals(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(_pollInterval);
    await tester.pump();
  }
}

void main() {
  late WidgetsBindingAppLifecycleGate gate;

  setUp(() {
    AppLifecycleGate.debugReset();
    gate = WidgetsBindingAppLifecycleGate();
    AppLifecycleGate.install(gate);
  });

  tearDown(() {
    gate.dispose();
    AppLifecycleGate.debugReset();
  });

  testWidgets(
    'presence control: binding transitions stop then resume the chat history '
    'poller with exact tick counts',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final gateway = _CountingPollingGateway();
      final cubit = _buildCubit(gateway);
      await cubit.load();

      expect(gateway.loadHistoryCalls, 1, reason: 'initial load attempt only');
      expect(cubit.debugHistoryTickCount, isZero);
      expect(cubit.debugHistoryPollerRunning, isTrue);
      expect(AppLifecycleGate.debugListenerCount, 1);

      await _pumpPollIntervals(tester, 2);
      expect(cubit.debugHistoryTickCount, 2);
      expect(gateway.loadHistoryCalls, 3);

      _driveToBackground(tester);
      expect(cubit.debugHistoryPollerRunning, isFalse);
      expect(cubit.debugHistoryTickCount, 2);

      await _pumpPollIntervals(tester, 2);
      expect(cubit.debugHistoryTickCount, 2);
      expect(gateway.loadHistoryCalls, 3);

      _driveBackToForeground(tester);
      expect(cubit.debugHistoryPollerRunning, isTrue);
      expect(
        cubit.debugHistoryTickCount,
        2,
        reason: 'tickOnResume false must not fetch on the resume edge',
      );
      expect(gateway.loadHistoryCalls, 3);

      await _pumpPollIntervals(tester, 1);
      expect(cubit.debugHistoryTickCount, 3);
      expect(gateway.loadHistoryCalls, 4);

      await cubit.close();
      expect(cubit.debugHistoryPollerRunning, isFalse);
      expect(AppLifecycleGate.debugListenerCount, isZero);
    },
  );

  testWidgets(
    'absence control: the full binding background chain leaves zero further '
    'chat history ticks and no armed timer',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final gateway = _CountingPollingGateway();
      final cubit = _buildCubit(gateway);
      await cubit.load();
      await _pumpPollIntervals(tester, 1);

      expect(cubit.debugHistoryTickCount, 1);
      expect(gateway.loadHistoryCalls, 2);
      expect(cubit.debugHistoryPollerRunning, isTrue);

      _driveToBackground(tester);
      final ticksAtBackground = cubit.debugHistoryTickCount;
      final readsAtBackground = gateway.loadHistoryCalls;

      expect(cubit.debugHistoryPollerRunning, isFalse);
      await _pumpPollIntervals(tester, 3);
      expect(cubit.debugHistoryTickCount, ticksAtBackground);
      expect(gateway.loadHistoryCalls, readsAtBackground);
      expect(cubit.debugHistoryPollerRunning, isFalse);

      await cubit.close();
      expect(AppLifecycleGate.debugListenerCount, isZero);
    },
  );
}
