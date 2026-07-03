// PURE Dart. No Flutter / Dio / GetIt imports (40_GUARDRAILS_ARCH §1 layer rules).
//
// Notifications inbox domain contract (JM-057). The notification-service list +
// mark-read endpoints are LIVE on :4010 (42_GUARDRAILS_MOCK §4 "mock-ready:
// GET /v1/notifications?userId= + PATCH /:id/read"), so the DI default is the
// real `DioNotificationsRepository`. Decisions: D84 (per-row deep-link
// dispatch), D64, R2.

/// The typed kind of an inbox notification (JM-057, D84). Each kind dispatches
/// to a different route on tap (the JM-057 engineer's `notif_row_<id>` handler).
enum NotificationKind {
  offer,
  offerAccepted,
  status,
  lowBalance,
  feeWon,
  refundPenalty,
  topup,
  kycApproved,
  kycRejected,
  requestExpired,
  confirmReceipt,
  marketing,

  /// G3 (sprint-009): a `new_request` broadcast to jeebers. Before this kind
  /// existed those rows mapped to [unknown] — an un-routable mark-read-only
  /// row — so a jeeber who dismissed the push had NO persistent, tappable
  /// trail back to the request. Routes to the request screen via the same
  /// resolver the push tap uses (`deepLinkForMessage`).
  newRequest,
  unknown,
}

/// A single inbox row (`notif_row_<id>`). `read` drives the unread badge; `ref`
/// carries the deep-link target id (order/delivery/dispute/request).
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.read,
    this.ref,
  });

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final String timestamp;
  final bool read;
  final String? ref;

  /// JM-057: copy with an updated [read] flag for the optimistic mark-read in
  /// [NotificationsListCubit.markRead]. Only [read] is mutable client-side; the
  /// rest of the row is server-owned.
  NotificationItem copyWith({bool? read}) {
    return NotificationItem(
      id: id,
      kind: kind,
      title: title,
      body: body,
      timestamp: timestamp,
      read: read ?? this.read,
      ref: ref,
    );
  }
}

enum NotificationsFailure { network, unauthorized, unknown }

class NotificationsRepositoryException implements Exception {
  const NotificationsRepositoryException(this.failure, [this.message]);

  final NotificationsFailure failure;
  final String? message;

  @override
  String toString() => 'NotificationsRepositoryException($failure, $message)';
}

/// Domain contract for the notifications inbox (JM-057).
abstract class NotificationsRepository {
  /// List the current user's notifications (newest first). Throws
  /// [NotificationsRepositoryException] on failure.
  Future<List<NotificationItem>> fetchNotifications();

  /// Mark a single notification read (`PATCH /v1/notifications/:id/read`).
  Future<void> markRead(String id);
}
