import '../../role/user_role.dart';
import 'notification_message.dart';

/// than throwing, so a malformed payload from jeeb-gateway can't crash
String? deepLinkForMessage(NotificationMessage message, {UserRole? role}) {
  if (role == UserRole.client &&
      (message.category == NotificationCategory.newRequest ||
          message.category == NotificationCategory.offerAccepted ||
          message.category == NotificationCategory.offerLost)) {
    return '/';
  }
  switch (message.category) {
    case NotificationCategory.delivery:
      final id =
          message.data['delivery_id'] ??
          message.data['order_id'] ??
          message.data['requestId'] ??
          message.data['request_id'];
      if (id == null || id.isEmpty) return null;
      return '/orders/$id';
    case NotificationCategory.chat:
      final id =
          message.data['requestId'] ??
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
    case NotificationCategory.newOffer:
      final id = message.data['requestId'] ?? message.data['request_id'];
      if (id == null || id.isEmpty) return '/';
      return '/requests/$id/offers';
    case NotificationCategory.newRequest:
      // cache recovery + graceful fallback).
      final id = message.data['requestId'] ?? message.data['request_id'];
      if (id == null || id.isEmpty) return null;
      return '/jeeber/requests/$id';
    case NotificationCategory.requestExpired:
      final id = message.data['requestId'] ?? message.data['request_id'];
      if (id == null || id.isEmpty) return '/';
      return '/requests/$id/waiting';
    case NotificationCategory.offerAccepted:
      final id =
          message.data['delivery_id'] ??
          message.data['deliveryId'] ??
          message.data['requestId'] ??
          message.data['request_id'];
      if (id == null || id.isEmpty) return '/jeeber/pending-offers';
      return '/jeeber/deliveries/$id/active';
    case NotificationCategory.offerLost:
      return '/';
    case NotificationCategory.other:
      return null;
  }
}
