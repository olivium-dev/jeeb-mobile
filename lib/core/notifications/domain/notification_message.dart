import 'package:equatable/equatable.dart';

enum NotificationCategory {
  delivery,
  chat,
  kyc,
  rating,
  settings,
  newRequest,

  newOffer,

  requestExpired,

  offerAccepted,

  offerLost,
  other;

  static NotificationCategory fromKey(String? key) {
    switch (key) {
      case 'delivery':
      case 'accept':
        return NotificationCategory.delivery;
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
      case 'new_request':
        return NotificationCategory.newRequest;
      case 'request_expired':
      case 'try_expand_tier':
        return NotificationCategory.requestExpired;
      case 'offer_accepted':
        return NotificationCategory.offerAccepted;
      case 'offer_lost':
        return NotificationCategory.offerLost;
      default:
        return NotificationCategory.other;
    }
  }

  /// legacy `category` must NOT win, or a `new_request` tap mis-routes to the
  static NotificationCategory fromData(Map<String, String> data) {
    final byType = fromKey(data['type']);
    if (byType != NotificationCategory.other) return byType;
    return fromKey(data['category']);
  }
}

class NotificationMessage extends Equatable {
  const NotificationMessage({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.receivedAt,
    this.data = const <String, String>{},
  });

  final String id;

  final NotificationCategory category;
  final String title;
  final String body;
  final DateTime receivedAt;

  final Map<String, String> data;

  @override
  List<Object?> get props => [id, category, title, body, receivedAt, data];
}
