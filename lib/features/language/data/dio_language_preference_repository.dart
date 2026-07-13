import 'package:dio/dio.dart';

import '../../../core/locale/language_preference_repository.dart';

/// Dio-backed [LanguagePreferenceRepository] (JEBV4-205, E10).
///
/// Talks ONLY to the gateway's remote-user-preferences BFF — the GR-2 store for
/// user-scoped state (`UserPreferencesController` →
/// `ServiceRemoteUserPreferencesClient`, the shared preferences service on
/// :10067). It issues NO write to `/api/User/*` (user-management) and NO
/// gateway-local persistence, satisfying the JEBV4-205 GR-2 DoD.
///
/// Gateway contract (`UserPreferencesController`, capability
/// `notification.prefs.self` = any-authenticated):
///   POST /api/UserPreferences/preferences        body `{ "key", "value" }` → 201
///   GET  /api/UserPreferences/preferences/{key}   → 200 `{ "value": "<code>" }`,
///                                                    404 when the key is unset
/// The path is the RAW gateway shape — same family as the display-name
/// `PUT /api/User/profile` repo (`dio_display_name_repository.dart`); do NOT
/// prefix a service segment here (live-gateway contract, not the Express mock).
class DioLanguagePreferenceRepository implements LanguagePreferenceRepository {
  const DioLanguagePreferenceRepository(this._dio);

  final Dio _dio;

  /// The remote-user-preferences key under which the app language is stored.
  static const String prefKey = 'language';

  /// Collection endpoint — `POST` a `{ key, value }` upsert.
  static const String setPath = '/api/UserPreferences/preferences';

  /// Single-key endpoint — `GET /api/UserPreferences/preferences/language`.
  static const String getPath = '/api/UserPreferences/preferences/$prefKey';

  @override
  Future<String?> fetch() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(getPath);
      final value = res.data?['value'];
      if (value is! String) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    } on DioException catch (e) {
      // An unset key is a legitimate "no server choice yet", not a failure —
      // the caller keeps the local/device resolution.
      if (e.response?.statusCode == 404) return null;
      throw LanguagePreferenceException(_map(e), e.message);
    }
  }

  @override
  Future<void> save(String languageCode) async {
    final code = languageCode.trim();
    if (code.isEmpty) return;
    try {
      await _dio.post<Map<String, dynamic>>(
        setPath,
        data: <String, dynamic>{'key': prefKey, 'value': code},
      );
    } on DioException catch (e) {
      throw LanguagePreferenceException(_map(e), e.message);
    }
  }

  LanguagePreferenceFailure _map(DioException e) {
    final status = e.response?.statusCode;
    if (status == 401 || status == 403) {
      return LanguagePreferenceFailure.unauthorized;
    }
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return LanguagePreferenceFailure.network;
      default:
        return LanguagePreferenceFailure.unknown;
    }
  }
}
