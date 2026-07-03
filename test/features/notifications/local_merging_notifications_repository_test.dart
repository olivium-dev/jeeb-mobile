// G3: the inbox must UNION the durable local push store with the server inbox,
// so a `new_request` the server never sources (dismissed while backgrounded)
// still shows a tappable row. The cycle-4 dio test fed a FAKE server row the
// real server never emits — this proves the real merge.

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/notifications/domain/local_push_inbox.dart';
import 'package:jeeb_mobile/features/notifications/data/local_merging_notifications_repository.dart';
import 'package:jeeb_mobile/features/notifications/domain/notifications_repository.dart';

/// In-memory [LocalPushInbox] test double.
class _FakeLocalInbox implements LocalPushInbox {
  _FakeLocalInbox(this._records);
  final List<LocalPushRecord> _records;
  final List<String> readMarked = <String>[];

  @override
  Future<void> append(LocalPushRecord record) async => _records.add(record);

  @override
  Future<List<LocalPushRecord>> readAll() async =>
      List<LocalPushRecord>.unmodifiable(_records);

  @override
  Future<bool> markRead(String id) async {
    final has = _records.any((r) => r.id == id);
    if (has) readMarked.add(id);
    return has;
  }

  @override
  Future<void> markAllRead() async {}
  @override
  Future<void> markAllNewRequestsSeenInFeed() async {}
}

class _StubRemote implements NotificationsRepository {
  _StubRemote({this.items = const [], this.error});
  final List<NotificationItem> items;
  final NotificationsFailure? error;
  final List<String> readMarked = <String>[];

  @override
  Future<List<NotificationItem>> fetchNotifications() async {
    final e = error;
    if (e != null) throw NotificationsRepositoryException(e);
    return items;
  }

  @override
  Future<void> markRead(String id) async => readMarked.add(id);
}

LocalPushRecord _local(String id, {String ref = 'req-x'}) => LocalPushRecord(
      id: id,
      type: kNewRequestPushType,
      title: 'New request',
      body: 'b',
      ts: '2026-07-03T10:00:00Z',
      ref: ref,
    );

NotificationItem _server(String id, {NotificationKind kind = NotificationKind.offer, String? ref}) =>
    NotificationItem(
      id: id,
      kind: kind,
      title: 'srv',
      body: 'b',
      timestamp: '2026-07-03T09:00:00Z',
      read: false,
      ref: ref,
    );

void main() {
  test('merges local new_request rows with server rows', () async {
    final repo = LocalMergingNotificationsRepository(
      remote: _StubRemote(items: [_server('s-1')]),
      localInbox: _FakeLocalInbox([_local('bg-1')]),
    );
    final items = await repo.fetchNotifications();
    expect(items.map((i) => i.id).toSet(), {'bg-1', 's-1'});
    final local = items.firstWhere((i) => i.id == 'bg-1');
    expect(local.kind, NotificationKind.newRequest);
    expect(local.ref, 'req-x');
  });

  test('a dismissed new_request shows even when the server inbox is EMPTY '
      '(the exact device gap)', () async {
    final repo = LocalMergingNotificationsRepository(
      remote: _StubRemote(items: const []),
      localInbox: _FakeLocalInbox([_local('bg-1')]),
    );
    final items = await repo.fetchNotifications();
    expect(items.map((i) => i.id), ['bg-1']);
  });

  test('dedups by ref — an authoritative server row wins over the local dup',
      () async {
    final repo = LocalMergingNotificationsRepository(
      remote: _StubRemote(items: [
        _server('s-1', kind: NotificationKind.newRequest, ref: 'req-42'),
      ]),
      localInbox: _FakeLocalInbox([_local('bg-1', ref: 'req-42')]),
    );
    final items = await repo.fetchNotifications();
    expect(items.map((i) => i.id), ['s-1'],
        reason: 'the local duplicate for the same requestId is dropped');
  });

  test('server error with local rows present → returns local (resilient)',
      () async {
    final repo = LocalMergingNotificationsRepository(
      remote: _StubRemote(error: NotificationsFailure.network),
      localInbox: _FakeLocalInbox([_local('bg-1')]),
    );
    final items = await repo.fetchNotifications();
    expect(items.map((i) => i.id), ['bg-1']);
  });

  test('server error with NO local rows → rethrows (preserves error state)',
      () async {
    final repo = LocalMergingNotificationsRepository(
      remote: _StubRemote(error: NotificationsFailure.network),
      localInbox: _FakeLocalInbox([]),
    );
    expect(repo.fetchNotifications(),
        throwsA(isA<NotificationsRepositoryException>()));
  });

  test('markRead routes a local id to the store (no server PATCH)', () async {
    final remote = _StubRemote();
    final local = _FakeLocalInbox([_local('bg-1')]);
    final repo =
        LocalMergingNotificationsRepository(remote: remote, localInbox: local);
    await repo.markRead('bg-1');
    expect(local.readMarked, ['bg-1']);
    expect(remote.readMarked, isEmpty,
        reason: 'a local-only id has no server PATCH target (would 404)');
  });

  test('markRead routes an unknown (server) id to the remote', () async {
    final remote = _StubRemote();
    final local = _FakeLocalInbox([]);
    final repo =
        LocalMergingNotificationsRepository(remote: remote, localInbox: local);
    await repo.markRead('s-1');
    expect(remote.readMarked, ['s-1']);
  });
}
