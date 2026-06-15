// QA-PRE for JEB-1423 (T-MOB-FIX-005). Binds the wire-shape `ChatMessage`
// ctor + ChatMessageStatus enum surface per the LEAD pin (comment #14900).
// Every ChatMessage call in this file uses the named-param ctor
// (clientId/conversationId/senderId/body/createdAt + optional
// status/attempts/serverId). ENG (JEB-1425) must make this file compile by
// implementing the ctor — they may NOT edit these call sites.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/application/chat_connection_cubit.dart';
import 'package:jeeb_mobile/features/chat/application/chat_connection_state.dart';
import 'package:jeeb_mobile/features/chat/application/reconnect_policy.dart';
import 'package:jeeb_mobile/features/chat/data/in_memory_chat_outbox.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_message.dart';
import 'package:jeeb_mobile/features/chat/domain/connection_status.dart';

import 'support/fake_chat_socket.dart';

/// Deterministically await the cubit reaching a target state instead of
/// sleeping a fixed wall-clock duration. Listens to the state stream and
/// completes on the first matching emission (or the current state if it
/// already matches). A generous [timeout] guards against a genuine hang — it
/// is an upper bound for the failure case, never a tuned "wait long enough"
/// sleep, so CPU contention cannot make a passing case flaky.
Future<void> _awaitState(
  ChatConnectionCubit cubit,
  bool Function(ChatConnectionState) predicate, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  if (predicate(cubit.state)) return;
  await cubit.stream.firstWhere(predicate).timeout(timeout);
}

ChatConnectionCubit _buildCubit({
  required List<FakeChatSocket> sockets,
  InMemoryChatOutbox? outbox,
  ReconnectPolicy policy = const ReconnectPolicy(
    initialDelay: Duration(milliseconds: 10),
    maxDelay: Duration(milliseconds: 40),
    multiplier: 2.0,
  ),
  int startId = 1,
  ChatTimerFactory? timerFactory,
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
    timerFactory: timerFactory,
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

    test('queues offline and flushes on reconnect', () {
      // Driven by fakeAsync so the 10ms backoff timer is virtual time, not a
      // wall-clock `Future.delayed` that races the real Timer under load.
      fakeAsync((async) {
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

        // start() is async; flush its connect chain (first socket fails →
        // schedules a reconnect timer) without sleeping.
        cubit.start();
        async.flushMicrotasks();
        expect(cubit.state.status, ConnectionStatus.reconnecting);

        cubit.sendMessage(conversationId: 'conv', body: 'offline draft');
        async.flushMicrotasks();
        expect(cubit.state.pending.length, 1);
        // Still offline → second socket not yet connected.
        expect(alive.sent, isEmpty);

        // Advance virtual time past the 10ms backoff; this fires the timer and
        // drains the resulting _connect() microtasks deterministically.
        async.elapse(const Duration(milliseconds: 10));
        async.flushMicrotasks();
        expect(cubit.state.status, ConnectionStatus.connected);
        // Outbox flushed exactly once on reconnect.
        expect(alive.sent.length, 1);
        expect(alive.sent.single['body'], 'offline draft');

        cubit.close();
        async.flushMicrotasks();
      });
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
    test('exponential backoff increments reconnectAttempt on each failure', () {
      // fakeAsync: each backoff step is advanced by virtual time, so the
      // attempt count is asserted at an exact, deterministic schedule point
      // instead of guessing a wall-clock sleep that races the real Timer.
      fakeAsync((async) {
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
        cubit.start();
        async.flushMicrotasks();
        // s1 failed immediately → reconnectAttempt 1, status reconnecting.
        expect(cubit.state.reconnectAttempt, 1);
        expect(cubit.state.status, ConnectionStatus.reconnecting);

        // attempt-1 delay = 5ms → fires s2's connect, which also fails →
        // schedules attempt-2 (delay = 10ms), reconnectAttempt 2.
        async.elapse(const Duration(milliseconds: 5));
        async.flushMicrotasks();
        expect(cubit.state.reconnectAttempt, 2);
        expect(cubit.state.status, ConnectionStatus.reconnecting);

        // attempt-2 delay = 10ms → fires s3's connect, which succeeds.
        async.elapse(const Duration(milliseconds: 10));
        async.flushMicrotasks();
        expect(cubit.state.status, ConnectionStatus.connected);
        expect(cubit.state.reconnectAttempt, 0); // resets on success

        cubit.close();
        async.flushMicrotasks();
      });
    });

    test('connection drop triggers reconnect cycle', () async {
      // This path is driven by a broadcast-stream `onDone` (peer close), which
      // fake_async does not deliver cleanly through the cubit's multi-hop async
      // subscription chain. So instead of a fixed wall-clock sleep (the old
      // flaky `Future.delayed(20ms)`), we await the cubit's state stream
      // reaching the target deterministically — contention cannot break it
      // because there is no tuned wait, only an event-driven completion.
      final first = FakeChatSocket();
      final second = FakeChatSocket();
      final cubit = _buildCubit(sockets: [first, second]);
      await cubit.start();
      expect(cubit.state.status, ConnectionStatus.connected);

      await first.simulateDrop();
      // Wait for the reconnect to land on `second` (status returns to
      // connected after the drop), bounded only by a failure-case timeout.
      await _awaitState(
        cubit,
        (s) => s.status == ConnectionStatus.connected && second.connectCalls > 0,
      );
      expect(cubit.state.status, ConnectionStatus.connected);
      expect(second.connectCalls, 1);
      await cubit.close();
    });

    test('gives up after maxAttempts and stays disconnected', () {
      fakeAsync((async) {
        final s1 = FakeChatSocket(autoConnect: false);
        final s2 = FakeChatSocket(autoConnect: false);
        final cubit = _buildCubit(
          sockets: [s1, s2],
          policy: const ReconnectPolicy(
            initialDelay: Duration(milliseconds: 5),
            maxAttempts: 2,
          ),
        );
        cubit.start();
        async.flushMicrotasks();
        // s1 failed → attempt 1, reconnecting.
        expect(cubit.state.reconnectAttempt, 1);
        expect(cubit.state.status, ConnectionStatus.reconnecting);

        // attempt-1 delay = 5ms → s2 connect fails → nextAttempt = 2 which
        // hits maxAttempts → give up, status disconnected.
        async.elapse(const Duration(milliseconds: 5));
        async.flushMicrotasks();
        expect(cubit.state.status, ConnectionStatus.disconnected);

        cubit.close();
        async.flushMicrotasks();
      });
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
      // After retry: status pending, attempts reset to 0, re-flushed once.
      // Per LEAD pin (comment #14900) Decision 2 / retry-semantics contract.
      expect(cubit.state.pending.single.status, ChatMessageStatus.pending);
      // _flushOutbox bumps attempts on the resend (0 → 1). The reset itself
      // is verified at the markFailed/copyWith layer in
      // test/chat_message_status_test.dart; here we assert the resend
      // happened (length == 1) which only fires after the reset.
      expect(cubit.state.pending.single.attempts, 1);
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
