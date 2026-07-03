// G3: BadgeCountCubit must re-derive its counts from the durable LocalPushInbox
// on hydrate (cold start / resume) so a background/terminated new_request push —
// which the cubit's own increment() never sees — still badges the feed tab. And
// the clears must write-through so a cleared badge does not resurrect on the
// next hydrate.

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/notifications/application/badge_count_cubit.dart';
import 'package:jeeb_mobile/core/notifications/domain/local_push_inbox.dart';

class _FakeInbox implements LocalPushInbox {
  _FakeInbox(this._records);
  final List<LocalPushRecord> _records;
  bool markAllReadCalled = false;
  bool markAllSeenCalled = false;

  @override
  Future<void> append(LocalPushRecord record) async => _records.add(record);
  @override
  Future<List<LocalPushRecord>> readAll() async => List.of(_records);
  @override
  Future<bool> markRead(String id) async => false;
  @override
  Future<void> markAllRead() async {
    markAllReadCalled = true;
    for (var i = 0; i < _records.length; i++) {
      _records[i] = _records[i].copyWith(read: true);
    }
  }

  @override
  Future<void> markAllNewRequestsSeenInFeed() async {
    markAllSeenCalled = true;
    for (var i = 0; i < _records.length; i++) {
      _records[i] = _records[i].copyWith(seenInFeed: true);
    }
  }
}

LocalPushRecord _newReq(String id, {bool read = false, bool seen = false}) =>
    LocalPushRecord(
      id: id,
      type: kNewRequestPushType,
      title: 't',
      body: 'b',
      ts: '2026-07-03T10:00:00Z',
      ref: 'req-$id',
      read: read,
      seenInFeed: seen,
    );

void main() {
  test('hydrate derives newRequests + unread from the store', () async {
    final cubit = BadgeCountCubit(
      inbox: _FakeInbox([_newReq('a'), _newReq('b')]),
    );
    addTearDown(cubit.close);
    await cubit.hydrate();
    expect(cubit.state, const BadgeCounts(unread: 2, newRequests: 2));
  });

  test('hydrate does NOT count rows already read or seen-in-feed', () async {
    final cubit = BadgeCountCubit(
      inbox: _FakeInbox([
        _newReq('a'), // counts for both
        _newReq('b', seen: true), // seen in feed → not a feed badge, still unread
        _newReq('c', read: true), // read → neither
      ]),
    );
    addTearDown(cubit.close);
    await cubit.hydrate();
    expect(cubit.state, const BadgeCounts(unread: 2, newRequests: 1));
  });

  test('clearNewRequests writes seen-in-feed through so a re-hydrate stays clear',
      () async {
    final inbox = _FakeInbox([_newReq('a')]);
    final cubit = BadgeCountCubit(inbox: inbox);
    addTearDown(cubit.close);
    await cubit.hydrate();
    expect(cubit.state.newRequests, 1);

    cubit.clearNewRequests();
    await Future<void>.delayed(Duration.zero); // let the fire-and-forget settle
    expect(inbox.markAllSeenCalled, isTrue);

    await cubit.hydrate();
    expect(cubit.state.newRequests, 0,
        reason: 'a cleared feed badge must not resurrect on the next resume');
  });

  test('clear writes read-through so the inbox total stays cleared', () async {
    final inbox = _FakeInbox([_newReq('a')]);
    final cubit = BadgeCountCubit(inbox: inbox);
    addTearDown(cubit.close);
    await cubit.hydrate();

    cubit.clear();
    await Future<void>.delayed(Duration.zero);
    expect(inbox.markAllReadCalled, isTrue);

    await cubit.hydrate();
    expect(cubit.state, const BadgeCounts());
  });

  test('with no store wired, hydrate is a no-op (pre-G3 in-memory behavior)',
      () async {
    final cubit = BadgeCountCubit();
    addTearDown(cubit.close);
    await cubit.hydrate();
    expect(cubit.state, const BadgeCounts());
    cubit.increment(isNewRequest: true);
    expect(cubit.state, const BadgeCounts(unread: 1, newRequests: 1));
  });
}
