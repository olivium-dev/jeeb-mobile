// b02 fg-suppression — the on-screen-chat-thread registry.
//
// The ordering hazard this locks down: navigating chat A → chat B mounts B
// BEFORE A is disposed, so an unguarded `clear()` in A's dispose would wipe B's
// registration and silently re-enable a banner for the thread the user is
// actually reading. `leave` is therefore owner-guarded.

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/notifications/domain/active_chat_thread.dart';

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
    registry.enter(screenA, const <String>['req-1', '', 'conv-1', '   ']);
    expect(registry.openIds, <String>{'req-1', 'conv-1'});
    expect(registry.isOpen(const <String>['conv-1']), isTrue);
    expect(registry.isOpen(const <String>['req-1']), isTrue);
    expect(registry.isOpen(const <String>['other']), isFalse);
  });

  test('re-entering replaces the id set (late resolution adds ids)', () {
    registry.enter(screenA, const <String>['req-1']);
    registry.enter(screenA, const <String>['req-1', 'conv-1']);
    expect(registry.openIds, <String>{'req-1', 'conv-1'});
  });

  test('an empty candidate list never matches', () {
    registry.enter(screenA, const <String>['conv-1']);
    expect(registry.isOpen(const <String>[]), isFalse);
    expect(registry.isOpen(const <String>['']), isFalse);
  });

  test('leave by the owner clears', () {
    registry.enter(screenA, const <String>['conv-1']);
    registry.leave(screenA);
    expect(registry.openIds, isEmpty);
  });

  test('leave by a SUPERSEDED owner is a no-op (chat A → chat B)', () {
    registry.enter(screenA, const <String>['conv-a']);
    registry.enter(screenB, const <String>['conv-b']);
    // A disposes only now, after B has already claimed the slot.
    registry.leave(screenA);
    expect(
      registry.openIds,
      <String>{'conv-b'},
      reason: 'B still owns the screen',
    );
    expect(registry.isOpen(const <String>['conv-b']), isTrue);
  });
}
