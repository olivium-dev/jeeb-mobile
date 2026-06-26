// Sprint-7 chat step: the HTTP-history POLL fallback in [ChatCubit].
//
// The live transport is the WS subscription, but against the mock backend (and
// any flaky / unauthorized socket) the stream may never emit. The poll fallback
// re-pulls history on an interval and merges inbound (counterpart/system)
// messages the socket missed — so "live receive" still works with zero frames.
//
// These tests use a fake gateway whose `subscribe` stream NEVER emits (a dead
// WS) and a tiny poll interval, then assert the cubit surfaces a new
// counterpart message via the poll, skips the local user's own messages, and
// dedupes against a message already delivered over the (test-pushed) stream.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/application/chat_cubit.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';

/// Gateway whose history is mutable (so the test can "land" a server message)
/// and whose subscribe stream is controllable (defaults to a dead WS — never
/// emits — so the poll is the ONLY inbound path under test).
class _PollGateway extends ChatGateway {
  _PollGateway(this.history);

  List<DeliveryChatMessage> history;
  final _controller = StreamController<ChatEvent>.broadcast();

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String conversationId) async =>
      List<DeliveryChatMessage>.from(history);

  @override
  Future<DeliveryChatMessage> send(
    String conversationId,
    DeliveryChatMessage message,
  ) async =>
      message.copyWith(status: MessageStatus.sent);

  @override
  Stream<ChatEvent> subscribe(String conversationId) => _controller.stream;

  // Opt into the poll fallback — this stands in for the real network gateway.
  @override
  bool get supportsPolling => true;

  void push(ChatEvent event) => _controller.add(event);
}

DeliveryChatMessage _them(String id, String text) => DeliveryChatMessage.text(
      id: id,
      author: ChatAuthor.them,
      sentAt: DateTime(2026, 6, 26, 10, 30),
      status: MessageStatus.delivered,
      text: text,
    );

DeliveryChatMessage _me(String id, String text) => DeliveryChatMessage.text(
      id: id,
      author: ChatAuthor.me,
      sentAt: DateTime(2026, 6, 26, 10, 31),
      status: MessageStatus.sent,
      text: text,
    );

ChatCubit _build(_PollGateway gateway) {
  final cubit = ChatCubit(
    deliveryId: 'conv-1',
    gateway: gateway,
    pickerService: StubPhotoPickerService(),
    pollInterval: const Duration(milliseconds: 20),
  );
  addTearDown(cubit.close);
  return cubit;
}

void main() {
  group('ChatCubit — HTTP-history poll fallback (sprint-7)', () {
    test('a counterpart message that lands server-side appears via the poll '
        '(no WS frame)', () async {
      final gateway = _PollGateway(const <DeliveryChatMessage>[]);
      final cubit = _build(gateway);
      await cubit.load();
      expect(cubit.state.messages, isEmpty);

      // The other participant posts; the dead WS never delivers it.
      gateway.history = [_them('srv-1', 'hello from the other side')];

      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(
        cubit.state.messages.map((m) => m.id),
        contains('srv-1'),
        reason: 'poll fallback should surface the inbound message',
      );
    });

    test('poll does NOT merge the local user\'s own messages', () async {
      // Start from empty history, then a server echo of our own message
      // (author == me) appears in a later poll. The poll merge must SKIP it —
      // the send path owns own-bubbles (they carry client ids), so merging the
      // server echo would duplicate the bubble.
      final gateway = _PollGateway(const <DeliveryChatMessage>[]);
      final cubit = _build(gateway);
      await cubit.load();
      expect(cubit.state.messages, isEmpty);

      gateway.history = [_me('srv-echo', 'mine')];
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(
        cubit.state.messages.where((m) => m.id == 'srv-echo'),
        isEmpty,
        reason: 'own-authored messages are not merged by the poll',
      );
    });

    test('poll dedupes a message already delivered over the WS stream',
        () async {
      final gateway = _PollGateway(const <DeliveryChatMessage>[]);
      final cubit = _build(gateway);
      await cubit.load();

      // WS delivers srv-2 first...
      gateway.push(IncomingMessage(_them('srv-2', 'live')));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      // ...and the same message is also present in the polled history.
      gateway.history = [_them('srv-2', 'live')];

      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(
        cubit.state.messages.where((m) => m.id == 'srv-2').length,
        1,
        reason: 'the same server id must appear exactly once',
      );
    });

    test('poll timer is cancelled on close (no inbound after dispose)',
        () async {
      final gateway = _PollGateway(const <DeliveryChatMessage>[]);
      final cubit = ChatCubit(
        deliveryId: 'conv-1',
        gateway: gateway,
        pickerService: StubPhotoPickerService(),
        pollInterval: const Duration(milliseconds: 20),
      );
      await cubit.load();
      await cubit.close();

      // Land a message AFTER close — the cancelled timer must never fire.
      gateway.history = [_them('srv-after-close', 'too late')];
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(cubit.state.messages, isEmpty);
    });
  });
}
