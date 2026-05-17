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

  /// Wire value comes from the `category` data field on the FCM payload
  /// (jeeb-gateway sends it explicitly so the client doesn't have to
  /// guess from the topic). Unknown values fall back to [other] — that
  /// path renders the banner but no-ops on tap rather than crashing.
  static NotificationCategory fromKey(String? key) {
    switch (key) {
      case 'delivery':
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
