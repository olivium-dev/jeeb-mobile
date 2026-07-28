// N4 (b02 polling→push). This file used to walk the real
// `WidgetsBindingAppLifecycleGate` chain — resumed → inactive → hidden → paused
// and back — and assert EXACT tick counts on the 60 s chat history poller
// either side of it (`tickOnResume: false` must not fetch on the resume edge,
// a backgrounded poller must be disarmed, and so on).
//
// That poller is DELETED, so every one of those assertions is about a thing
// that no longer exists. What survives — and is the sharper property — is that
// the SAME binding chain now produces ZERO reads in both directions, and that
// the cubit registers no lifecycle listener at all, because it has nothing to
// gate.
//
// The `AppLifecycleGate.debugListenerCount` assertions are kept and INVERTED.
// They are the load-bearing ones: a `LifecyclePoller` subscribes to the gate,
// so `debugListenerCount == 0` on a live cubit is direct, structural evidence
// that no poller was constructed — evidence a read-count assertion alone
// cannot give (a poll whose reads all happened to fail would look identical).

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/lifecycle/app_lifecycle_gate.dart';
import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';

/// The retired cadence, used only to pump PAST it many times over.
const _retiredCadence = Duration(seconds: 60);

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

ChatCubit _buildCubit(
  _CountingPollingGateway gateway,
  Stream<void> signals,
) => ChatCubit(
  deliveryId: 'conversation-1',
  gateway: gateway,
  pickerService: StubPhotoPickerService(),
  refreshSignals: signals,
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

Future<void> _pumpRetiredCadences(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(_retiredCadence);
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
    'the full binding chain — foreground, background and back — produces ZERO '
    'reads, and the cubit holds no lifecycle listener because it holds no '
    'poller',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final gateway = _CountingPollingGateway();
      final bus = StreamController<void>.broadcast();
      final cubit = _buildCubit(gateway, bus.stream);
      // NOT `await cubit.load()`. Under `testWidgets` the binding owns the
      // clock, and awaiting a cubit future directly in the test body can park
      // forever when nothing pumps a frame to drain it — this test hung for the
      // full 10-minute timeout that way. Drive it with pumps instead, which is
      // what every other widget-level case here does.
      unawaited(cubit.load());
      await tester.pump();
      await tester.pump();

      expect(gateway.loadHistoryCalls, 1, reason: 'the mount one-shot');
      expect(
        AppLifecycleGate.debugListenerCount,
        isZero,
        reason: 'structural leg 1: a LifecyclePoller would have registered here',
      );

      await _pumpRetiredCadences(tester, 3);
      expect(gateway.loadHistoryCalls, 1, reason: 'three retired cadences: 0');

      _driveToBackground(tester);
      await _pumpRetiredCadences(tester, 3);
      expect(gateway.loadHistoryCalls, 1);

      _driveBackToForeground(tester);
      await _pumpRetiredCadences(tester, 3);
      expect(
        gateway.loadHistoryCalls,
        1,
        reason: 'the app resuming does NOT drive this cubit — the resume '
            'one-shot lives in _ChatScaffoldState.onAppResumed, above it',
      );

      // POSITIVE CONTROL. Without this the run above is indistinguishable from
      // a cubit that was never loaded and a gateway nobody holds.
      bus.add(null);
      await tester.pump();
      expect(gateway.loadHistoryCalls, 2, reason: 'push drives one re-pull');

      unawaited(cubit.close());
      unawaited(bus.close());
      await tester.pump();
      expect(AppLifecycleGate.debugListenerCount, isZero);
    },
  );
}
