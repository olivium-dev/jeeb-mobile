// b02 polling→push: a chat PUSH must drive the OPEN chat thread.
//
// WHAT WAS BROKEN. `ChatCubit` took no push/refresh input of any kind.
// `PushRefreshSignals` was wired into `home_tab`, `client_home_cubit` and
// `request_feed_cubit` — never into chat. On the deployed build a chat push
// landed at 18:44:29Z and triggered NO fetch, while
// `GET /v1/conversations/{id}/messages` kept ticking at exactly 60.0s on a
// fixed phase (18:45:02.512, 18:46:02.514, 18:47:02.512). The 60s safety-net
// poll was the ONLY inbound HTTP path, and it is deleted in the follow-up
// commit — which is only safe if these tests hold.
//
// Every gateway here has `supportsPolling == false`, so NO timer exists in any
// of these tests. That is deliberate: it makes the push the only thing that
// could possibly produce a fetch, so a passing assertion cannot be a poll tick
// wearing a push's clothes.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';

/// Gateway that COUNTS history reads and can be made to hang, so the tests can
/// assert both "how many reads" and "what happens to a read that overlaps".
class _CountingGateway extends ChatGateway {
  _CountingGateway(this.history);

  List<DeliveryChatMessage> history;
  int historyReads = 0;
  int phaseReads = 0;

  /// When non-null, `loadHistory` parks on this completer instead of returning
  /// — the seam for the single-flight (burst) test.
  Completer<void>? gate;

  final _controller = StreamController<ChatEvent>.broadcast();

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String conversationId) async {
    historyReads++;
    final g = gate;
    if (g != null) await g.future;
    return List<DeliveryChatMessage>.from(history);
  }

  @override
  Future<ConversationPhase> loadPhase(String conversationId) async {
    phaseReads++;
    return ConversationPhase.accepted;
  }

  @override
  Future<DeliveryChatMessage> send(
    String conversationId,
    DeliveryChatMessage message,
  ) async =>
      message.copyWith(status: MessageStatus.sent);

  @override
  Stream<ChatEvent> subscribe(String conversationId) => _controller.stream;

  Future<void> dispose() => _controller.close();
}

DeliveryChatMessage _them(String id, String text, {int minute = 30}) =>
    DeliveryChatMessage.text(
      id: id,
      author: ChatAuthor.them,
      sentAt: DateTime(2026, 7, 26, 18, minute),
      status: MessageStatus.delivered,
      text: text,
    );

DeliveryChatMessage _me(
  String id,
  String text, {
  int minute = 31,
  MessageStatus status = MessageStatus.sent,
}) =>
    DeliveryChatMessage.text(
      id: id,
      author: ChatAuthor.me,
      sentAt: DateTime(2026, 7, 26, 18, minute),
      status: status,
      text: text,
    );

ChatCubit _build(
  _CountingGateway gateway, {
  Stream<void>? signals,
}) =>
    ChatCubit(
      deliveryId: 'conv-1',
      gateway: gateway,
      pickerService: StubPhotoPickerService(),
      refreshSignals: signals,
    );

