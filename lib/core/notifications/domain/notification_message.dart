import 'package:equatable/equatable.dart';

/// Categorises a push payload so the dispatcher can route taps without
/// re-parsing free-text titles. The mapping lives in [NotificationCategory.fromKey]
/// so jeeb-gateway is the single source of truth for the wire value.
enum NotificationCategory {
  delivery,
  chat,
  kyc,
  rating,
  settings,
  newRequest,

  /// P2 (b01-20260725): a jeeber submitted a BID on this customer's still-open
  /// request — gateway `type=offer`, `OfferPushNotifier.NotifyNewOfferAsync`,
  /// sent ONLY to `request.ClientId` (`RequestOffersController.cs:326-327`).
  /// The request is in the AUCTION phase: no delivery exists. Routes to the
  /// offer-review list (`/requests/:id/offers`) — the same surface the in-app
  /// Replies CTA opens (`replies_tab.dart:86`). It previously bucketed as
  /// [delivery], which resolved to `/orders/:requestId`: a delivery-detail hub
  /// for a delivery that does not exist.
  newOffer,

  /// P2 (b01-20260725): the customer's request is timing out / found no
  /// coverage — gateway `type=request_expired` / `type=try_expand_tier`
  /// (`DispatchingRequestExpiryNotifier.cs:37,50`, stamped with a legacy
  /// `category: "delivery"` at `:94-103`). Routes to the waiting/no-coverage
  /// screen (`/requests/:id/waiting`), the SAME target the notifications inbox
  /// already uses for this event (`notifications_list_screen.dart:234-238`).
  requestExpired,

  /// sprint-009 offer-lifecycle: the customer ACCEPTED this jeeber's offer
  /// (`type=offer_accepted`). Routes the jeeber to its pending-offers surface
  /// where the row flips to "Accepted".
  offerAccepted,

  /// sprint-009 offer-lifecycle: this jeeber's offer was NOT selected
  /// (`type=offer_lost`) — the customer accepted someone else's. Routes to the
  /// pending-offers surface where the row flips to "Not selected".
  offerLost,
  other;

  /// Maps a single wire discriminator value to a category.
  ///
  /// Accepts BOTH the legacy/admin `category` value AND the values
  /// jeeb-gateway's `EventPushNotifier` actually emits on its `type`
  /// routing key (verified against the iter6 gateway source — chat-send
  /// fan-out emits `type=chat`; new-offer `type=offer`; offer-accept
  /// `type=accept`; delivery status `type=delivery`). `offer` is the
  /// auction-phase new-bid event and lands on the offer-review list
  /// (see [newOffer]); only `delivery`/`accept` land on the order surface.
  /// Unknown values fall back to [other] — that path
  /// renders the banner but no-ops on tap rather than crashing.
  static NotificationCategory fromKey(String? key) {
    switch (key) {
      case 'delivery':
      // The order/delivery surface (`/orders/:id`). `accept` is DEAD on the
      // wire today (an exhaustive scan of jeeb-gateway `src/**/*.cs` for
      // `["type"] =` finds only offer / offer_accepted / offer_lost /
      // new_request / chat / try_expand_tier / request_expired) but its target
      // would be correct, so it stays.
      case 'accept':
        return NotificationCategory.delivery;
      // P2: auction-phase bid — NOT a delivery. See [NotificationCategory.newOffer].
      case 'offer':
        return NotificationCategory.newOffer;
      case 'chat':
        return NotificationCategory.chat;
      case 'kyc':
        return NotificationCategory.kyc;
      case 'rating':
        return NotificationCategory.rating;
      case 'settings':
        return NotificationCategory.settings;
      // sprint-009: the gateway broadcasts `type=new_request` to the
      // jeeb_jeebers topic when a customer creates a request, so a jeeber's tap
      // lands on that request's screen.
      case 'new_request':
        return NotificationCategory.newRequest;
      // P2/F3: both expiry events carry a legacy `category: "delivery"`. Without
      // an explicit case here they resolve to `other`, and [fromData]'s legacy
      // fallback then re-buckets them as `delivery` → the same phantom
      // `/orders/:requestId`. Route them to the waiting surface instead.
      case 'request_expired':
      case 'try_expand_tier':
        return NotificationCategory.requestExpired;
      // sprint-009 offer-lifecycle discriminators (feat/offer-lifecycle
      // gateway contract): a jeeber's submitted offer was accepted or lost.
      // Both land on the jeeber's pending-offers surface (see
      // [deepLinkForMessage]).
      case 'offer_accepted':
        return NotificationCategory.offerAccepted;
      case 'offer_lost':
        return NotificationCategory.offerLost;
      default:
        return NotificationCategory.other;
    }
  }

  /// Resolves the category from the FULL FCM `data` map.
  ///
  /// jeeb-gateway's `EventPushNotifier` flattens the whole payload into the
  /// FCM `data` map and uses `type` as the routing discriminator (the push
  /// service does `data = {k: str(v) for k,v in payload}`). The
  /// `NewRequestPushNotifier` ALSO stamps a legacy `category: "delivery"`
  /// alongside `type: "new_request"` so pre-sprint-009 APKs (which only read
  /// `category`) still bucket the push as a delivery. On a current APK that
  /// legacy `category` must NOT win, or a `new_request` tap mis-routes to the
  /// order surface instead of the jeeber's request screen (the run-19 push-D
  /// gap).
  ///
  /// Precedence: a `type` that maps to a KNOWN category wins (the gateway's
  /// event notifiers use `type` as the real discriminator; NewRequestPushNotifier
  /// also stamps a legacy `category: "delivery"` for pre-sprint-009 APKs).
  /// Fall back to `category` when `type` is absent or unknown.
  static NotificationCategory fromData(Map<String, String> data) {
    final byType = fromKey(data['type']);
    if (byType != NotificationCategory.other) return byType;
    return fromKey(data['category']);
  }
}

/// Transport-agnostic envelope for a push payload.
///
/// The transport (Firebase, fake, etc.) is responsible for parsing the
/// platform-specific payload into this shape so the rest of the stack —
/// the cubit, dispatcher, banner — never imports `firebase_messaging`.
class NotificationMessage extends Equatable {
  const NotificationMessage({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.receivedAt,
    this.data = const <String, String>{},
  });

  /// Stable id for dedup. FCM provides `messageId`; the fake transport
  /// can synthesize one. Two messages with the same id collapse in the
  /// handler so a duplicated APNs delivery doesn't double-bannerize.
  final String id;

  final NotificationCategory category;
  final String title;
  final String body;
  final DateTime receivedAt;

  /// Arbitrary key/value payload — primarily used by [deepLinkForMessage]
  /// to extract resource ids (delivery id, chat id, etc.). Kept as
  /// `Map<String, String>` because that's what FCM's `data` field is.
  final Map<String, String> data;

  @override
  List<Object?> get props => [id, category, title, body, receivedAt, data];
}
