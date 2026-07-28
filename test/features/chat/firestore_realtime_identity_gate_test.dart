// NO IDENTITY, NO READ — asserted, not asserted-about.
//
// Reading `Conversations/{id}/Messages` from the device moves the
// message-visibility decision out of the chat-service and into Firestore
// security rules. The server-side predicate it bypasses is
// `chat-service/ChatService.Application/Service/MessageVisibilityResolver.cs`,
// and its `Restricted` lane (`:190`) is what stops one bidding Jeeber seeing
// another's offer during the `broadcasting` auction: a restricted participant
// sees ONLY messages they authored, plus explicit `audience == "all"`
// broadcasts and the three broadcast kinds.
//
// So an unauthenticated read of that subcollection is not a missing feature —
// it is a competing-bid leak. The guard has to be "we never opened the channel",
// not "we opened it and Firestore said no", because the second one is only as
// good as rules nobody in this repo can read (searched jeeb-mobile,
// jeeb-gateway and chat-service for `*.rules` / `firebase.json` /
// `firestore.indexes.json`: zero files — they live in the console).
//
// The test therefore hands the source a Firestore accessor that THROWS. If the
// identity check is ever reordered, weakened, or short-circuited, this fails
// loudly instead of silently starting to read.

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
  final bool _result;
  int calls = 0;

  @override
  Future<bool> ensureSignedIn() async {
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
      final identity = _StubIdentity(false);
      final source = _source(identity);
      addTearDown(source.dispose);

      final events = <ChatEvent>[];
      final sub = source.subscribe('conv-1').listen(events.add);
      addTearDown(sub.cancel);

      // Let the async open run to completion. If the gate is broken the
      // accessor throws here and the test fails with the message above.
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
      // host resolves when it must NOT open a channel (no Firebase app, no
      // session user id, an unresolved pre-accept conversation). It must be
      // impossible for it to report otherwise, because the realtime source
      // treats "signed in" as its sole licence to touch Firestore.
      expect(await ChatFirebaseIdentity.absent.ensureSignedIn(), isFalse);
    });

    // POSITIVE CONTROL. Without this the test above passes for a source that
    // never reads Firestore under ANY condition — including a source that is
    // simply broken. Here the identity SUCCEEDS, and reaching the accessor is
    // now the CORRECT behaviour, so the throw is what proves the gate is the
    // only thing that was holding it back.
    test('WITH an identity, it does reach Firestore', () async {
      final identity = _StubIdentity(true);
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
    });
  });
}
