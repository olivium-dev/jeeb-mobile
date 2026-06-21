import 'package:dio/dio.dart';

import '../../../core/network/auth_token_store.dart';
import '../domain/saved_location.dart';
import '../domain/saved_location_repository.dart';

/// Dio-backed implementation of [SavedLocationRepository] (T-MOB-012 / JM-049).
///
/// **iter6 D-ADDRESS-SAVE repoint.** Targets the LIVE gateway's `me`-scoped
/// Saved-Locations BFF `GET/POST/PUT/DELETE /api/users/me/saved-locations`
/// (ACCT-04 / REQ-02). Identity is derived from the bearer claim by the gateway,
/// so there is **no `:userId` path segment** and **no hardcoded `user-client-001`**;
/// the Dio `_AuthInterceptor` already attaches the JWT. `/api/users` is NOT in
/// the mock rewrite table (keys are `/users` and `/v1/users`), so this path
/// passes through to the live gateway unrewritten. Never hardcodes a `:4010`
/// host or service prefix (40_GUARDRAILS_ARCH §4/§11). The previous impl read
/// from the mock-only `/users/<id>/saved-locations` with a hardcoded
/// `user-client-001`, which 404s on the live gateway (iter6 root-cause;
/// STATE/iter6-emu-captures-batch1.md). This MUST move together with
/// `DioAddressFormRepository` so add↔list stay coherent on the live path.
///
/// The optional [AuthTokenStore] is retained for constructor compatibility (and
/// existing tests) but is **no longer used to build the path** — the `me` route
/// resolves identity from the token.
///
/// Parsing is defensive (40_GUARDRAILS_ARCH §4): tolerates a bare list or
/// `{ items: [...] }` (the gateway list shape), the nested `geo:{lat,lng}` shape
/// AND a top-level `latitude/longitude`, both `isDefault` and `is_default`, and
/// degrades a malformed row to its best-effort fields rather than crashing on a
/// cast.
///
/// Observability: logs `saved_location.<op>` per AC5 (T-MOB-025).
class DioSavedLocationRepository implements SavedLocationRepository {
  /// [tokenStore] is accepted for source/DI/test compatibility but is
  /// intentionally unused: the `me` route resolves identity from the bearer the
  /// Dio `_AuthInterceptor` attaches, so the path no longer derives from a
  /// stored userId (iter6 D-ADDRESS-SAVE).
  DioSavedLocationRepository(this._dio, {AuthTokenStore? tokenStore});

  /// LIVE `me`-scoped Saved-Locations BFF. Identity comes from the bearer token
  /// (the gateway resolves `me`), so no `:userId` segment is needed.
  static const String _basePath = '/api/users/me/saved-locations';

  final Dio _dio;

  @override
  Future<List<SavedLocation>> fetchSavedLocations() async {
    _log('list');
    final response = await _dio.get<dynamic>(_basePath);
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
        _basePath,
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
        '$_basePath/$id',
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
      await _dio.delete<void>('$_basePath/$id');
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
    // Matches the LIVE gateway DTO's accepted field set
    // (`label, address?, latitude, longitude, isDefault`). `category` is NOT in
    // the gateway DTO, so it is omitted from the request (kept client-side only;
    // A-CALL-2, flagged). `isDefault` is not part of this CRUD method's params,
    // so it is left to the gateway's default (false) on create.
    return {
      'label': label,
      'latitude': lat,
      'longitude': lng,
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
