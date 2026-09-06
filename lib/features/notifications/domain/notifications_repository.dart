import '../../../core/network/app_failure.dart';

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

  newRequest,
  dispute,
  support,
  chat,
  availability,
  unknown,
}

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
  const NotificationsRepositoryException(this.failure, [this.message])
    : appFailure = null;

  const NotificationsRepositoryException.classified(
    this.failure, {
    this.message,
    required this.appFailure,
  });

  final NotificationsFailure failure;

  /// DIAGNOSTIC ONLY — never rendered.
  final String? message;

  /// The classified transport failure, when the thrower could produce one.
  final AppFailure? appFailure;

  @override
  String toString() => 'NotificationsRepositoryException($failure, $message)';
}

abstract class NotificationsRepository {
  Future<List<NotificationItem>> fetchNotifications();

  Future<void> markRead(String id);
}

/// What a partial read actually returned: [degraded] means the list is a
/// subset, not a complete inbox (NOTIF-02).
typedef NotificationsSnapshot = ({
  List<NotificationItem> items,
  bool degraded,
  AppFailure? failure,
});

/// The honest-read lane: only a repository that can serve a partial inbox
/// implements it, and the cubit `is`-checks before falling back.
abstract class DegradableNotificationsRepository {
  Future<NotificationsSnapshot> fetchSnapshot();
}
