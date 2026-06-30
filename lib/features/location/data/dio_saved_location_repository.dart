import 'package:dio/dio.dart';

import '../../../core/network/auth_token_store.dart';
import '../../../core/network/mock_gateway_client.dart';
import '../domain/saved_location.dart';
import '../domain/saved_location_repository.dart';

/// Dio-backed implementation of [SavedLocationRepository] (T-MOB-012 / JM-049).
///
/// **Path source of truth.** The base path comes from
/// [MockGatewayClient.savedLocationsPath]. The LIVE gateway serves the
/// collection me-keyed under `/api` (`GET|POST /api/users/me/saved-locations`,
/// `PUT|DELETE …/:id`) — VERIFIED 200/201/204 on `:10090` (2026-06-30). The
/// `:4010` Express mock instead keys it by `:userId` and is reached via the
/// `/users` → `/user-management/users` rewrite; the helper emits that shape only
/// in mock mode. The earlier `/users/:userId/...` (and the older `/v1/users/me/…`)
/// shapes 404'd on the live gateway — that was the saved-locations-404 bug.
///
/// The `:userId` (used only for the mock-mode path + the observability log) is
/// resolved from the persisted [AuthTokenStore]. When absent — bare tests / a
/// not-yet-logged-in boot — it falls back to the mock's `authStub` convention
/// (`user-client-001`). On the live gateway the path is `me` regardless of this
/// id. Never hardcodes a `:4010` host or service prefix (40_GUARDRAILS_ARCH §4/§11).
///
/// Parsing is defensive (40_GUARDRAILS_ARCH §4): tolerates a bare list or
/// `{ items: [...] }`, the seeded nested `geo:{lat,lng}` shape AND a top-level
/// `latitude/longitude`, both `isDefault` and `is_default`, and degrades a
/// malformed row to its best-effort fields rather than crashing on a cast.
///
/// Observability: logs `saved_location.<op>` per AC5 (T-MOB-025).
class DioSavedLocationRepository implements SavedLocationRepository {
  DioSavedLocationRepository(this._dio, {AuthTokenStore? tokenStore})
      : _tokenStore = tokenStore ?? AuthTokenStore();

  /// Mock `authStub` convention: any bearer resolves to `user-client-001`, and
  /// the W1 journey seeds target that id (42_GUARDRAILS_MOCK §4). Used only when
  /// the persisted userId is absent (bare test / pre-login).
  static const String _fallbackUserId = 'user-client-001';

  final Dio _dio;
  final AuthTokenStore _tokenStore;

  Future<String> _userId() async {
    final id = await _tokenStore.userId;
    return (id == null || id.isEmpty) ? _fallbackUserId : id;
  }

  Future<String> _basePath() async =>
      MockGatewayClient.savedLocationsPath(userId: await _userId());

  @override
  Future<List<SavedLocation>> fetchSavedLocations() async {
    _log('list');
    final response = await _dio.get<dynamic>(await _basePath());
    return _parseList(response.data);
  }

  @override
  Future<SavedLocation> saveLocation({
    required double latitude,
    required double longitude,
    required String label,
    required SavedLocationCategory category,
    String? address,
  }) async {
    _log('create');
    try {
      final response = await _dio.post<dynamic>(
        await _basePath(),
        data: _buildBody(label, latitude, longitude, category, address),
      );
      return _parseItem(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _handleError(e);
    }
  }

  @override
  Future<SavedLocation> updateLocation({
    required String id,
    required double latitude,
    required double longitude,
    required String label,
    required SavedLocationCategory category,
    String? address,
  }) async {
    _log('update');
    try {
      final response = await _dio.put<dynamic>(
        '${await _basePath()}/$id',
        data: _buildBody(label, latitude, longitude, category, address),
      );
      return _parseItem(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _handleError(e);
    }
  }

  @override
  Future<void> deleteLocation(String id) async {
    _log('delete');
    try {
      await _dio.delete<void>('${await _basePath()}/$id');
    } on DioException catch (e) {
      _handleError(e);
    }
  }

  Map<String, dynamic> _buildBody(
    String label,
    double lat,
    double lng,
    SavedLocationCategory category,
    String? address,
  ) {
    return {
      'label': label,
      'latitude': lat,
      'longitude': lng,
      'category': category.name,
      if (address != null) 'address': address,
    };
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
    // The seam seeds the coordinate as a nested `geo:{lat,lng}`; the legacy
    // T-MOB-012 contract used top-level `latitude/longitude`. Accept both.
    final geo = json['geo'];
    final geoMap = geo is Map<String, dynamic> ? geo : const {};
    final lat = (json['latitude'] as num?)?.toDouble() ??
        (geoMap['lat'] as num?)?.toDouble() ??
        0.0;
    final lng = (json['longitude'] as num?)?.toDouble() ??
        (geoMap['lng'] as num?)?.toDouble() ??
        0.0;
    final isDefault =
        json['isDefault'] == true || json['is_default'] == true;
    return SavedLocation(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      latitude: lat,
      longitude: lng,
      category: _parseCategory(json['category'] as String?, json['label']),
      address: json['address'] as String?,
      isDefault: isDefault,
      // JM-050 address-detail-form fields (seam: journey-seed.ts). snake_case +
      // camelCase tolerated so the form round-trips the seeded values.
      building: json['building'] as String?,
      floorApt: (json['floorApt'] ?? json['floor_apt']) as String?,
      deliveryNotes:
          (json['deliveryNotes'] ?? json['delivery_notes']) as String?,
      codPhone: (json['codPhone'] ?? json['cod_phone']) as String?,
    );
  }

  /// Best-effort category. The seam rows carry no `category`, so fall back to
  /// the label hint (Home/Office) — purely cosmetic (drives the leading glyph).
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

  Never _handleError(DioException e) {
    // The mock returns 422 `limit_reached` at the 10-location cap; the legacy
    // gateway used 409. Treat both as the cap-reached signal.
    final code = e.response?.statusCode;
    if (code == 409 || code == 422) {
      throw const SavedLocationCapReachedException();
    }
    throw SavedLocationException(
      e.message ?? 'Saved location operation failed',
    );
  }

  void _log(String op) {
    // ignore: avoid_print — observability per AC5
    print('[jeeb] saved_location.$op');
  }
}
