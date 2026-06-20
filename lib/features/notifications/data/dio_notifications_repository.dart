import 'package:dio/dio.dart';

import '../domain/notifications_repository.dart';

/// Dio-backed [NotificationsRepository] (JM-057) — the notification-service
/// inbox, LIVE on `:4010` (42_GUARDRAILS_MOCK §4).
///
///   list      GET   `/v1/notifications?userId=`   → rewritten to
///             `/notification-service/v1/notifications` (existing map key)
///   mark-read PATCH `/v1/notifications/:id/read`
///
/// This IS the DI default (the endpoints exist). It scopes the inbox to the
/// AUTHENTICATED user via the bearer token: the gateway derives the owner from
/// the JWT `sub` claim and IGNORES any `?userId=` param (§6B-confirmed). A prior
/// build hardcoded `?userId=user-client-001` (a mock fixture id) at construction
/// — a §6B FAIL: the screen rendered the wrong user's inbox (empty) instead of
/// the real authenticated user's notifications. Dropping the param lets the
/// gateway scope to the token `sub`, so the real user's rows render. DO NOT
/// hardcode a service prefix here (40_GUARDRAILS_ARCH §4 / DO-NOT).
class DioNotificationsRepository implements NotificationsRepository {
  const DioNotificationsRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<List<NotificationItem>> fetchNotifications() async {
    try {
      // No `userId` param: the gateway scopes the inbox to the authenticated
      // token `sub`. Passing a client-side id (mock or otherwise) is both
      // ignored by the gateway and semantically wrong, so it is omitted.
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/notifications',
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

  @override
  Future<void> confirmReceipt(String deliveryId) async {
    // Inline confirm-receipt (notif-inline-confirm-receipt, D70): transition
    // the delivery to Done with the customer-confirmed trigger. The platform
    // commission / COD ledger is a server concern (D11) — the inline action
    // never sends a fee, mirroring the delivered-receipt screen's contract.
    try {
      await _dio.post<Map<String, dynamic>>(
        '/v1/delivery/status/transition',
        data: <String, dynamic>{
          'deliveryId': deliveryId,
          'to': 'Done',
          'trigger': 'customer_confirmed_receipt',
        },
      );
    } on DioException catch (e) {
      throw NotificationsRepositoryException(_map(e), e.message);
    }
  }

  NotificationItem _item(Map<String, dynamic> json) {
    return NotificationItem(
      id: _str(json['id']) ?? '',
      kind: _kind(json['type'] ?? json['kind']),
      title: _str(json['title']) ?? '',
      body: _str(json['body'] ?? json['message']) ?? '',
      timestamp: _str(json['ts'] ?? json['timestamp'] ?? json['createdAt']) ?? '',
      read: json['read'] == true,
      ref: _str(json['ref'] ?? json['targetId'] ?? json['deliveryId']),
    );
  }

  NotificationKind _kind(Object? v) {
    switch (v) {
      case 'offer':
        return NotificationKind.offer;
      case 'offer_accepted':
      case 'offerAccepted':
        return NotificationKind.offerAccepted;
      case 'status':
      case 'order_status':
        return NotificationKind.status;
      case 'low_balance':
      case 'lowBalance':
        return NotificationKind.lowBalance;
      case 'fee_won':
      case 'feeWon':
        return NotificationKind.feeWon;
      case 'refund_penalty':
      case 'refundPenalty':
        return NotificationKind.refundPenalty;
      case 'topup':
        return NotificationKind.topup;
      case 'kyc_approved':
      case 'kycApproved':
        return NotificationKind.kycApproved;
      case 'kyc_rejected':
      case 'kycRejected':
        return NotificationKind.kycRejected;
      case 'request_expired':
      case 'requestExpired':
        return NotificationKind.requestExpired;
      case 'confirm_receipt':
      case 'confirmReceipt':
        return NotificationKind.confirmReceipt;
      case 'marketing':
        return NotificationKind.marketing;
      default:
        return NotificationKind.unknown;
    }
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
