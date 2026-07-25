import '../../role/user_role.dart';
import 'notification_message.dart';

/// Maps a [NotificationMessage] to a go_router path.
///
/// Returns `null` when the message has no actionable destination — the
/// dispatcher treats that as "show the banner, do nothing on tap" rather
/// than throwing, so a malformed payload from jeeb-gateway can't crash
/// the app.
///
/// [role] is the RECIPIENT's active role. When supplied, jeeber-scoped
/// destinations are refused for a client (returns `'/'`, the shell) — see the
/// FIX-REQUESTS 403 (`docs/qa-e2e-crawl/FIX-REQUESTS.md:35`): a client tapping a
/// `new_request` row was routed to `/jeeber/requests/:id`, whose recovery path
/// calls `GET /v1/jeebers/me/feed`, a jeeber-only capability
/// (`JeebFeedController.cs:82-88`) → 403. `null` (the default) keeps the legacy
/// role-blind behaviour for callers with no role context.
///
/// The route shapes here mirror `AppRouter.create` — keep in sync.
String? deepLinkForMessage(NotificationMessage message, {UserRole? role}) {
  // F5 role-safety: a jeeber-scoped destination handed to a CLIENT token is a
  // guaranteed 403 dead end (FIX-REQUESTS.md:35). The gateway stamps no
  // audience, so the client is the only place this can be enforced. Refuse to
  // the shell — never fabricate a client-side equivalent.
  if (role == UserRole.client &&
      (message.category == NotificationCategory.newRequest ||
          message.category == NotificationCategory.offerAccepted ||
          message.category == NotificationCategory.offerLost)) {
    return '/';
  }
  switch (message.category) {
    case NotificationCategory.delivery:
      // `delivery`-category pushes cover the gateway `type=delivery|accept`
      // events (see [NotificationCategory.fromKey]). The order/delivery surface
      // keys off the delivery id, but some live `EventPushNotifier` payloads
      // carry ONLY `requestId` (no `delivery_id`/`order_id`). In this
      // system the delivery id == the request id (run evidence:
      // `GET /v1/deliveries/{requestId}` resolves 200), so fall back to
      // `requestId`/`request_id` — otherwise such a tap is a silent
      // no-op. Precedence keeps the explicit delivery/order id first.
      // P2: `type=offer` NO LONGER lands here — an auction-phase bid has no
      // delivery. See [NotificationCategory.newOffer].
      final id =
          message.data['delivery_id'] ??
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
      // P2: a new BID on the customer's open request → the offer-review list,
      // where the Accept CTA lives. The push body literally says "Tap to
      // review." The gateway payload carries `requestId` + `request_id` only
      // (`OfferPushNotifier.cs:112-123`) — no delivery id, because no delivery
      // exists yet.
      final id = message.data['requestId'] ?? message.data['request_id'];
      // Id-less fallback: the shell (the customer's Replies tab is the
      // never-empty surface), mirroring the [offerLost] reasoning below.
      // NEVER `/orders/:id` — that laundered a request id into a delivery id
      // and is the defect this change removes.
      if (id == null || id.isEmpty) return '/';
      return '/requests/$id/offers';
    case NotificationCategory.newRequest:
      // sprint-009: `type=new_request` fan-out to the jeeb_jeebers topic carries
      // a flat `requestId`/`request_id`. Route the jeeber to that request's
      // screen (`/jeeber/requests/:id` already exists for push-tap entry with
      // cache recovery + graceful fallback).
      final id = message.data['requestId'] ?? message.data['request_id'];
      if (id == null || id.isEmpty) return null;
      return '/jeeber/requests/$id';
    case NotificationCategory.requestExpired:
      // P2/F3: no-coverage / tier-expansion nudge → the waiting screen, the
      // same destination the inbox row already uses.
      final id = message.data['requestId'] ?? message.data['request_id'];
      if (id == null || id.isEmpty) return '/';
      return '/requests/$id/waiting';
    case NotificationCategory.offerAccepted:
      // run-23 CHECK B (P1): an ACCEPTED offer means this jeeber now owns an
      // active delivery — land on the jeeber active-delivery screen, the SAME
      // target the dashboard's active-deliveries banner routes to
      // (`/jeeber/deliveries/:id/active`). The old constant target,
      // `/jeeber/pending-offers`, was proven EMPTY on-device by tap time (the
      // self-scoped offers list drops decided offers), stranding the winner.
      //
      // The gateway's `OfferPushNotifier.SendLifecycleAsync` carries the flat
      // `requestId` + `request_id` (plus `offerId`/`deepLink`), and the
      // delivery id == request id in this system (`GET /v1/deliveries/
      // {requestId}` resolves 200 — same convention the `delivery` case above
      // relies on). Prefer an explicit delivery id should the gateway ever
      // stamp one. The active-delivery screen absorbs the tap-time edges: a
      // delivery already terminal (`Done`) renders its explicit
      // `delivery_completed_state` panel, and a missing/failed fetch renders
      // the retryable error state — never an empty list.
      final id =
          message.data['delivery_id'] ??
          message.data['deliveryId'] ??
          message.data['requestId'] ??
          message.data['request_id'];
      // Last-resort fallback: an id-less payload still routes to the constant
      // pending-offers surface, so an accepted tap can never silently no-op.
      if (id == null || id.isEmpty) return '/jeeber/pending-offers';
      return '/jeeber/deliveries/$id/active';
    case NotificationCategory.offerLost:
      // A LOST offer has no surface that reliably still shows it: the
      // self-scoped offers list drops decided offers (the run-23 empty-list
      // evidence), and `/jeeber/requests/:id` is unsafe for a LOSER — its
      // accepted-delivery probe (`_probeAcceptedDeliveryId`, deliveryId ==
      // requestId) would find the WINNER's in-flight delivery and redirect
      // this jeeber into an active-delivery screen that isn't theirs. The
      // stable, never-empty destination is the shell — the jeeber's
      // dashboard/feed — where they can pick the next request (the push
      // banner itself is the "not selected" notice).
      return '/';
    case NotificationCategory.other:
      return null;
  }
}
