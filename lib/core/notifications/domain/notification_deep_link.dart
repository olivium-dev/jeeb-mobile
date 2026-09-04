import '../../role/user_role.dart';
import 'notification_message.dart';

/// Data keys carrying a server-authored destination, richest first.
const List<String> kDeepLinkDataKeys = <String>[
  'deepLink',
  'deep_link',
  'deeplink',
];

/// Every in-app route a push `deepLink` is allowed to reach. An unknown shape
/// falls through to the category rules instead of navigating somewhere wrong.
final List<RegExp> _kPushRouteAllowList = <RegExp>[
  RegExp(r'^/$'),
  RegExp(r'^/notifications$'),
  RegExp(r'^/wallet(/(customer|activity|charge-info))?$'),
  RegExp(r'^/earnings$'),
  RegExp(r'^/profile/kyc$'),
  RegExp(r'^/settings/notifications$'),
  RegExp(r'^/support$'),
  RegExp(r'^/jeeber/pending-offers$'),
  RegExp(r'^/chat/[^/]+$'),
  RegExp(r'^/disputes/[^/]+$'),
  RegExp(r'^/support/tickets/[^/]+$'),
  RegExp(r'^/wallet/transactions/[^/]+$'),
  RegExp(r'^/requests/[^/]+/(offers|waiting)$'),
  RegExp(
    r'^/orders/[^/]+(/(receipt|summary|cancel|rate|tracking|otp|feedback|'
    r'mutual-rate|escalate))?$',
  ),
  RegExp(r'^/jeeber/requests/[^/]+(/offer)?$'),
  RegExp(r'^/jeeber/deliveries/[^/]+/active$'),
];

/// Folds a push `deepLink` into a canonical in-app path.
///
/// Accepts an already-canonical `/path` and the `jeeb://<host>/<rest>` custom
/// scheme (the host is the first path segment, matching the router's own
/// `normalizeJeebSchemeDeepLink`). Returns `null` when the value is absent,
/// malformed, or names no registered route — `jeeb://offers/<offerId>` is the
/// live example: no route is keyed by OFFER id, so it must not be honoured.
String? routeFromPushDeepLink(String? raw) {
  final trimmed = raw?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;
  final String path;
  if (uri.scheme.isEmpty) {
    if (!trimmed.startsWith('/')) return null;
    path = uri.path;
  } else if (uri.scheme == 'jeeb') {
    if (uri.host.isEmpty) return null;
    path = '/${uri.host}${uri.path}';
  } else {
    return null;
  }
  final normalized = path.length > 1 && path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
  if (!_kPushRouteAllowList.any((r) => r.hasMatch(normalized))) return null;
  return uri.hasQuery ? '$normalized?${uri.query}' : normalized;
}

String? _explicitDeepLink(NotificationMessage message) {
  for (final key in kDeepLinkDataKeys) {
    final route = routeFromPushDeepLink(message.data[key]);
    if (route != null) return route;
  }
  return null;
}

/// than throwing, so a malformed payload from jeeb-gateway can't crash
String? deepLinkForMessage(NotificationMessage message, {UserRole? role}) {
  if (role == UserRole.client &&
      (message.category == NotificationCategory.newRequest ||
          message.category == NotificationCategory.offerAccepted ||
          message.category == NotificationCategory.offerLost)) {
    return '/';
  }
  // A server-authored destination wins over the category rules, except a
  // jeeber-only surface handed to a client (same refusal as the guard above).
  final explicit = _explicitDeepLink(message);
  if (explicit != null &&
      !(role == UserRole.client && explicit.startsWith('/jeeber/'))) {
    return explicit;
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
    case NotificationCategory.dispute:
      final id =
          message.data['dispute_id'] ??
          message.data['disputeId'] ??
          message.data['case_id'] ??
          message.data['caseId'];
      if (id == null || id.isEmpty) return null;
      return '/disputes/$id';
    case NotificationCategory.support:
      final id =
          message.data['ticket_id'] ??
          message.data['ticketId'] ??
          message.data['support_ticket_id'] ??
          message.data['case_id'] ??
          message.data['caseId'];
      if (id == null || id.isEmpty) return '/support';
      return '/support/tickets/$id';
    case NotificationCategory.wallet:
      return '/wallet';
    case NotificationCategory.other:
      return null;
  }
}
