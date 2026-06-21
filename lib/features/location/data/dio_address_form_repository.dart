import 'package:dio/dio.dart';

import '../domain/address_form_repository.dart';
import '../domain/saved_location.dart';

/// Dio-backed [AddressFormRepository] (JM-050).
///
/// **iter6 D-ADDRESS-SAVE repoint.** Targets the LIVE gateway's `me`-scoped
/// Saved-Locations BFF `POST/PUT /api/users/me/saved-locations` (ACCT-04 /
/// REQ-02). Identity is derived from the bearer claim by the gateway — there is
/// **no `:userId` path segment**; the Dio `_AuthInterceptor` already attaches
/// the JWT (`mock_gateway_client.dart`), and `/api/users` is NOT in the mock
/// rewrite table (keys are `/users` and `/v1/users`), so this path passes through
/// to the live gateway unrewritten. Never hardcodes a `:4010` host or a service
/// prefix (40_GUARDRAILS_ARCH §4/§11). The previous impl POSTed to the mock-only
/// `/users/<id>/saved-locations` with a hardcoded `user-client-001`, which 404s
/// on the live gateway (iter6 root-cause; STATE/iter6-emu-captures-batch1.md).
///
/// The `userId` param is retained as a TEST SEAM only (it is no longer used in
/// the path — the `me` route resolves identity from the token).
///
/// **Field contract (A-CALL-2, flagged product call — not decided here).** The
/// live gateway `CreateSavedLocationRequest` DTO accepts ONLY `label, address?,
/// latitude, longitude, isDefault`. The mobile form's extra fields —
/// `building`, `floorApt`, `deliveryNotes`, `codPhone`, `category` — are NOT in
/// the gateway DTO, so they are **omitted from the request** (sending them is
/// out of contract). They remain in the local draft and the parsed model; if
/// the product call adds them to the gateway DTO, restore them to `_body` here.
///
/// Parses the response defensively (40_GUARDRAILS_ARCH §4): nested `geo:{lat,lng}`
/// OR flat `latitude/longitude`, `isDefault`/`is_default`, null-coalesced
/// everywhere. Extended fields not echoed by the gateway fall back to the draft.
class DioAddressFormRepository implements AddressFormRepository {
  const DioAddressFormRepository(this._dio);

  final Dio _dio;

  /// LIVE `me`-scoped Saved-Locations BFF. Identity comes from the bearer token
  /// (the gateway resolves `me`), so no `:userId` segment is needed.
  static const String _basePath = '/api/users/me/saved-locations';

  @override
  Future<SavedLocation> create({
    required String userId,
    required AddressFormDraft draft,
  }) async {
    try {
      final res = await _dio.post<dynamic>(
        _basePath,
        data: _body(draft),
      );
      return _parseItem(res.data, draft);
    } on DioException catch (e) {
      throw AddressFormException(_map(e), e.message);
    }
  }

  @override
  Future<SavedLocation> update({
    required String userId,
    required String id,
    required AddressFormDraft draft,
  }) async {
    try {
      final res = await _dio.put<dynamic>(
        '$_basePath/$id',
        data: _body(draft),
      );
      return _parseItem(res.data, draft, fallbackId: id);
    } on DioException catch (e) {
      throw AddressFormException(_map(e), e.message);
    }
  }

  /// Builds the request body matching the LIVE gateway DTO's accepted field set
  /// (`label, address?, latitude, longitude, isDefault`). The form's extended
  /// fields (`building`/`floorApt`/`deliveryNotes`/`codPhone`/`category`) are
  /// deliberately NOT sent — they are not in the gateway DTO (A-CALL-2, flagged).
  Map<String, dynamic> _body(AddressFormDraft draft) {
    return {
      'label': draft.label,
      'latitude': draft.latitude,
      'longitude': draft.longitude,
      'isDefault': draft.isDefault,
      if (_nn(draft.address) != null) 'address': _nn(draft.address),
    };
  }

  SavedLocation _parseItem(
    dynamic data,
    AddressFormDraft draft, {
    String? fallbackId,
  }) {
    final json = data is Map<String, dynamic> ? data : const <String, dynamic>{};
    final geo = json['geo'];
    final geoMap = geo is Map<String, dynamic> ? geo : const {};
    final lat = (json['latitude'] as num?)?.toDouble() ??
        (geoMap['lat'] as num?)?.toDouble() ??
        draft.latitude;
    final lng = (json['longitude'] as num?)?.toDouble() ??
        (geoMap['lng'] as num?)?.toDouble() ??
        draft.longitude;
    return SavedLocation(
      id: json['id'] as String? ?? fallbackId ?? '',
      label: (json['label'] as String?) ?? draft.label,
      latitude: lat,
      longitude: lng,
      category: _parseCategory(json['category'] as String?) ?? draft.category,
      address: _nn(json['address'] as String?) ?? _nn(draft.address),
      isDefault: (json['isDefault'] as bool?) ??
          (json['is_default'] as bool?) ??
          draft.isDefault,
      building: _nn(json['building'] as String?) ?? _nn(draft.building),
      floorApt: _nn(json['floorApt'] as String?) ?? _nn(draft.floorApt),
      deliveryNotes:
          _nn(json['deliveryNotes'] as String?) ?? _nn(draft.deliveryNotes),
      codPhone: _nn(json['codPhone'] as String?) ?? _nn(draft.codPhone),
    );
  }

  SavedLocationCategory? _parseCategory(String? raw) {
    switch (raw) {
      case 'home':
        return SavedLocationCategory.home;
      case 'work':
        return SavedLocationCategory.work;
      case 'other':
        return SavedLocationCategory.other;
    }
    return null;
  }

  /// Normalises empty/whitespace strings to null.
  String? _nn(String? raw) {
    final t = raw?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  AddressFormFailure _map(DioException e) =>
      (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.sendTimeout)
          ? AddressFormFailure.network
          : AddressFormFailure.unknown;
}
