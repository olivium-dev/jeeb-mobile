import 'package:dio/dio.dart';

import '../../../core/network/auth_token_store.dart';
import '../domain/notification_kind_mapping.dart';
import '../../../core/network/app_failure.dart';
import '../domain/notifications_repository.dart';

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
      final data = res.data;
      if (data == null) throw const UnknownFailure(parse: true);
      final raw = data.containsKey('items')
          ? data['items']
          : data['notifications'];
      if (raw is! List) throw const UnknownFailure(parse: true);
      final out = <NotificationItem>[];
      for (final item in raw) {
        if (item is! Map<String, dynamic> || _str(item['id']) == null) {
          throw const UnknownFailure(parse: true);
        }
        out.add(_item(item));
      }
      return out;
    } on DioException catch (e) {
      throw NotificationsRepositoryException.classified(
        _map(e),
        message: e.message,
        appFailure: AppFailure.of(e),
      );
    }
  }

  @override
  Future<void> markRead(String id) async {
    try {
      await _dio.patch<void>('/v1/notifications/$id/read');
    } on DioException catch (e) {
      throw NotificationsRepositoryException.classified(
        _map(e),
        message: e.message,
        appFailure: AppFailure.of(e),
      );
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
      ref: _reference(json),
    );
  }

  String? _reference(Map<String, dynamic> json) {
    final nested = json['data'];
    final data = nested is Map ? nested : const <Object?, Object?>{};
    return _str(
      json['ref'] ??
          json['targetId'] ??
          json['requestId'] ??
          json['deliveryId'] ??
          json['offerId'] ??
          json['offer_id'] ??
          json['orderId'] ??
          json['disputeId'] ??
          json['dispute_id'] ??
          json['caseId'] ??
          json['case_id'] ??
          json['ticketId'] ??
          json['ticket_id'] ??
          json['support_ticket_id'] ??
          data['disputeId'] ??
          data['dispute_id'] ??
          data['caseId'] ??
          data['case_id'] ??
          data['ticketId'] ??
          data['ticket_id'] ??
          data['support_ticket_id'],
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
