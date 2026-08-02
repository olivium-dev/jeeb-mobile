import 'package:dio/dio.dart';

import '../../../core/network/auth_token_store.dart';
import '../../../core/network/mock_gateway_client.dart';
import '../domain/saved_location.dart';
import '../domain/saved_location_repository.dart';

class DioSavedLocationRepository implements SavedLocationRepository {
  DioSavedLocationRepository(this._dio, {AuthTokenStore? tokenStore})
      : _tokenStore = tokenStore ?? AuthTokenStore();

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
      'address': ?address,
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
      building: json['building'] as String?,
      floorApt: (json['floorApt'] ?? json['floor_apt']) as String?,
      deliveryNotes:
          (json['deliveryNotes'] ?? json['delivery_notes']) as String?,
      codPhone: (json['codPhone'] ?? json['cod_phone']) as String?,
    );
  }

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
