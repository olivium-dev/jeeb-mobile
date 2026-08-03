// G3: the inbox must UNION the durable local push store with the server inbox,

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
    final index = _records.indexWhere((record) => record.id == id);
    if (index < 0) return false;
    _records[index] = _records[index].copyWith(read: true);
    readMarked.add(id);
    return true;
  }

  @override
  Future<void> markAllRead() async {}
  @override
  Future<void> markAllNewRequestsSeenInFeed() async {}
}

class _StubRemote implements NotificationsRepository {
  _StubRemote({List<NotificationItem> items = const [], this.error})
    : items = List<NotificationItem>.of(items);
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
  Future<void> markRead(String id) async {
    readMarked.add(id);
    final index = items.indexWhere((item) => item.id == id);
    if (index >= 0) items[index] = _withRead(items[index]);
  }
}

NotificationItem _withRead(NotificationItem item) => NotificationItem(
  id: item.id,
  kind: item.kind,
  title: item.title,
  body: item.body,
  timestamp: item.timestamp,
  read: true,
  ref: item.ref,
);

LocalPushRecord _local(String id, {String ref = 'req-x'}) => LocalPushRecord(
  id: id,
  type: kNewRequestPushType,
  title: 'New request',
  body: 'b',
  ts: '2026-07-03T10:00:00Z',
  ref: ref,
);

NotificationItem _server(
  String id, {
  NotificationKind kind = NotificationKind.offer,
  String? ref,
}) => NotificationItem(
  id: id,
  kind: kind,
  title: 'srv',
  body: 'b',
  timestamp: '2026-07-03T09:00:00Z',
  read: false,
  ref: ref,
);

