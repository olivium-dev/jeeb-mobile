import '../domain/notifications_repository.dart';

/// The release fallback when no [NotificationsRepository] is registered: it
/// fails loudly rather than fabricating an empty inbox (GEN-01).
class UnavailableNotificationsRepository implements NotificationsRepository {
  const UnavailableNotificationsRepository();

  @override
  Future<List<NotificationItem>> fetchNotifications() {
    throw const NotificationsRepositoryException(
      NotificationsFailure.unknown,
      'NotificationsRepository unregistered',
    );
  }

  @override
  Future<void> markRead(String id) {
    throw const NotificationsRepositoryException(
      NotificationsFailure.unknown,
      'NotificationsRepository unregistered',
    );
  }
}
