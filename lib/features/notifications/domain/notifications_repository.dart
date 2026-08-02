
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
  const NotificationsRepositoryException(this.failure, [this.message]);

  final NotificationsFailure failure;
  final String? message;

  @override
  String toString() => 'NotificationsRepositoryException($failure, $message)';
}

abstract class NotificationsRepository {
  Future<List<NotificationItem>> fetchNotifications();

  Future<void> markRead(String id);
}
