import 'package:dio/dio.dart';

import '../domain/notification_prefs_model.dart';
import '../domain/notification_prefs_repository.dart';

/// Dio-backed [NotificationPrefsRepository] (JM-058, D64). Gateway contract:
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
      // PATCH four client-owned toggles as flat booleans (gateway's partial-update contract; PUT is 405).
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
    // Real gateway shape: `{ preferences: { offers, statusChanges, settlements, promotions, ... } }` (flat booleans).
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
        // Gateway snapshot has no `push` channel flag; push stays on (R2).
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
