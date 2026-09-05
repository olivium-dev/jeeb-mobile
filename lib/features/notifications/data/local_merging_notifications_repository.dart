import '../../../core/network/app_failure.dart';
import '../../../core/notifications/domain/local_push_inbox.dart';
import '../domain/notification_kind_mapping.dart';
import '../domain/notifications_repository.dart';

class LocalMergingNotificationsRepository
    implements NotificationsRepository, DegradableNotificationsRepository {
  LocalMergingNotificationsRepository({
    required NotificationsRepository remote,
    required LocalPushInbox localInbox,
  }) : _remote = remote,
       _localInbox = localInbox;

  final NotificationsRepository _remote;
  final LocalPushInbox _localInbox;
  Set<String> _provenLegacyLocalOnlyIds = const <String>{};

  @override
  Future<List<NotificationItem>> fetchNotifications() async =>
      (await fetchSnapshot()).items;

  @override
  Future<NotificationsSnapshot> fetchSnapshot() async {
    final localItems = (await _localInbox.readAll())
        .map(_toItem)
        .toList(growable: false);
    _provenLegacyLocalOnlyIds = const <String>{};

    List<NotificationItem> serverItems;
    try {
      serverItems = await _remote.fetchNotifications();
    } on NotificationsRepositoryException catch (error) {
      if (localItems.isEmpty) rethrow;
      // A local subset is NOT a complete inbox; say so (NOTIF-02).
      return (
        items: List<NotificationItem>.unmodifiable(localItems),
        degraded: true,
        failure: error.appFailure ?? AppFailure.of(error),
      );
    }

    final serverNewRequestRefs = serverItems
        .where(
          (item) =>
              item.kind == NotificationKind.newRequest &&
              item.ref != null &&
              item.ref!.isNotEmpty,
        )
        .map((i) => i.ref)
        .toSet();
    final serverIds = serverItems.map((i) => i.id).toSet();
    final retainedLocalItems = localItems
        .where(
          (item) =>
              !serverIds.contains(item.id) &&
              !(item.kind == NotificationKind.newRequest &&
                  item.ref != null &&
                  serverNewRequestRefs.contains(item.ref)),
        )
        .toList(growable: false);
    _provenLegacyLocalOnlyIds = retainedLocalItems
        .where((item) => item.kind == NotificationKind.newRequest)
        .map((item) => item.id)
        .toSet();
    final merged = <NotificationItem>[...retainedLocalItems, ...serverItems];
    return (
      items: List<NotificationItem>.unmodifiable(merged),
      degraded: false,
      failure: null,
    );
  }

  @override
  Future<void> markRead(String id) async {
    final wasLocal = await _localInbox.markRead(id);
    if (wasLocal && _provenLegacyLocalOnlyIds.contains(id)) return;
    await _remote.markRead(id);
  }

  NotificationItem _toItem(LocalPushRecord record) {
    return NotificationItem(
      id: record.id,
      kind: notificationKindFromWireType(record.type),
      title: record.title,
      body: record.body,
      timestamp: record.ts,
      read: record.read,
      ref: record.ref,
    );
  }
}
