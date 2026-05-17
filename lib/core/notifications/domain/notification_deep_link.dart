import 'notification_message.dart';

/// Maps a [NotificationMessage] to a go_router path.
///
/// Returns `null` when the message has no actionable destination — the
/// dispatcher treats that as "show the banner, do nothing on tap" rather
/// than throwing, so a malformed payload from jeeb-gateway can't crash
/// the app.
///
/// The route shapes here mirror `AppRouter.create` — keep in sync.
String? deepLinkForMessage(NotificationMessage message) {
  switch (message.category) {
    case NotificationCategory.delivery:
      final id = message.data['delivery_id'] ?? message.data['order_id'];
      if (id == null || id.isEmpty) return null;
      return '/orders/$id';
    case NotificationCategory.chat:
      final id = message.data['chat_id'] ?? message.data['conversation_id'];
      if (id == null || id.isEmpty) return null;
      return '/chat/$id';
    case NotificationCategory.kyc:
      return '/profile/kyc';
    case NotificationCategory.rating:
      final id = message.data['delivery_id'] ?? message.data['order_id'];
      if (id == null || id.isEmpty) return null;
      return '/orders/$id/rate';
    case NotificationCategory.settings:
      return '/settings/notifications';
    case NotificationCategory.other:
      return null;
  }
}
