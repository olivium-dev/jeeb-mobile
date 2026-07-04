import 'package:dio/dio.dart';

import '../domain/notification_prefs_model.dart';
import '../domain/notification_prefs_repository.dart';

/// Dio-backed [NotificationPrefsRepository] (JM-058, D64).
///
/// Gateway-contract path; `MockGatewayClient` rewrites the `/v1/notifications`
/// prefix to `/notification-service/v1/notifications` (`mock_gateway_client.dart`).
/// Do NOT hardcode a service prefix or host here (guardrail §4, DO-NOT).
///
/// Real gateway contract (`NotificationPreferencesController`, DEFECT-2):
///   GET   /v1/notifications/preferences → `{ userId, preferences:{ offers,
///         chat, statusChanges, ratingReminders, promotions, settlements },
///         alwaysOn:[...], updatedAt }`
///   PATCH /v1/notifications/preferences → partial flat booleans (only the
///         keys you send change); echoes the same full snapshot. PUT/POST 405.
/// The app's four categories map onto the gateway toggles: offers→offers,
/// orderStatus→statusChanges, wallet→settlements, marketing→promotions
/// (chat/ratingReminders have no client toggle and are never sent).
///
/// Legacy mock contract (`notification-service.ts`) is still tolerated on
/// parse: `{ userId, push, sms, email, topics:{} }` — used when `preferences`
/// is absent, so USE_MOCK_GATEWAY builds keep working.
class DioNotificationPrefsRepository implements NotificationPrefsRepository {
  const DioNotificationPrefsRepository(this._dio);

  final Dio _dio;

  static const String _path = '/v1/notifications/preferences';

  @override
  Future<NotificationPrefs> fetch() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(_path);
      return _parse(res.data ?? const {});
    } on DioException catch (e) {
      throw NotificationPrefsRepositoryException(_map(e), e.message);
    }
  }

  @override
  Future<NotificationPrefs> save(NotificationCategoryPrefs categories) async {
    try {
      // PATCH the four client-owned toggles as flat booleans (the gateway's
      // partial-update contract; PUT is 405 — DEFECT-2). The transactional
      // class is never sent — it cannot be disabled (D64), and the gateway
      // 400s any attempt to turn an always-on channel off.
      final res = await _dio.patch<Map<String, dynamic>>(
        _path,
        data: <String, dynamic>{
          'offers': categories.offers,
          'statusChanges': categories.orderStatus,
          'settlements': categories.wallet,
          'promotions': categories.marketing,
        },
      );
      return _parse(res.data ?? const {});
    } on DioException catch (e) {
      throw NotificationPrefsRepositoryException(_map(e), e.message);
    }
  }

  NotificationPrefs _parse(Map<String, dynamic> json) {
    // Real gateway shape: `{ preferences: { offers, statusChanges,
    // settlements, promotions, ... } }` (flat booleans).
    final rawPrefs = json['preferences'];
    if (rawPrefs is Map<String, dynamic>) {
      bool read(String key, bool fallback) {
        final v = rawPrefs[key];
        return v is bool ? v : fallback;
      }

      return NotificationPrefs(
        categories: NotificationCategoryPrefs(
          offers: read('offers', true),
          orderStatus: read('statusChanges', true),
          wallet: read('settlements', true),
          marketing: read('promotions', true),
        ),
        // The gateway snapshot has no `push` channel flag; push stays on (R2).
        transactionalLocked: true,
      );
    }

    // Legacy mock shape: `{ push, topics:{} }`.
    final rawTopics = json['topics'];
    final topics =
        rawTopics is Map<String, dynamic> ? rawTopics : const <String, dynamic>{};
    final push = json['push'];
    return NotificationPrefs(
      categories: NotificationCategoryPrefs.fromTopicsJson(topics),
      pushEnabled: push is bool ? push : true,
      transactionalLocked: true,
    );
  }

  NotificationPrefsFailure _map(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return NotificationPrefsFailure.network;
    }
    return NotificationPrefsFailure.unknown;
  }
}
