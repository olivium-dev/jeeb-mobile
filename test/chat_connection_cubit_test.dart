import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/application/chat_connection_cubit.dart';
import 'package:jeeb_mobile/features/chat/application/reconnect_policy.dart';
import 'package:jeeb_mobile/features/chat/data/in_memory_chat_outbox.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_message.dart';
import 'package:jeeb_mobile/features/chat/domain/connection_status.dart';

import 'support/fake_chat_socket.dart';

ChatConnectionCubit _buildCubit({
  required List<FakeChatSocket> sockets,
  InMemoryChatOutbox? outbox,
  ReconnectPolicy policy = const ReconnectPolicy(
    initialDelay: Duration(milliseconds: 10),
    maxDelay: Duration(milliseconds: 40),
    multiplier: 2.0,
  ),
  int startId = 1,
}) {
  var idx = 0;
  var counter = startId - 1;
  return ChatConnectionCubit(
    socketFactory: () {
      if (idx >= sockets.length) {
        throw StateError('Test ran out of pre-seeded sockets');
      }
      return sockets[idx++];
    },
    outbox: outbox ?? InMemoryChatOutbox(),
    currentUserId: 'me',
    policy: policy,
    clock: () => DateTime.utc(2026, 5, 17, 12, 0),
    idGenerator: () {
      counter++;
      return 'c-$counter';
    },
  );
}

