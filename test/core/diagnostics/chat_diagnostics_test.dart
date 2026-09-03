import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/diagnostics/chat_diagnostics.dart';

void main() {
  setUp(ChatDiagnostics.resetForTest);
  tearDown(ChatDiagnostics.resetForTest);

  test('a degradation is recorded with its stage, reason and status', () {
    ChatDiagnostics.clock = () => DateTime.utc(2026, 9, 4, 12);
    ChatDiagnostics.degraded(
      stage: ChatDiagStage.mint,
      reason: 'no_token',
      status: 503,
      conversationId: 'c1',
    );

    expect(ChatDiagnostics.events, hasLength(1));
    final event = ChatDiagnostics.events.single;
    expect(event.stage, 'mint');
    expect(event.reason, 'no_token');
    expect(event.status, 503);
    expect(event.conversationId, 'c1');
    expect(event.at, DateTime.utc(2026, 9, 4, 12));
  });

  test('the emitted line is the greppable JEEB-CHAT-DEGRADED tripwire', () {
    final lines = <String>[];
    ChatDiagnostics.sink = lines.add;
    ChatDiagnostics.degraded(
      stage: ChatDiagStage.identity,
      reason: 'minted_uid_mismatch',
    );
    expect(lines, <String>[
      'JEEB-CHAT-DEGRADED stage=identity reason=minted_uid_mismatch',
    ]);
  });

  test('the store keeps only the last `capacity` events', () {
    ChatDiagnostics.sink = (_) {};
    for (var i = 0; i < ChatDiagnostics.capacity + 5; i++) {
      ChatDiagnostics.degraded(stage: ChatDiagStage.socket, reason: 'r$i');
    }
    expect(ChatDiagnostics.events, hasLength(ChatDiagnostics.capacity));
    expect(ChatDiagnostics.events.first.reason, 'r5');
    expect(
      ChatDiagnostics.events.last.reason,
      'r${ChatDiagnostics.capacity + 4}',
    );
  });

  test('listeners are notified on every record and on clear', () {
    ChatDiagnostics.sink = (_) {};
    var notifications = 0;
    void listener() => notifications++;
    ChatDiagnostics.listenable.addListener(listener);
    addTearDown(() => ChatDiagnostics.listenable.removeListener(listener));

    ChatDiagnostics.degraded(stage: ChatDiagStage.wrap, reason: 'a');
    ChatDiagnostics.clear();
    expect(notifications, 2);
    expect(ChatDiagnostics.events, isEmpty);
  });

  group('push registration', () {
    setUp(PushRegistrationDiagnostics.resetForTest);
    tearDown(PushRegistrationDiagnostics.resetForTest);

    test('a 2xx is recorded as a success, a 401 is not', () {
      PushRegistrationDiagnostics.record(reason: 'login', status: 201);
      expect(PushRegistrationDiagnostics.last!.succeeded, isTrue);

      PushRegistrationDiagnostics.record(reason: 'login', status: 401);
      expect(PushRegistrationDiagnostics.last!.succeeded, isFalse);
      expect(PushRegistrationDiagnostics.last!.status, 401);
    });

    test('a transport failure records the error and never counts as success', () {
      PushRegistrationDiagnostics.record(
        reason: 'rotation',
        error: 'connectionError',
      );
      final last = PushRegistrationDiagnostics.last!;
      expect(last.succeeded, isFalse);
      expect(last.error, 'connectionError');
      expect(last.status, isNull);
    });
  });
}
