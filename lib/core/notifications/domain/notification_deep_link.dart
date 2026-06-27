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
      // jeeb-gateway EventPushNotifier emits camelCase ids: a delivery-status
      // push carries `deliveryId`; an offer / offer-accept push carries
      // `requestId` (mock convention: deliveryId == accepted-request-id). The
      // snake_case keys are kept for legacy/admin payloads.
      final id = message.data['deliveryId'] ??
          message.data['requestId'] ??
          message.data['delivery_id'] ??
          message.data['order_id'];
      if (id == null || id.isEmpty) return null;
      return '/orders/$id';
    case NotificationCategory.chat:
      // jeeb-gateway chat fan-out push carries `conversationId` (camelCase).
      // `/chat/:id` resolves its param as the conversation correlation key and
      // degrades to using the id directly as the conversation id, so routing
      // by `conversationId` lands on the ORIGINAL thread. snake_case + the
      // legacy `chat_id` are accepted as fallbacks.
      final id = message.data['conversationId'] ??
          message.data['conversation_id'] ??
          message.data['chat_id'];
      if (id == null || id.isEmpty) return null;
      return '/chat/$id';
    case NotificationCategory.kyc:
      return '/profile/kyc';
    case NotificationCategory.rating:
      final id = message.data['deliveryId'] ??
          message.data['delivery_id'] ??
          message.data['order_id'];
      if (id == null || id.isEmpty) return null;
      return '/orders/$id/rate';
    case NotificationCategory.settings:
      return '/settings/notifications';
    case NotificationCategory.other:
      return null;
  }
}
