import 'package:dio/dio.dart';

import '../domain/address_form_repository.dart';
import '../domain/saved_location.dart';

/// Dio-backed [AddressFormRepository] (JM-050).
///
/// Speaks the gateway-contract path `/users/:userId/saved-locations`; the
/// `MockGatewayClient` `/users` → `/user-management/users` rewrite carries it to
/// the live mock route `POST/PUT /user-management/users/:userId/saved-locations`
/// (the SAME working path JM-024's `DioLocationSelectRepository` reads — verified
/// in `user-management.ts`, which spreads `...req.body`). Never hardcodes a
/// `:4010` host or a service prefix (40_GUARDRAILS_ARCH §4/§11).
///
/// > Contract note: the JM-049 `DioSavedLocationRepository` speaks the legacy
/// > Mockoon `/v1/users/me/saved-locations` shape, for which the gateway has NO
/// > rewrite key (only `/users` → `/user-management/users`). This impl uses the
/// > rewriteable `/users/:userId/...` form so the form's save actually reaches
/// > the mock and the JM-049 list reflects it. Flagged in 50_ROUTE_REQUESTS.
///
/// The POST body carries the full address-detail field set; field names mirror
/// the `has_saved_addresses` seed (`building`, `floorApt`, `deliveryNotes`,
/// `codPhone`, `isDefault`/`is_default`). Parses the response defensively
/// (40_GUARDRAILS_ARCH §4): nested `geo:{lat,lng}` OR flat `latitude/longitude`,
/// `isDefault`/`is_default`, null-coalesced everywhere.
class DioAddressFormRepository implements AddressFormRepository {
  const DioAddressFormRepository(this._dio);

  final Dio _dio;

  String _basePath(String userId) => '/users/$userId/saved-locations';

  @override
  Future<SavedLocation> create({
    required String userId,
    required AddressFormDraft draft,
  }) async {
    try {
      final res = await _dio.post<dynamic>(
        _basePath(userId),
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
        '${_basePath(userId)}/$id',
        data: _body(draft),
      );
      return _parseItem(res.data, draft, fallbackId: id);
    } on DioException catch (e) {
      throw AddressFormException(_map(e), e.message);
    }
  }

  Map<String, dynamic> _body(AddressFormDraft draft) {
    return {
      'label': draft.label,
      'category': draft.category.name,
      'latitude': draft.latitude,
      'longitude': draft.longitude,
      // Mirror the seeded nested geo shape too, so a `geo`-reading consumer
      // (JM-024 parse) sees the new pin even before a list refetch.
      'geo': {'lat': draft.latitude, 'lng': draft.longitude},
      'isDefault': draft.isDefault,
      'is_default': draft.isDefault,
      if (_nn(draft.address) != null) 'address': _nn(draft.address),
      if (_nn(draft.building) != null) 'building': _nn(draft.building),
      if (_nn(draft.floorApt) != null) 'floorApt': _nn(draft.floorApt),
      if (_nn(draft.deliveryNotes) != null)
        'deliveryNotes': _nn(draft.deliveryNotes),
      if (_nn(draft.codPhone) != null) 'codPhone': _nn(draft.codPhone),
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
