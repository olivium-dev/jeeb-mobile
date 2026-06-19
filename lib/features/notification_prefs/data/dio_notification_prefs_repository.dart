import 'package:dio/dio.dart';

import '../domain/notification_prefs_model.dart';
import '../domain/notification_prefs_repository.dart';

/// Dio-backed [NotificationPrefsRepository] (JM-058, D64).
///
/// Gateway-contract path; `MockGatewayClient` rewrites the `/v1/notifications`
/// prefix to `/notification-service/v1/notifications` (`mock_gateway_client.dart`).
/// Do NOT hardcode a service prefix or host here (guardrail §4, DO-NOT).
///
/// Mock contract (`notification-service.ts`):
///   GET  /v1/notifications/preferences → `{ userId, push, sms, email, topics:{} }`
///   PUT  /v1/notifications/preferences → echoes `{ userId, ...body }`
/// The four toggleable categories live in `topics` (the mock echoes them back);
/// the app owns the `topics` key contract.
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
      // PUT the full snapshot: push channel stays on (the only channel we
      // surface, R2) + the category map under `topics`. The transactional class
      // is never sent — it cannot be disabled (D64).
      final res = await _dio.put<Map<String, dynamic>>(
        _path,
        data: <String, dynamic>{
          'push': true,
          'topics': categories.toTopicsJson(),
        },
      );
      return _parse(res.data ?? const {});
    } on DioException catch (e) {
      throw NotificationPrefsRepositoryException(_map(e), e.message);
    }
  }

  NotificationPrefs _parse(Map<String, dynamic> json) {
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
