// Regression: BUG-chat-cache-staleness.
//
// A chat-detail thread left open while the app is backgrounded retains its
// screen-scoped [ChatCubit] in memory (the OS did not kill the process), so the
// one-shot create-time [ChatCubit.load] never re-runs. Any messages the
// counterpart sent while we were away stayed invisible until an app restart.
//
// The fix adds:
//   1. [ChatCubit.refresh] — a non-destructive re-fetch of history + phase that
//      surfaces messages that arrived since [load], preserves the visible
//      thread on a transient failure, and never re-opens the inbound stream.
//   2. A [WidgetsBindingObserver] on the chat scaffold that calls [refresh] on
//      `AppLifecycleState.resumed`, so the thread is never stale within a live
//      session.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/chat/presentation/chat_screen.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';

import '../../support/sync_app_localizations.dart';

/// Gateway double whose history can change between calls (simulating the server
/// gaining new messages while the app is backgrounded) and that counts every
/// [loadHistory] / [subscribe] call so the test can assert refetch behaviour.
class _MutableHistoryGateway extends ChatGateway {
  _MutableHistoryGateway(this._history);

  List<DeliveryChatMessage> _history;
  int loadHistoryCalls = 0;
  int subscribeCalls = 0;
  bool failNextHistory = false;

  final StreamController<ChatEvent> _events =
      StreamController<ChatEvent>.broadcast();

  void setHistory(List<DeliveryChatMessage> next) => _history = next;

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String conversationId) async {
    loadHistoryCalls++;
    if (failNextHistory) {
      failNextHistory = false;
      throw StateError('transient network failure');
    }
    return List<DeliveryChatMessage>.from(_history);
  }

  @override
  Future<DeliveryChatMessage> send(
    String conversationId,
    DeliveryChatMessage message,
  ) async =>
      message.copyWith(status: MessageStatus.sent);

  @override
  Stream<ChatEvent> subscribe(String conversationId) {
    subscribeCalls++;
    return _events.stream;
  }

  Future<void> dispose() => _events.close();
}

DeliveryChatMessage _msg(String id, String text) => DeliveryChatMessage.text(
      id: id,
      author: ChatAuthor.them,
      sentAt: DateTime(2026, 6, 30, 11),
      status: MessageStatus.delivered,
      text: text,
    );

ChatCubit _cubit(_MutableHistoryGateway gateway) {
  final cubit = ChatCubit(
    deliveryId: 'conv-1',
    gateway: gateway,
    pickerService: StubPhotoPickerService(),
    clock: () => DateTime(2026, 6, 30, 12),
  );
  addTearDown(cubit.close);
  addTearDown(gateway.dispose);
  return cubit;
}

void main() {
  group('ChatCubit.refresh', () {
    test('surfaces messages that arrived on the server since load', () async {
      final gateway = _MutableHistoryGateway([_msg('m1', 'first')]);
      final cubit = _cubit(gateway);

      await cubit.load();
      expect(cubit.state.messages.map((m) => m.text), ['first']);
      expect(gateway.loadHistoryCalls, 1);

      // Server gains a newer message while the screen is retained in memory.
      gateway.setHistory([_msg('m1', 'first'), _msg('m2', 'second')]);

      await cubit.refresh();

      expect(
        cubit.state.messages.map((m) => m.text),
        ['first', 'second'],
        reason: 'refresh must replace the stale thread with fresh history',
      );
      expect(gateway.loadHistoryCalls, 2);
    });

    test('keeps the visible thread on a transient refresh failure', () async {
      final gateway = _MutableHistoryGateway([_msg('m1', 'first')]);
      final cubit = _cubit(gateway);

      await cubit.load();
      gateway.failNextHistory = true;

      await cubit.refresh();

      expect(
        cubit.state.messages.map((m) => m.text),
        ['first'],
        reason: 'a failed refresh must not blank an already-loaded thread',
      );
    });

    test('does not re-open the inbound subscription', () async {
      final gateway = _MutableHistoryGateway(const []);
      final cubit = _cubit(gateway);

      await cubit.load();
      expect(gateway.subscribeCalls, 1);

      await cubit.refresh();
      await cubit.refresh();

      expect(
        gateway.subscribeCalls,
        1,
        reason: 'refresh reuses the subscription established by load',
      );
    });
  });

  group('ChatScreen lifecycle', () {
    testWidgets('refetches the open thread when the app resumes',
        (tester) async {
      final gateway = _MutableHistoryGateway([_msg('m1', 'hi')]);
      addTearDown(gateway.dispose);

      await tester.pumpWidget(
        wrapForTest(
          ChatScreen(
            deliveryId: 'conv-1',
            counterpartName: 'Sam',
            gateway: gateway,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(gateway.loadHistoryCalls, 1, reason: 'cold mount loads once');

      // Simulate background → foreground.
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(
        gateway.loadHistoryCalls,
        2,
        reason: 'resuming the app must trigger a fresh history fetch',
      );
    });
  });
}