void main() {
  group('start()', () {
    test('hydrates the outbox and reaches connected', () async {
      final socket = FakeChatSocket();
      final outbox = InMemoryChatOutbox([
        ChatMessage(
          clientId: 'old-1',
          conversationId: 'conv',
          senderId: 'me',
          body: 'queued before start',
          createdAt: DateTime.utc(2026, 5, 17),
        ),
      ]);
      final cubit = _buildCubit(sockets: [socket], outbox: outbox);
      await cubit.start();
      expect(cubit.state.status, ConnectionStatus.connected);
      expect(cubit.state.pending.map((m) => m.clientId), contains('old-1'));
      // Hydrated outbox is flushed on connect.
      expect(socket.sent.length, 1);
      expect(socket.sent.single['clientId'], 'old-1');
      await cubit.close();
    });

    test('is a no-op once already connecting', () async {
      final socket = FakeChatSocket();
      final cubit = _buildCubit(sockets: [socket]);
      await cubit.start();
      // Calling start again must NOT pull a second socket from the factory.
      await cubit.start();
      expect(socket.connectCalls, 1);
      await cubit.close();
    });
  });

  group('sendMessage', () {
    test('flushes immediately when connected', () async {
      final socket = FakeChatSocket();
      final cubit = _buildCubit(sockets: [socket]);
      await cubit.start();
      await cubit.sendMessage(conversationId: 'conv-1', body: 'hello');
      expect(socket.sent.length, 1);
      expect(socket.sent.single['body'], 'hello');
      expect(cubit.state.pending.length, 1);
      expect(cubit.state.pending.single.attempts, 1);
      await cubit.close();
    });

    test('queues offline and flushes on reconnect', () async {
      final dead = FakeChatSocket(
        autoConnect: false,
        connectError: Exception('initial fail'),
      );
      final alive = FakeChatSocket();
      final cubit = _buildCubit(
        sockets: [dead, alive],
        policy: const ReconnectPolicy(
          initialDelay: Duration(milliseconds: 10),
        ),
      );
      await cubit.start();
      expect(cubit.state.status, ConnectionStatus.reconnecting);

      await cubit.sendMessage(conversationId: 'conv', body: 'offline draft');
      expect(cubit.state.pending.length, 1);
      // Still offline → second socket not yet connected.
      expect(alive.sent, isEmpty);

      // Wait for backoff timer + connect microtask to complete.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(cubit.state.status, ConnectionStatus.connected);
      // Outbox flushed exactly once on reconnect.
      expect(alive.sent.length, 1);
      expect(alive.sent.single['body'], 'offline draft');
      await cubit.close();
    });
  });

  group('delivery confirmation', () {
    test('removes acked message from the outbox when status=sent', () async {
      final socket = FakeChatSocket();
      final outbox = InMemoryChatOutbox();
      final cubit = _buildCubit(sockets: [socket], outbox: outbox);
      await cubit.start();
      await cubit.sendMessage(conversationId: 'conv', body: 'hi');
      expect(cubit.state.pending.length, 1);

      socket.push({
        'type': 'ack',
        'clientId': 'c-1',
        'serverId': 's-1',
        'status': 'sent',
      });
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.pending, isEmpty);
      expect((await outbox.load()), isEmpty);
      await cubit.close();
    });

    test('keeps message marked failed when ack status=failed', () async {
      final socket = FakeChatSocket();
      final outbox = InMemoryChatOutbox();
      final cubit = _buildCubit(sockets: [socket], outbox: outbox);
      await cubit.start();
      await cubit.sendMessage(conversationId: 'conv', body: 'hi');

      socket.push({
        'type': 'ack',
        'clientId': 'c-1',
        'status': 'failed',
      });
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.pending.length, 1);
      expect(cubit.state.pending.single.status, ChatMessageStatus.failed);
      await cubit.close();
    });
  });

  group('inbound events', () {
    test('appends a received message to inbox', () async {
      final socket = FakeChatSocket();
      final cubit = _buildCubit(sockets: [socket]);
      await cubit.start();
      socket.push({
        'type': 'message',
        'message': {
          'clientId': 'remote-1',
          'conversationId': 'conv-7',
          'senderId': 'other',
          'body': 'pong',
          'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        },
      });
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.inbox.length, 1);
      expect(cubit.state.inbox.first.body, 'pong');
      await cubit.close();
    });

    test('tracks remote typing senders per conversation', () async {
      final socket = FakeChatSocket();
      final cubit = _buildCubit(sockets: [socket]);
      await cubit.start();
      socket.push({
        'type': 'typing',
        'conversationId': 'conv-1',
        'senderId': 'other',
        'isTyping': true,
      });
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.typingSenders['conv-1'], contains('other'));

      socket.push({
        'type': 'typing',
        'conversationId': 'conv-1',
        'senderId': 'other',
        'isTyping': false,
      });
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.typingSenders.containsKey('conv-1'), isFalse);
      await cubit.close();
    });

    test('ignores typing echoes from the local user', () async {
      final socket = FakeChatSocket();
      final cubit = _buildCubit(sockets: [socket]);
      await cubit.start();
      socket.push({
        'type': 'typing',
        'conversationId': 'conv-1',
        'senderId': 'me',
        'isTyping': true,
      });
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.typingSenders, isEmpty);
      await cubit.close();
    });
  });

  group('reconnect', () {
    test('exponential backoff increments reconnectAttempt on each failure',
        () async {
      final s1 = FakeChatSocket(autoConnect: false);
      final s2 = FakeChatSocket(autoConnect: false);
      final s3 = FakeChatSocket();
      final cubit = _buildCubit(
        sockets: [s1, s2, s3],
        policy: const ReconnectPolicy(
          initialDelay: Duration(milliseconds: 5),
          maxDelay: Duration(milliseconds: 20),
        ),
      );
      await cubit.start();
      // s1 failed immediately → reconnectAttempt should be 1, status reconnecting.
      expect(cubit.state.reconnectAttempt, 1);
      expect(cubit.state.status, ConnectionStatus.reconnecting);

      await Future<void>.delayed(const Duration(milliseconds: 30));
      // s2 also failed; expect attempt 2; then s3 connects.
      expect(cubit.state.status, ConnectionStatus.connected);
      expect(cubit.state.reconnectAttempt, 0); // resets on success
      await cubit.close();
    });

    test('connection drop triggers reconnect cycle', () async {
      final first = FakeChatSocket();
      final second = FakeChatSocket();
      final cubit = _buildCubit(sockets: [first, second]);
      await cubit.start();
      expect(cubit.state.status, ConnectionStatus.connected);

      await first.simulateDrop();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // Either reconnecting or already reconnected to `second`.
      expect(cubit.state.status, ConnectionStatus.connected);
      expect(second.connectCalls, 1);
      await cubit.close();
    });

    test('gives up after maxAttempts and stays disconnected', () async {
      final s1 = FakeChatSocket(autoConnect: false);
      final s2 = FakeChatSocket(autoConnect: false);
      final cubit = _buildCubit(
        sockets: [s1, s2],
        policy: const ReconnectPolicy(
          initialDelay: Duration(milliseconds: 5),
          maxAttempts: 2,
        ),
      );
      await cubit.start();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(cubit.state.status, ConnectionStatus.disconnected);
      await cubit.close();
    });
  });

  group('retry()', () {
    test('resets a failed message and re-flushes', () async {
      final socket = FakeChatSocket();
      final cubit = _buildCubit(sockets: [socket]);
      await cubit.start();
      await cubit.sendMessage(conversationId: 'conv', body: 'hi');
      // Server says failed.
      socket.push({
        'type': 'ack',
        'clientId': 'c-1',
        'status': 'failed',
      });
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.pending.single.status, ChatMessageStatus.failed);

      socket.sent.clear();
      await cubit.retry('c-1');
      // After retry: status pending, attempts reset, re-flushed once.
      expect(cubit.state.pending.single.status, ChatMessageStatus.pending);
      expect(socket.sent.length, 1);
      await cubit.close();
    });
  });

  group('notifyTyping', () {
    test('emits a typing frame only when connected', () async {
      final socket = FakeChatSocket();
      final cubit = _buildCubit(sockets: [socket]);
      // Not yet connected → no-op.
      cubit.notifyTyping(conversationId: 'conv-1', isTyping: true);
      expect(socket.sent, isEmpty);

      await cubit.start();
      cubit.notifyTyping(conversationId: 'conv-1', isTyping: true);
      expect(socket.sent.length, 1);
      expect(socket.sent.single['type'], 'typing');
      expect(socket.sent.single['isTyping'], isTrue);
      await cubit.close();
    });
  });
}
