import '../../../core/notifications/domain/local_push_inbox.dart';
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
  const LocalMergingNotificationsRepository({
    required NotificationsRepository remote,
    required LocalPushInbox localInbox,
  })  : _remote = remote,
        _localInbox = localInbox;

  final NotificationsRepository _remote;
  final LocalPushInbox _localInbox;

  @override
  Future<List<NotificationItem>> fetchNotifications() async {
    final localItems =
        (await _localInbox.readAll()).map(_toItem).toList(growable: false);

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

    // Dedup: if the server ever DOES return the same request (matched by `ref`),
    // the server row is authoritative — drop the local duplicate. The cubit owns
    // the final newest-first sort, so order here is not load-bearing.
    final serverRefs = serverItems
        .where((i) => i.ref != null && i.ref!.isNotEmpty)
        .map((i) => i.ref)
        .toSet();
    final serverIds = serverItems.map((i) => i.id).toSet();
    final merged = <NotificationItem>[
      ...localItems.where(
        (i) => !serverIds.contains(i.id) &&
            !(i.ref != null && serverRefs.contains(i.ref)),
      ),
      ...serverItems,
    ];
    return List<NotificationItem>.unmodifiable(merged);
  }

  @override
  Future<void> markRead(String id) async {
    // A local-only row has no server PATCH target (its id is an FCM messageId,
    // not a notification-service id) — marking it read locally is authoritative.
    final wasLocal = await _localInbox.markRead(id);
    if (wasLocal) return;
    await _remote.markRead(id);
  }

  NotificationItem _toItem(LocalPushRecord record) {
    return NotificationItem(
      id: record.id,
      kind: _kind(record.type),
      title: record.title,
      body: record.body,
      timestamp: record.ts,
      read: record.read,
      ref: record.ref,
    );
  }

  /// Local records are only ever new_request today (the sole G3 gap the server
  /// inbox lacks); map defensively and fall back to unknown for anything else.
  NotificationKind _kind(String type) {
    switch (type) {
      case kNewRequestPushType:
      case 'newRequest':
        return NotificationKind.newRequest;
      default:
        return NotificationKind.unknown;
    }
  }
}
