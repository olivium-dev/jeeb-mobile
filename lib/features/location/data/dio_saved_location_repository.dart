import 'package:dio/dio.dart';

import '../domain/saved_location.dart';
import '../domain/saved_location_repository.dart';

/// Dio-backed implementation of [SavedLocationRepository].
///
/// Endpoint contract verified against Mockoon :3055 (useMockPrefixes=false):
///   GET    /v1/users/me/saved-locations → {items, count, maxLocations}
///   POST   /v1/users/me/saved-locations → 201 created SavedLocation
///   PUT    /v1/users/me/saved-locations/{id} → 200 merged SavedLocation
///   DELETE /v1/users/me/saved-locations/{id} → 204 No Content
///
/// Observability: logs `saved_location.<op>` per AC5 (T-MOB-025).
class DioSavedLocationRepository implements SavedLocationRepository {
  DioSavedLocationRepository(this._dio);

  static const _basePath = '/v1/users/me/saved-locations';

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
    return SavedLocation(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      category: _parseCategory(json['category'] as String?),
      address: json['address'] as String?,
    );
  }

  SavedLocationCategory _parseCategory(String? raw) {
    switch (raw) {
      case 'home':
        return SavedLocationCategory.home;
      case 'work':
        return SavedLocationCategory.work;
      default:
        return SavedLocationCategory.other;
    }
  }

  Never _handleError(DioException e) {
    if (e.response?.statusCode == 409) {
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
