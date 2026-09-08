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
  dispute,
  support,

  /// F1 — wallet-affecting pushes (e.g. guard-2's auto-withdraw notice). No
  /// order/delivery/request id, mirroring `chat`/`newRequest`.
  wallet,
  other;

  static NotificationCategory fromKey(String? key) {
    var normalized = key?.trim().toLowerCase();
    if (normalized?.startsWith('jeeb.') ?? false) {
      normalized = normalized!.substring('jeeb.'.length).trim();
    }
    if (normalized?.startsWith('dispute.') ?? false) {
      return NotificationCategory.dispute;
    }
    if (normalized?.startsWith('support.') ?? false) {
      return NotificationCategory.support;
    }
    switch (normalized) {
      case 'delivery':
      case 'accept':
        return NotificationCategory.delivery;
      case 'offer':
      case 'offer_received':
      case 'offerreceived':
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
      case 'offeraccepted':
        return NotificationCategory.offerAccepted;
      case 'offer_lost':
      case 'offerlost':
        return NotificationCategory.offerLost;
      case 'dispute':
      case 'dispute_update':
      case 'dispute_updated':
      case 'dispute_resolved':
        return NotificationCategory.dispute;
      case 'support':
      case 'support_reply':
      case 'support_update':
      case 'support_ticket_update':
        return NotificationCategory.support;
      case 'wallet':
      case 'wallet_insufficient_balance':
      case 'offer_withdrawn_insufficient_balance':
        return NotificationCategory.wallet;
      default:
        return NotificationCategory.other;
    }
  }

  /// legacy `category` must NOT win, or a `new_request` tap mis-routes to the
  /// `notification_type` is last: the notification-service lane carries only it,
  /// while delivery/chat pushes carry it alongside a flat `type` that must win.
  static NotificationCategory fromData(Map<String, String> data) {
    final byType = fromKey(data['type']);
    if (byType != NotificationCategory.other) return byType;
    final byCategory = fromKey(data['category']);
    if (byCategory != NotificationCategory.other) return byCategory;
    return fromKey(data['notification_type']);
  }
}

/// An open that did not come from a tray notification (the in-app banner).
const String kPushOpenSourceInApp = 'inapp';

/// The FCM tray notification the OS displayed (onMessageOpenedApp).
const String kPushOpenSourceFcm = 'fcm';

/// A notification this app posted itself via flutter_local_notifications.
const String kPushOpenSourceLocal = 'local';

/// A cold start: the process was launched BY the notification tap.
const String kPushOpenSourceLaunch = 'launch';

class NotificationMessage extends Equatable {
  const NotificationMessage({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.receivedAt,
    this.data = const <String, String>{},
    this.openSource = kPushOpenSourceInApp,
  });

  final String id;

  final NotificationCategory category;
  final String title;
  final String body;
  final DateTime receivedAt;

  final Map<String, String> data;

  /// Which tap surface opened this message: fcm | local | launch | inapp.
  /// Transport metadata, deliberately NOT part of the wire `data` contract.
  final String openSource;

  NotificationMessage withOpenSource(String source) => NotificationMessage(
    id: id,
    category: category,
    title: title,
    body: body,
    receivedAt: receivedAt,
    data: data,
    openSource: source,
  );

  @override
  List<Object?> get props => [id, category, title, body, receivedAt, data];
}
