import '../../../core/notifications/domain/local_push_inbox.dart';
import '../domain/notification_kind_mapping.dart';
import '../domain/notifications_repository.dart';

/// [NotificationsRepository] decorator that UNIONS the on-device
/// [LocalPushInbox] (pushes the server inbox does not source — G3 `new_request`)
/// with the live server inbox ([DioNotificationsRepository]).
///
/// G3 root cause (run-24 CHECK D): a `new_request` push dismissed while the app
/// was backgrounded is written ONLY to the FCM background isolate; the server
/// `GET /v1/notifications` has no `new_request` row to return, so the inbox
/// rendered "You're all caught up" even though the row-mapping + deep-link code
/// were correct and unit-tested (the dio test fed a FAKE server row that the
/// real server never emits). Merging the durable local record back in gives the
/// dismissed push a persistent, tappable inbox trail.
///
/// Resilience: local rows survive a server failure. If the server call throws
/// but local rows exist, the local rows are returned (degraded, no error state);
/// only a server failure with NO local rows rethrows so the screen can show its
/// error state (preserving the pre-decorator behavior for the empty case).
class LocalMergingNotificationsRepository implements NotificationsRepository {
  LocalMergingNotificationsRepository({
    required NotificationsRepository remote,
    required LocalPushInbox localInbox,
  }) : _remote = remote,
       _localInbox = localInbox;

  final NotificationsRepository _remote;
  final LocalPushInbox _localInbox;
  Set<String> _provenLegacyLocalOnlyIds = const <String>{};

  @override
  Future<List<NotificationItem>> fetchNotifications() async {
    final localItems = (await _localInbox.readAll())
        .map(_toItem)
        .toList(growable: false);
    _provenLegacyLocalOnlyIds = const <String>{};

    List<NotificationItem> serverItems;
    try {
      serverItems = await _remote.fetchNotifications();
    } on NotificationsRepositoryException {
      // Server down/unauthorized: still surface the durable local trail rather
      // than losing a dismissed push. Only rethrow when there's nothing local
      // to show, so the empty-inbox error state is unchanged.
      if (localItems.isEmpty) rethrow;
      return List<NotificationItem>.unmodifiable(localItems);
    }

    // The NCID is authoritative for every kind. A request-ref fallback is safe
    // only for two new_request rows; multiple offers legitimately share a ref.
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
    return List<NotificationItem>.unmodifiable(merged);
  }

  @override
  Future<void> markRead(String id) async {
    // A proven legacy local-only new_request has no server PATCH target. A row
    // reconciled by NCID must update both stores so read state survives restart.
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
