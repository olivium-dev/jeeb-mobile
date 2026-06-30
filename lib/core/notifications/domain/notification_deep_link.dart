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
      // The chat-detail screen resolves the conversation via
      // `GET /v1/conversations?correlationKey={id}`, where the gateway's
      // correlationKey == the REQUEST id (auto-conversation-per-request), NOT
      // the conversation id. So prefer the request id for the `/chat/:id` route
      // param: routing with the `conversationId` 404s that first lookup and
      // forces a fallthrough to the `/messages` probe. The live chat push
      // (gateway patch 0009) carries BOTH `conversationId` and `requestId`, so
      // ordering matters. The snake_case `chat_id` and the conversation-id keys
      // remain accepted fallbacks so a tap still resolves to a route when the
      // backend stamps only a conversation id (the screen's messages probe then
      // resolves it).
      final id = message.data['requestId'] ??
          message.data['request_id'] ??
          message.data['chat_id'] ??
          message.data['conversation_id'] ??
          message.data['conversationId'];
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
