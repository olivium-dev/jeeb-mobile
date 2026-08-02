// NO IDENTITY, NO READ — asserted, not asserted-about.

library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/data/firestore_chat_message_mapper.dart';
import 'package:jeeb_mobile/features/chat/data/firestore_chat_realtime_source.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_firebase_identity.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_gateway.dart';

class _ThrowIfTouched implements Error {
  @override
  StackTrace? get stackTrace => StackTrace.current;
  @override
  String toString() =>
      'Firestore was reached without a Firebase identity — this is the '
      'competing-bid leak MessageVisibilityResolver exists to prevent.';
}

/// Records whether it was asked, and what it answered.
class _StubIdentity implements ChatFirebaseIdentity {
  _StubIdentity(this._result);
  final String? _result;
  int calls = 0;

  @override
  Future<String?> ensureSignedIn() async {
    calls++;
    return _result;
  }
}

FirestoreChatRealtimeSource _source(ChatFirebaseIdentity identity) =>
    FirestoreChatRealtimeSource(
      // If this is ever called, the identity gate did not hold.
      firestore: () => throw _ThrowIfTouched(),
      identity: identity,
      mapper: FirestoreChatMessageMapper(currentUserId: 'user-1'),
    );

void main() {
  group('the identity gate', () {
    test('without an identity, Firestore is NEVER reached', () async {
      final identity = _StubIdentity(null);
      final source = _source(identity);
      addTearDown(source.dispose);

      final events = <ChatEvent>[];
      final sub = source.subscribe('conv-1').listen(events.add);
      addTearDown(sub.cancel);

      // Let the async open run to completion. If the gate is broken the
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(identity.calls, 1, reason: 'the gate was actually consulted');
      expect(events, hasLength(1));
      final event = events.single as RealtimeTransportChanged;
      expect(event.live, isFalse);
      expect(
        event.reason,
        'no_identity',
        reason: 'the cubit needs the REASON to keep the HTTP fallback armed',
      );
    });

    test('the absent identity is never signed in', () async {
      // `ChatFirebaseIdentity.absent` is the fail-closed identity: it is what a
      expect(await ChatFirebaseIdentity.absent.ensureSignedIn(), isNull);
    });

    test('an empty identity uid is treated as no identity', () async {
      final identity = _StubIdentity('');
      final source = _source(identity);
      addTearDown(source.dispose);

      final events = <ChatEvent>[];
      final sub = source.subscribe('conv-1').listen(events.add);
      addTearDown(sub.cancel);

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(identity.calls, 1);
      expect(events, hasLength(1));
      final event = events.single as RealtimeTransportChanged;
      expect(event.live, isFalse);
      expect(
        event.reason,
        'no_identity',
        reason: 'arrayContains with an empty uid would silently query nothing',
      );
    });

    // POSITIVE CONTROL. Without this the test above passes for a source that
    test(
      'WITH the identity uid, it passes the gate and reaches Firestore',
      () async {
        final identity = _StubIdentity('firebase-user-1');
        final source = _source(identity);
        addTearDown(source.dispose);

        Object? thrown;
        await runZonedGuarded(() async {
          final sub = source.subscribe('conv-1').listen((_) {});
          addTearDown(sub.cancel);
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
        }, (error, _) => thrown = error);

        expect(identity.calls, 1);
        expect(
          thrown,
          isA<_ThrowIfTouched>(),
          reason:
              'a signed-in caller DOES open the channel — so the false case above '
              'was withheld by the identity check and nothing else',
        );
      },
    );
  });
}
