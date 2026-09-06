import 'package:dio/dio.dart';

import '../../../core/diagnostics/diag.dart';
import '../../../core/network/app_failure.dart';
import '../domain/recipient_phone_resolver.dart';

class DioRecipientPhoneResolver implements RecipientPhoneResolver {
  const DioRecipientPhoneResolver(this._dio);

  final Dio _dio;

  static const String _path = '/v1/users/me';

  @override
  Future<String?> resolve() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(_path);
      final json = response.data ?? const <String, dynamic>{};
      final raw = json['phone'] ?? json['phoneE164'] ?? json['phone_e164'];
      if (raw is! String) return null;
      final trimmed = raw.trim();
      return trimmed.isEmpty ? null : trimmed;
    } catch (e) {
      Diag.event('recipient_phone_lookup_failed', <String, Object?>{
        'kind': AppFailure.of(e).kind.name,
      });
      return null;
    }
  }
}
