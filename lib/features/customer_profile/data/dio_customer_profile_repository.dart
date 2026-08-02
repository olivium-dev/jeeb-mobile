import 'package:dio/dio.dart';

import '../domain/customer_profile_repository.dart';
import '../domain/customer_profile_view_data.dart';

class DioCustomerProfileRepository implements CustomerProfileRepository {
  const DioCustomerProfileRepository(this._dio);

  final Dio _dio;

  static const String _path = '/v1/users/me';

  @override
  Future<CustomerProfileViewData> fetchProfile() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(_path);
      return _parse(response.data ?? const <String, dynamic>{});
    } on DioException catch (e) {
      throw CustomerProfileRepositoryException(_map(e), e.message);
    }
  }

  CustomerProfileViewData _parse(Map<String, dynamic> json) {
    final roles = (json['availableRoles'] ?? json['available_roles']);
    final activeRole = json['activeRole'] ?? json['active_role'];
    final availableRoles = _normaliseRoles(roles);
    final normalisedActiveRole = _normaliseRole(activeRole);
    final isJeeber =
        _isJeeberRole(activeRole) ||
        roles is List &&
            roles.any((role) {
              return _isJeeberRole(role);
            });

    final ratingRaw = json['rating'] ?? json['averageRating'];
    final rating = (ratingRaw is num) ? ratingRaw.toDouble() : null;
    final ratingCountRaw =
        json['ratingCount'] ?? json['rating_count'] ?? json['reviewsCount'];
    final ratingCount = (ratingCountRaw is num) ? ratingCountRaw.toInt() : 0;

    final status = _str(json['status']);

    return CustomerProfileViewData(
      name: _str(json['name'] ?? json['fullName'] ?? json['displayName']),
      email: _str(json['email']),
      avatarUrl: _str(
        json['avatarUrl'] ?? json['avatar_url'] ?? json['photoUrl'],
      ),
      isVerified: status == 'active',
      isJeeber: isJeeber,
      rating: rating,
      ratingCount: ratingCount,
      activeRole: normalisedActiveRole,
      availableRoles: availableRoles,
    );
  }

  List<String> _normaliseRoles(Object? roles) {
    if (roles is! List) return const <String>[];
    final out = <String>[];
    for (final role in roles) {
      final canonical = _normaliseRole(role);
      if (canonical != null && !out.contains(canonical)) out.add(canonical);
    }
    return List<String>.unmodifiable(out);
  }

  String? _normaliseRole(Object? value) {
    if (_isJeeberRole(value)) return 'jeeber';
    final normalized = value is String ? value.trim().toLowerCase() : '';
    return normalized == 'client' ? 'client' : null;
  }

  bool _isJeeberRole(Object? value) {
    final normalized = value is String ? value.trim().toLowerCase() : '';
    return normalized == 'jeeber' ||
        normalized == 'driver' ||
        normalized == 'delivery' ||
        normalized == 'deliveryman' ||
        normalized == 'delivery_man';
  }

  String? _str(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  CustomerProfileFailure _map(DioException e) {
    if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
      return CustomerProfileFailure.unauthorized;
    }
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return CustomerProfileFailure.network;
      default:
        return CustomerProfileFailure.unknown;
    }
  }
}
