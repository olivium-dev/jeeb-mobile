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
      // `delivery`-category pushes cover the gateway `type=delivery|offer|accept`
      // events (see [NotificationCategory.fromKey]). The order/delivery surface
      // keys off the delivery id, but the live `EventPushNotifier` offer/accept
      // payloads carry ONLY `requestId` (no `delivery_id`/`order_id`). In this
      // system the delivery id == the request id (run evidence:
      // `GET /v1/deliveries/{requestId}` resolves 200), so fall back to
      // `requestId`/`request_id` — otherwise an offer/accept tap is a silent
      // no-op. Precedence keeps the explicit delivery/order id first.
      final id = message.data['delivery_id'] ??
          message.data['order_id'] ??
          message.data['requestId'] ??
          message.data['request_id'];
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
    case NotificationCategory.newRequest:
      // sprint-009: `type=new_request` fan-out to the jeeb_jeebers topic carries
      // a flat `requestId`/`request_id`. Route the jeeber to that request's
      // screen (`/jeeber/requests/:id` already exists for push-tap entry with
      // cache recovery + graceful fallback).
      final id = message.data['requestId'] ?? message.data['request_id'];
      if (id == null || id.isEmpty) return null;
      return '/jeeber/requests/$id';
    case NotificationCategory.offerAccepted:
    case NotificationCategory.offerLost:
      // sprint-009 offer-lifecycle: an accept/lost push lands the jeeber on its
      // pending-offers surface (route `jeeber-pending-offers`), where the list
      // re-pulls and the affected row flips to Accepted / Not selected. The
      // gateway ships a ready `deepLink` (jeeb://offers/{offerId}) and a flat
      // `offerId`, but the offers list is self-scoped (`GET /v1/offers?jeeberId`)
      // and keys rows by index, so there is no per-offer route to target — the
      // stable surface is the list itself. Routing to a constant destination
      // (no id required) means an accept/lost tap can never no-op on a missing
      // id, unlike the delivery/chat/new_request cases.
      return '/jeeber/pending-offers';
    case NotificationCategory.other:
      return null;
  }
}
