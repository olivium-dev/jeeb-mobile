// NOTIF-02: a local subset is NOT a complete inbox. `fetchSnapshot` says so;
// `fetchNotifications` keeps its old shape for the devtool implementors.

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/notifications/domain/local_push_inbox.dart';
import 'package:jeeb_mobile/features/notifications/data/local_merging_notifications_repository.dart';
import 'package:jeeb_mobile/features/notifications/domain/notifications_repository.dart';

class _FakeLocalInbox implements LocalPushInbox {
  _FakeLocalInbox(this._records);

  final List<LocalPushRecord> _records;

  @override
  Future<void> append(LocalPushRecord record) async => _records.add(record);

  @override
  Future<List<LocalPushRecord>> readAll() async =>
      List<LocalPushRecord>.unmodifiable(_records);

  @override
  Future<bool> markRead(String id) async => false;

  @override
  Future<void> markAllRead() async {}

  @override
  Future<void> markAllNewRequestsSeenInFeed() async {}
}

class _FailingRemote implements NotificationsRepository {
  const _FailingRemote();

  @override
  Future<List<NotificationItem>> fetchNotifications() async =>
      throw const NotificationsRepositoryException.classified(
        NotificationsFailure.network,
        appFailure: NetworkFailure(offline: true),
      );

  @override
  Future<void> markRead(String id) async {}
}

class _OkRemote implements NotificationsRepository {
  const _OkRemote();

  @override
  Future<List<NotificationItem>> fetchNotifications() async =>
      const <NotificationItem>[
        NotificationItem(
          id: 'srv-1',
          kind: NotificationKind.status,
          title: 'server',
          body: 'server',
          timestamp: '2026-07-03T10:00:00Z',
          read: false,
        ),
      ];

  @override
  Future<void> markRead(String id) async {}
}

LocalPushRecord _local(String id) => LocalPushRecord(
  id: id,
  type: 'status',
  title: 'local',
  body: 'local',
  ts: '2026-07-03T09:00:00Z',
  read: false,
);

void main() {
  test(
    'a remote failure over a non-empty local inbox degrades honestly',
    () async {
      final repository = LocalMergingNotificationsRepository(
        remote: const _FailingRemote(),
        localInbox: _FakeLocalInbox(<LocalPushRecord>[_local('loc-1')]),
      );

      final snapshot = await repository.fetchSnapshot();

      expect(snapshot.degraded, isTrue);
      expect(snapshot.items.map((i) => i.id), <String>['loc-1']);
      expect(snapshot.failure, isA<NetworkFailure>());
    },
  );

  test(
    'a remote failure over an EMPTY local inbox rethrows (cold error)',
    () async {
      final repository = LocalMergingNotificationsRepository(
        remote: const _FailingRemote(),
        localInbox: _FakeLocalInbox(<LocalPushRecord>[]),
      );

      await expectLater(
        repository.fetchSnapshot(),
        throwsA(isA<NotificationsRepositoryException>()),
      );
    },
  );

  test('a healthy read is not degraded', () async {
    final repository = LocalMergingNotificationsRepository(
      remote: const _OkRemote(),
      localInbox: _FakeLocalInbox(<LocalPushRecord>[_local('loc-1')]),
    );

    final snapshot = await repository.fetchSnapshot();

    expect(snapshot.degraded, isFalse);
    expect(snapshot.failure, isNull);
    expect(snapshot.items.map((i) => i.id), containsAll(<String>['srv-1']));
  });

  test(
    'fetchNotifications keeps its old shape for existing implementors',
    () async {
      final repository = LocalMergingNotificationsRepository(
        remote: const _FailingRemote(),
        localInbox: _FakeLocalInbox(<LocalPushRecord>[_local('loc-1')]),
      );

      final items = await repository.fetchNotifications();
      expect(items.map((i) => i.id), <String>['loc-1']);
    },
  );
}
