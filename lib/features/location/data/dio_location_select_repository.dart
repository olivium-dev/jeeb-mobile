import 'package:dio/dio.dart';

import '../domain/location_select_repository.dart';
import '../domain/saved_location.dart';

/// Dio-backed [LocationSelectRepository] for the JM-024 location-select step.
///
/// **iter6 D-ADDRESS-SAVE / DEFECT-B path consolidation.** Reads the LIVE
/// gateway's `me`-scoped Saved-Locations BFF `GET /api/users/me/saved-locations`
/// (ACCT-04 / REQ-02) — the SAME canonical path the JM-049 manager
/// ([DioSavedLocationRepository]) and the JM-050 form
/// ([DioAddressFormRepository]) use, so all saved-locations reads/writes share
/// one contract. Identity is derived from the bearer claim by the gateway (the
/// Dio `_AuthInterceptor` attaches the JWT), so there is **no `:userId` path
/// segment** and the picker can no longer drift onto the mock-only
/// `/users/<id>/saved-locations` shape (the old path 404s under a tightened
/// route while CREATE keeps working — the reported "choose is broken but create
/// works" symptom). `/api/users` is NOT in the mock rewrite table (keys are
/// `/users` and `/v1/users`), so this path passes through unrewritten. Never
/// hardcodes a `:4010` host or service prefix (40_GUARDRAILS_ARCH §4/§11).
///
/// The [fetchSavedAddresses] `userId` arg is retained to satisfy the
/// [LocationSelectRepository] contract (the cubit passes the authenticated id),
/// but it is **no longer used to build the path** — the `me` route resolves
/// identity from the token.
class DioLocationSelectRepository implements LocationSelectRepository {
  const DioLocationSelectRepository(this._dio);

  /// LIVE `me`-scoped Saved-Locations BFF. Identity comes from the bearer
  /// token (the gateway resolves `me`), so no `:userId` segment is needed.
  /// Shared with [DioSavedLocationRepository] / [DioAddressFormRepository].
  static const String _basePath = '/api/users/me/saved-locations';

  final Dio _dio;

  @override
  Future<List<SavedLocation>> fetchSavedAddresses(String userId) async {
    try {
      // `userId` is ignored in the path: the `me` route derives identity from
      // the bearer token (DEFECT-B consolidation). Kept in the signature to
      // satisfy the [LocationSelectRepository] contract.
      final res = await _dio.get<dynamic>(_basePath);
      return _parseList(res.data);
    } on DioException catch (e) {
      throw LocationSelectException(_map(e), e.message);
    }
  }

  List<SavedLocation> _parseList(dynamic data) {
    final List<dynamic> raw;
    if (data is List) {
      raw = data;
    } else if (data is Map && data['items'] is List) {
      raw = data['items'] as List<dynamic>;
    } else {
      return const [];
    }
    return raw
        .whereType<Map<String, dynamic>>()
        .map(_parseItem)
        .toList(growable: false);
  }

  SavedLocation _parseItem(Map<String, dynamic> json) {
    final geo = json['geo'];
    final geoMap = geo is Map<String, dynamic> ? geo : const {};
    final lat = (json['latitude'] as num?)?.toDouble() ??
        (geoMap['lat'] as num?)?.toDouble() ??
        0.0;
    final lng = (json['longitude'] as num?)?.toDouble() ??
        (geoMap['lng'] as num?)?.toDouble() ??
        0.0;
    final address = (json['address'] as String?)?.trim();
    return SavedLocation(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      latitude: lat,
      longitude: lng,
      category: _parseCategory(json['category'] as String?, json['label']),
      address: (address == null || address.isEmpty) ? null : address,
    );
  }

  /// Best-effort category. The seed carries no `category`, so fall back to the
  /// label hint (Home/Work) — purely cosmetic (drives the leading glyph).
  SavedLocationCategory _parseCategory(String? raw, Object? label) {
    switch (raw) {
      case 'home':
        return SavedLocationCategory.home;
      case 'work':
        return SavedLocationCategory.work;
      case 'other':
        return SavedLocationCategory.other;
    }
    final hint = (label as String? ?? '').toLowerCase();
    if (hint.contains('home')) return SavedLocationCategory.home;
    if (hint.contains('office') || hint.contains('work')) {
      return SavedLocationCategory.work;
    }
    return SavedLocationCategory.other;
  }

  LocationSelectFailure _map(DioException e) =>
      (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.sendTimeout)
          ? LocationSelectFailure.network
          : LocationSelectFailure.unknown;
}
