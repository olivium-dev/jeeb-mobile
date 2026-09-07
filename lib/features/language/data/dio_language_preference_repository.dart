import 'package:dio/dio.dart';

import '../../../core/locale/language_preference_repository.dart';
import '../../../core/network/app_failure.dart';

/// Dio-backed [LanguagePreferenceRepository] (JEBV4-205, E10).
class DioLanguagePreferenceRepository implements LanguagePreferenceRepository {
  const DioLanguagePreferenceRepository(this._dio);

  final Dio _dio;

  static const String prefKey = 'language';

  static const String setPath = '/api/UserPreferences/preferences';

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

  LanguagePreferenceFailure _map(DioException e) =>
      switch (AppFailure.of(e).kind) {
        // Only a real 401 is a session problem. A 403 on a preference route is
        // a permission answer and must never reach the auth-loss lane.
        AppFailureKind.unauthorized => LanguagePreferenceFailure.unauthorized,
        AppFailureKind.network ||
        AppFailureKind.timeout => LanguagePreferenceFailure.network,
        AppFailureKind.server => LanguagePreferenceFailure.serverError,
        _ => LanguagePreferenceFailure.unknown,
      };
}