void main() {
  test(
    'AC-11a/AC-11b missed server push renders once from server in timestamp order',
    () async {
      final repo = LocalMergingNotificationsRepository(
        remote: _StubRemote(items: [_server('s-1')]),
        localInbox: _FakeLocalInbox([_local('bg-1')]),
      );
      final items = await repo.fetchNotifications();
      expect(items.map((i) => i.id), ['bg-1', 's-1']);
      final local = items.firstWhere((i) => i.id == 'bg-1');
      final server = items.where((i) => i.id == 's-1');
      expect(server, hasLength(1));
      expect(server.single.title, 'srv');
      expect(server.single.kind, NotificationKind.offer);
      expect(
        DateTime.parse(
          items.first.timestamp,
        ).isAfter(DateTime.parse(items.last.timestamp)),
        isTrue,
      );
      expect(local.kind, NotificationKind.newRequest);
      expect(local.ref, 'req-x');
    },
  );

  test('a dismissed new_request shows even when the server inbox is EMPTY '
      '(the exact device gap)', () async {
    final repo = LocalMergingNotificationsRepository(
      remote: _StubRemote(items: const []),
      localInbox: _FakeLocalInbox([_local('bg-1')]),
    );
    final items = await repo.fetchNotifications();
    expect(items.map((i) => i.id), ['bg-1']);
  });

  test(
    'dedups by ref — an authoritative server row wins over the local dup',
    () async {
      final repo = LocalMergingNotificationsRepository(
        remote: _StubRemote(
          items: [
            _server('s-1', kind: NotificationKind.newRequest, ref: 'req-42'),
          ],
        ),
        localInbox: _FakeLocalInbox([_local('bg-1', ref: 'req-42')]),
      );
      final items = await repo.fetchNotifications();
      expect(
        items.map((i) => i.id),
        ['s-1'],
        reason: 'the local duplicate for the same requestId is dropped',
      );
    },
  );

  test(
    'AC-15 server error with local rows present → returns local (resilient)',
    () async {
      final repo = LocalMergingNotificationsRepository(
        remote: _StubRemote(error: NotificationsFailure.network),
        localInbox: _FakeLocalInbox([_local('bg-1')]),
      );
      final items = await repo.fetchNotifications();
      expect(items.map((i) => i.id), ['bg-1']);
    },
  );

  test(
    'AC-15 server error with NO local rows → rethrows (preserves error state)',
    () async {
      final repo = LocalMergingNotificationsRepository(
        remote: _StubRemote(error: NotificationsFailure.network),
        localInbox: _FakeLocalInbox([]),
      );
      expect(
        repo.fetchNotifications(),
        throwsA(isA<NotificationsRepositoryException>()),
      );
    },
  );

  test('markRead routes a local id to the store (no server PATCH)', () async {
    final remote = _StubRemote();
    final local = _FakeLocalInbox([_local('bg-1')]);
    final repo = LocalMergingNotificationsRepository(
      remote: remote,
      localInbox: local,
    );
    await repo.fetchNotifications();
    await repo.markRead('bg-1');
    expect(local.readMarked, ['bg-1']);
    expect(
      remote.readMarked,
      isEmpty,
      reason: 'a proven legacy local-only id has no PATCH target',
    );
  });

  test('markRead routes an unknown (server) id to the remote', () async {
    final remote = _StubRemote();
    final local = _FakeLocalInbox([]);
    final repo = LocalMergingNotificationsRepository(
      remote: remote,
      localInbox: local,
    );
    await repo.markRead('s-1');
    expect(remote.readMarked, ['s-1']);
  });

  test(
    'AC-12a/AC-12b/AC-13a/AC-14a/AC-14b reconciles and survives cold restart',
    () async {
      final distinctKindsRemote = _StubRemote(
        items: [
          _server('offer-ncid-a', kind: NotificationKind.offer, ref: 'req-42'),
          _server('offer-ncid-b', kind: NotificationKind.offer, ref: 'req-42'),
        ],
      );
      final distinctKindsLocal = _FakeLocalInbox([
        _local('new-request-fcm-id', ref: 'req-42'),
      ]);
      final distinctKindsRepository = LocalMergingNotificationsRepository(
        remote: distinctKindsRemote,
        localInbox: distinctKindsLocal,
      );

      final distinctKinds = await distinctKindsRepository.fetchNotifications();
      expect(
        distinctKinds.map((item) => item.id).toSet(),
        {'new-request-fcm-id', 'offer-ncid-a', 'offer-ncid-b'},
        reason: 'a ref may dedup only when both rows are new_request',
      );
      final offers = distinctKinds
          .where((item) => item.kind == NotificationKind.offer)
          .toList(growable: false);
      expect(offers.map((item) => item.id).toSet(), {
        'offer-ncid-a',
        'offer-ncid-b',
      });
      expect(offers.map((item) => item.ref), everyElement('req-42'));

      final serverBackedRemote = _StubRemote(
        items: [
          _server('shared-ncid', kind: NotificationKind.offer, ref: 'req-9'),
        ],
      );
      final serverBackedLocal = _FakeLocalInbox([
        _local('shared-ncid', ref: 'req-9'),
      ]);
      final serverBackedRepository = LocalMergingNotificationsRepository(
        remote: serverBackedRemote,
        localInbox: serverBackedLocal,
      );

      final serverBacked = await serverBackedRepository.fetchNotifications();
      expect(serverBacked.map((item) => item.id), ['shared-ncid']);
      expect(serverBacked.single.title, 'srv');
      expect(serverBacked.single.kind, NotificationKind.offer);
      expect(serverBacked.single.ref, 'req-9');
      expect(serverBacked.single.timestamp, '2026-07-03T09:00:00Z');

      await serverBackedRepository.markRead('shared-ncid');
      expect(serverBackedLocal.readMarked, ['shared-ncid']);
      expect(
        serverBackedRemote.readMarked,
        ['shared-ncid'],
        reason: 'a server-backed NCID must be marked in both stores',
      );

      // Cold restart: discard the repository and both adapters. Rehydrate fresh
      final restartedRepository = LocalMergingNotificationsRepository(
        remote: _StubRemote(items: serverBackedRemote.items),
        localInbox: _FakeLocalInbox(
          List<LocalPushRecord>.of(serverBackedLocal._records),
        ),
      );
      final afterRestart = await restartedRepository.fetchNotifications();
      expect(afterRestart, hasLength(1));
      expect(afterRestart.single.id, 'shared-ncid');
      expect(afterRestart.single.read, isTrue);
    },
  );
}
