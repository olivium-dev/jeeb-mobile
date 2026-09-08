import 'package:dio/dio.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/network/mock_gateway_client.dart';
import '../domain/location_select_repository.dart';
import '../domain/saved_location.dart';

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
      throw AppFailure.of(e);
    }
  }

  List<SavedLocation> _parseList(dynamic data) {
    final List<dynamic> raw;
    if (data is List) {
      raw = data;
    } else if (data is Map && data['items'] is List) {
      raw = data['items'] as List<dynamic>;
    } else {
      throw const UnknownFailure(parse: true);
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
}
