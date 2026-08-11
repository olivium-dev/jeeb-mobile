import 'package:dio/dio.dart';

import '../domain/customer_profile_repository.dart';
import '../domain/customer_profile_view_data.dart';

class DioCustomerProfileRepository implements CustomerProfileRepository {
  const DioCustomerProfileRepository(this._dio, {this.phoneFallback});

  final Dio _dio;

  /// Supplies the locally stored E.164 phone for phone-only accounts, whose
  /// server "email" is a synthetic handle no user should ever be shown (D-V5).
  final Future<String?> Function()? phoneFallback;

  static const String _path = '/v1/users/me';

  /// `phone-only+<hex>@jeeb.internal` — user-management's placeholder handle.
  static final RegExp _syntheticEmail = RegExp(
    r'^phone-only\+[0-9a-fA-F-]+@|@jeeb\.internal$',
  );

  @override
  Future<CustomerProfileViewData> fetchProfile() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(_path);
      final parsed = _parse(response.data ?? const <String, dynamic>{});
      if (parsed.email != null) return parsed;
      final phone = await phoneFallback?.call();
      if (phone == null || phone.trim().isEmpty) return parsed;
      return parsed.copyWith(email: phone.trim());
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
      email: _publicEmail(json['email']),
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

  String? _publicEmail(Object? value) {
    final email = _str(value);
    if (email == null || _syntheticEmail.hasMatch(email)) return null;
    return email;
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
