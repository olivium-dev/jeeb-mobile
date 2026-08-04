import '../domain/notifications_repository.dart';

class EmptyNotificationsRepository implements NotificationsRepository {
  const EmptyNotificationsRepository();

  @override
  Future<List<NotificationItem>> fetchNotifications() async =>
      const <NotificationItem>[];

  @override
  Future<void> markRead(String id) async {}
}
