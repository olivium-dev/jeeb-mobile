// b02 fg-suppression — the on-screen-chat-thread registry.
//
// Two hazards are locked down here.
//
// 1. ORDERING: navigating chat A → chat B mounts B BEFORE A is disposed, so an
//    unguarded `clear()` in A's dispose would wipe B's registration and
//    silently re-enable a banner for the thread the user is actually reading.
//    `leave` is therefore owner-guarded.
// 2. STALENESS: the registry holds a READER, not a snapshot, so ids that only
//    exist after the async `?correlationKey=` resolution are visible without
//    anyone remembering to republish. A hardware run caught the snapshot
//    version missing exactly that moment.

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/notifications/domain/active_chat_thread.dart';

/// Reader over a mutable set — stands in for a live `State` whose resolved ids
/// grow after it has already registered.
ChatThreadIdsReader _live(Set<String> box) => () => box;

void main() {
  final registry = ActiveChatThread.instance;
  final screenA = Object();
  final screenB = Object();

  setUp(registry.resetForTest);
  tearDown(registry.resetForTest);

  test('nothing is open by default', () {
    expect(registry.openIds, isEmpty);
    expect(registry.isOpen(const <String>['conv-1']), isFalse);
  });

  test('enter registers every non-empty id', () {
    registry.enter(screenA, () => <String>{'req-1', '', 'conv-1', '   '});
    expect(registry.openIds, <String>{'req-1', 'conv-1'});
    expect(registry.isOpen(const <String>['conv-1']), isTrue);
    expect(registry.isOpen(const <String>['req-1']), isTrue);
    expect(registry.isOpen(const <String>['other']), isFalse);
  });

  test(
    'ids added AFTER enter are visible with NO republish — this is the '
    'snapshot bug the reader design removes',
    () {
      final box = <String>{'req-1'};
      registry.enter(screenA, _live(box));
      expect(registry.isOpen(const <String>['conv-1']), isFalse);

      // The `?correlationKey=` lookup lands. Nobody calls `enter` again.
      box.add('conv-1');

      expect(
        registry.isOpen(const <String>['conv-1']),
        isTrue,
        reason: 'a snapshot registry returns false here, and did on hardware',
      );
      expect(registry.openIds, <String>{'req-1', 'conv-1'});
    },
  );

  test('re-entering replaces the reader', () {
    registry.enter(screenA, () => <String>{'req-1'});
    registry.enter(screenA, () => <String>{'req-1', 'conv-1'});
    expect(registry.openIds, <String>{'req-1', 'conv-1'});
  });

  test('an empty candidate list never matches', () {
    registry.enter(screenA, () => <String>{'conv-1'});
    expect(registry.isOpen(const <String>[]), isFalse);
    expect(registry.isOpen(const <String>['']), isFalse);
  });

  test('leave by the owner clears', () {
    registry.enter(screenA, () => <String>{'conv-1'});
    registry.leave(screenA);
    expect(registry.openIds, isEmpty);
  });

  test('leave by a SUPERSEDED owner is a no-op (chat A → chat B)', () {
    registry.enter(screenA, () => <String>{'conv-a'});
    registry.enter(screenB, () => <String>{'conv-b'});
    // A disposes only now, after B has already claimed the slot.
    registry.leave(screenA);
    expect(
      registry.openIds,
      <String>{'conv-b'},
      reason: 'B still owns the screen',
    );
    expect(registry.isOpen(const <String>['conv-b']), isTrue);
  });

  test(
    'a THROWING reader fails OPEN — suppression never swallows a message '
    'because the screen was torn down mid-read',
    () {
      registry.enter(screenA, () => throw StateError('disposed'));
      expect(registry.openIds, isEmpty);
      expect(registry.isOpen(const <String>['conv-1']), isFalse);
    },
  );
}
