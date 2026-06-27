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
  other;

  /// Maps a single wire discriminator value to a category.
  ///
  /// Accepts BOTH the legacy/admin `category` value AND the values
  /// jeeb-gateway's `EventPushNotifier` actually emits on its `type`
  /// routing key (verified against the iter6 gateway source — chat-send
  /// fan-out emits `type=chat`; new-offer `type=offer`; offer-accept
  /// `type=accept`; delivery status `type=delivery`). `offer`/`accept`
  /// both land on the order surface (the request/delivery), so they map
  /// to [delivery]. Unknown values fall back to [other] — that path
  /// renders the banner but no-ops on tap rather than crashing.
  static NotificationCategory fromKey(String? key) {
    switch (key) {
      case 'delivery':
      // jeeb-gateway EventPushNotifier `type` values that resolve to the
      // order/delivery surface (`/orders/:id`).
      case 'offer':
      case 'accept':
        return NotificationCategory.delivery;
      case 'chat':
        return NotificationCategory.chat;
      case 'kyc':
        return NotificationCategory.kyc;
      case 'rating':
        return NotificationCategory.rating;
      case 'settings':
        return NotificationCategory.settings;
      default:
        return NotificationCategory.other;
    }
  }

  /// Resolves the category from the FULL FCM `data` map.
  ///
  /// jeeb-gateway's `EventPushNotifier` flattens the whole payload into the
  /// FCM `data` map and uses `type` as the routing discriminator (the push
  /// service does `data = {k: str(v) for k,v in payload}` — so there is no
  /// `category` key on event pushes, only `type`). Older/admin payloads may
  /// still carry an explicit `category`. Precedence: explicit `category`
  /// first, then the gateway `type`. This is the single entry point the
  /// transport should use so a chat push (`type=chat`) is never mis-bucketed
  /// as [other] and silently un-routable on tap.
  static NotificationCategory fromData(Map<String, String> data) =>
      fromKey(data['category'] ?? data['type']);
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