void main() {
  group('chat push drives the open thread', () {
    test('a push signal produces exactly ONE targeted re-pull', () async {
      final gateway = _CountingGateway(<DeliveryChatMessage>[
        _them('m1', 'first'),
      ]);
      final bus = StreamController<void>.broadcast();
      final cubit = _build(gateway, signals: bus.stream);

      await cubit.load();
      expect(gateway.historyReads, 1, reason: 'the cold load');
      expect(cubit.debugPushRefreshWired, isTrue);

      // The counterpart's new line lands on the server. Nothing on the device
      // knows yet: there is no poll and the WS stream never emits.
      gateway.history = <DeliveryChatMessage>[
        _them('m1', 'first'),
        _them('m2', 'nonce-7f3a'),
      ];
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.messages.map((m) => m.id), <String>['m1'],
          reason: 'no fetch without a push — this is the negative control');

      bus.add(null);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(gateway.historyReads, 2, reason: 'exactly one push-driven read');
      expect(cubit.debugPushRefreshCount, 1);
      expect(
        cubit.state.messages.map((m) => m.text).toList(),
        containsAll(<String>['first', 'nonce-7f3a']),
      );

      await cubit.close();
      await bus.close();
      await gateway.dispose();
    });

    test('a burst of pushes inside one round-trip collapses to ONE read',
        () async {
      final gateway = _CountingGateway(<DeliveryChatMessage>[_them('m1', 'a')]);
      final bus = StreamController<void>.broadcast();
      final cubit = _build(gateway, signals: bus.stream);

      await cubit.load();
      expect(gateway.historyReads, 1);

      // Park the next read so three signals arrive while it is outstanding.
      final gate = Completer<void>();
      gateway.gate = gate;

      bus
        ..add(null)
        ..add(null)
        ..add(null);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(gateway.historyReads, 2,
          reason: 'three signals, one in-flight read');
      expect(cubit.debugPushRefreshCount, 1);

      gateway.gate = null;
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // The latch clears, so a LATER push still fetches.
      bus.add(null);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(gateway.historyReads, 3);
      expect(cubit.debugPushRefreshCount, 2);

      await cubit.close();
      await bus.close();
      await gateway.dispose();
    });

    test('the push-driven refetch RECONCILES — read receipts keep advancing',
        () async {
      // The receipt path folds the server echo into the optimistic bubble (the
      // double-tick). A push-driven refetch that replaced the list instead
      // would strand own bubbles at `sending` forever and drop any the server
      // has not echoed yet.
      final gateway = _CountingGateway(<DeliveryChatMessage>[
        _them('m1', 'hi'),
      ]);
      final bus = StreamController<void>.broadcast();
      final cubit = _build(gateway, signals: bus.stream);

      await cubit.load();
      cubit.composerChanged('my line');
      await cubit.sendText();
      final own = cubit.state.messages.firstWhere((m) => m.text == 'my line');
      expect(own.author, ChatAuthor.me);

      // Server echo of that own message, now READ by the counterpart, plus a
      // fresh inbound line.
      gateway.history = <DeliveryChatMessage>[
        _them('m1', 'hi'),
        _me('srv-1', 'my line', status: MessageStatus.read),
        _them('m2', 'nonce-b19c'),
      ];

      bus.add(null);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final texts = cubit.state.messages.map((m) => m.text).toList();
      expect(texts.where((t) => t == 'my line').length, 1,
          reason: 'the echo folded onto the optimistic bubble, not beside it');
      expect(
        cubit.state.messages.firstWhere((m) => m.text == 'my line').status,
        MessageStatus.read,
        reason: 'the receipt advanced through the push-driven refetch',
      );
      expect(texts, contains('nonce-b19c'));

      await cubit.close();
      await bus.close();
      await gateway.dispose();
    });

    test('no bus wired (bare test / DI absent) → no push-driven read, no throw',
        () async {
      final gateway = _CountingGateway(<DeliveryChatMessage>[_them('m1', 'a')]);
      final cubit = _build(gateway);

      await cubit.load();
      expect(cubit.debugPushRefreshWired, isFalse);
      expect(gateway.historyReads, 1);

      await Future<void>.delayed(Duration.zero);
      expect(gateway.historyReads, 1);
      expect(cubit.debugPushRefreshCount, 0);

      await cubit.close();
      await gateway.dispose();
    });

    test('a signal after close() drives nothing', () async {
      final gateway = _CountingGateway(<DeliveryChatMessage>[_them('m1', 'a')]);
      final bus = StreamController<void>.broadcast();
      final cubit = _build(gateway, signals: bus.stream);

      await cubit.load();
      await cubit.close();

      bus.add(null);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(gateway.historyReads, 1, reason: 'subscription cancelled');

      await bus.close();
      await gateway.dispose();
    });
  });
}
