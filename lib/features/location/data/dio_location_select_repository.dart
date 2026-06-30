import 'package:dio/dio.dart';

import '../../../core/network/mock_gateway_client.dart';
import '../domain/location_select_repository.dart';
import '../domain/saved_location.dart';

/// Dio-backed [LocationSelectRepository] for the JM-024 location-select step.
///
/// Resolves the saved-locations base path via
/// [MockGatewayClient.savedLocationsPath]: the live gateway serves it me-keyed
/// under `/api` (`GET /api/users/me/saved-locations`, VERIFIED 200 on :10090),
/// while the `:4010` Express mock serves the `:userId`-keyed `/users/…` shape
/// via the `/users` → `/user-management/users` rewrite. Never hardcodes a
/// `:4010` host or service prefix (40_GUARDRAILS_ARCH §4/§11).
///
/// Parses defensively (40_GUARDRAILS_ARCH §4): tolerates a bare list or
/// `{ items: [...] }`, both the seeded nested `geo:{lat,lng}` shape AND a
/// top-level `latitude/longitude`, and `isDefault`/`is_default`. A malformed
/// row degrades to its best-effort fields rather than crashing on a cast.
class DioLocationSelectRepository implements LocationSelectRepository {
  const DioLocationSelectRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<SavedLocation>> fetchSavedAddresses(String userId) async {
    try {
      final res = await _dio.get<dynamic>(
        MockGatewayClient.savedLocationsPath(userId: userId),
      );
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
