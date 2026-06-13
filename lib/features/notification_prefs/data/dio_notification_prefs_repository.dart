import 'package:dio/dio.dart';

import '../domain/notification_prefs_model.dart';
import '../domain/notification_prefs_repository.dart';

/// Dio-backed [NotificationPrefsRepository].
///
/// Endpoints (useMockPrefixes=false, Mockoon :3055):
///   GET  /users/me/notification-preferences  → [NotificationPrefs]
///   PATCH /users/me/notification-preferences → [NotificationPrefs]
///
/// Contract: `{ "userId": "...", "preferences": { "offers": bool, "chat": bool,
///   "statusChanges": bool, "ratingReminders": bool },
///   "alwaysOn": ["otp","system_critical"], "updatedAt": "..." }`.
///
/// Mock endpoint verified against Mockoon :3055 scenario s12-notifications-topics.
class DioNotificationPrefsRepository implements NotificationPrefsRepository {
  const DioNotificationPrefsRepository(this._dio);

  final Dio _dio;

  static const String _path = '/users/me/notification-preferences';

  @override
  Future<NotificationPrefs> fetch() async {
    final response = await _dio.get<Map<String, dynamic>>(_path);
    return _parse(response.data ?? {});
  }

  @override
  Future<NotificationPrefs> patch(NotificationTopicPrefs prefs) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      _path,
      data: prefs.toJson(),
    );
    return _parse(response.data ?? {});
  }

  NotificationPrefs _parse(Map<String, dynamic> json) {
    final rawPrefs = json['preferences'] as Map<String, dynamic>?;
    final rawAlwaysOn = json['alwaysOn'] as List<dynamic>?;
    return NotificationPrefs(
      preferences: rawPrefs != null
          ? NotificationTopicPrefs.fromJson(rawPrefs)
          : const NotificationTopicPrefs(),
      alwaysOn: rawAlwaysOn?.cast<String>() ?? const [],
    );
  }
}
