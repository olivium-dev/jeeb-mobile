import 'package:dio/dio.dart';

import '../../../core/network/app_failure.dart';
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
      final json = response.data ?? const <String, dynamic>{};
      final parsed = await _withReviewSummary(_parse(json), json);
      if (parsed.email != null) return parsed;
      final phone = await phoneFallback?.call();
      if (phone == null || phone.trim().isEmpty) return parsed;
      return parsed.copyWith(email: phone.trim());
    } on DioException catch (e) {
      throw CustomerProfileRepositoryException.classified(
        _map(e),
        message: e.message,
        appFailure: AppFailure.of(e),
      );
    }
  }

  /// `/v1/users/me` owns identity and roles but does not project the mutual
  /// review aggregate. Join the generic revealed-review read by the verified
  /// user's opaque id so the shared profile header reflects real reviews for
  /// both customer and Jeeber sessions.
  ///
  /// The join is deliberately fail-soft: a review-service outage must not make
  /// account settings, sign-out, or security controls unavailable. A successful
  /// response is authoritative, including the cold-start shape where a review
  /// count is present but `averageScore` is intentionally hidden.
  Future<CustomerProfileViewData> _withReviewSummary(
    CustomerProfileViewData profile,
    Map<String, dynamic> identity,
  ) async {
    final userId = _str(
      identity['userId'] ?? identity['user_id'] ?? identity['id'],
    );
    if (userId == null) return profile;

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/ratings/jeeb/reviews',
        queryParameters: <String, Object>{
          // The gateway keeps this legacy parameter name, but the underlying
          // feedback read is generic by opaque ratee id and supports both roles.
          'jeeberId': userId,
          'page': 1,
          'pageSize': 1,
        },
      );
      final json = response.data ?? const <String, dynamic>{};
      final count =
          _int(
            json['reviewCount'] ??
                json['review_count'] ??
                json['totalCount'] ??
                json['total_count'],
          ) ??
          0;
      final average = _numOrNull(json['averageScore'] ?? json['average_score']);

      return profile.copyWith(
        rating: average,
        ratingCount: count,
        clearRating: average == null,
      );
    } on DioException {
      // A review-service outage is not "no reviews yet" (UX-33).
      return profile.copyWith(ratingUnavailable: true, clearRating: true);
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

  int? _int(Object? value) => value is num ? value.toInt() : null;

  double? _numOrNull(Object? value) => value is num ? value.toDouble() : null;

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
