import 'package:dio/dio.dart';

import '../../../core/network/auth_token_store.dart';
import '../domain/notification_kind_mapping.dart';
import '../domain/notifications_repository.dart';

/// Dio-backed [NotificationsRepository] (JM-057) — the notification-service
/// inbox, LIVE on `:4010` (42_GUARDRAILS_MOCK §4).
///
///   list      GET   `/v1/notifications?userId=`   → rewritten to
///             `/notification-service/v1/notifications` (existing map key)
///   mark-read PATCH `/v1/notifications/:id/read`
///
/// This IS the DI default (the endpoints exist). The `?userId=` is supplied at
/// construction (the seeded session user, mirroring DioSubmittedOffersRepository
/// / 50_ROUTE_REQUESTS JM-047) until a real session-user-id provider lands; the
/// JM-057 engineer swaps it for the live session user. DO NOT hardcode a service
/// prefix here (40_GUARDRAILS_ARCH §4 / DO-NOT).
class DioNotificationsRepository implements NotificationsRepository {
  const DioNotificationsRepository({
    required Dio dio,
    AuthTokenStore? tokenStore,
  }) : _dio = dio,
       _tokenStore = tokenStore;

  final Dio _dio;
  final AuthTokenStore? _tokenStore;

  @override
  Future<List<NotificationItem>> fetchNotifications() async {
    try {
      final userId = await _tokenStore?.userId;
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/notifications',
        queryParameters: userId == null || userId.isEmpty
            ? null
            : <String, Object>{'userId': userId},
      );
      final data = res.data ?? const <String, dynamic>{};
      final raw = data['items'] ?? data['notifications'];
      final list = raw is List ? raw : const <dynamic>[];
      final out = <NotificationItem>[];
      for (final item in list) {
        if (item is Map) {
          out.add(_item(item.cast<String, dynamic>()));
        }
      }
      return out;
    } on DioException catch (e) {
      throw NotificationsRepositoryException(_map(e), e.message);
    }
  }

  @override
  Future<void> markRead(String id) async {
    try {
      await _dio.patch<void>('/v1/notifications/$id/read');
    } on DioException catch (e) {
      throw NotificationsRepositoryException(_map(e), e.message);
    }
  }

  NotificationItem _item(Map<String, dynamic> json) {
    return NotificationItem(
      id: _str(json['id']) ?? '',
      kind: notificationKindFromWireType(_str(json['type'] ?? json['kind'])),
      title: _str(json['title']) ?? '',
      body: _str(json['body'] ?? json['message']) ?? '',
      timestamp:
          _str(json['ts'] ?? json['timestamp'] ?? json['createdAt']) ?? '',
      read: json['read'] == true,
      // `requestId` joins the ref chain for `new_request` rows (G3); it sits
      // after the explicit ref/target keys and before `deliveryId` — safe
      // because in this system the delivery id == the request id (the same
      // convention notification_deep_link.dart documents).
      ref: _str(
        json['ref'] ??
            json['targetId'] ??
            json['requestId'] ??
            json['deliveryId'] ??
            json['offerId'] ??
            json['offer_id'] ??
            json['orderId'],
      ),
    );
  }

  String? _str(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  NotificationsFailure _map(DioException e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) return NotificationsFailure.unauthorized;
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return NotificationsFailure.network;
      default:
        return NotificationsFailure.unknown;
    }
  }
}
