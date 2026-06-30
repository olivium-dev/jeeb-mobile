import 'package:dio/dio.dart';

import '../domain/customer_profile_repository.dart';
import '../domain/customer_profile_view_data.dart';

/// Dio-backed [CustomerProfileRepository] (JM-035).
///
/// Endpoint (gateway contract; the live gateway serves `GET /v1/users/me`, and
/// `MockGatewayClient` rewrites `/v1/users` → `/user-management/users` for
/// `:4010`, per `mock_gateway_client.dart`):
///   GET /v1/users/me  → the signed-in user (getMe)
///
/// Verified getMe shape (`user-management.ts` `withStatuses`, seed
/// `user-client-001`):
///   { id, phone, name, availableRoles: [...], activeRole, avatarUrl,
///     language, status, kycStatus, rating?, ratingCount? }
///
/// Parsing is defensive (40_GUARDRAILS §4): every field is null-coalesced,
/// snake_case + camelCase are both accepted, `''` normalises to `null`, and a
/// malformed body degrades to an empty profile rather than crashing on a cast.
class DioCustomerProfileRepository implements CustomerProfileRepository {
  const DioCustomerProfileRepository(this._dio);

  final Dio _dio;

  // Gateway-contract path. DO NOT hardcode the `:4010` service prefix — the
  // live gateway serves `GET /v1/users/me`; the MockGatewayClient interceptor
  // rewrites `/v1/users` → `/user-management/users`.
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
    // BUG-1: carry the gateway Auth/Capabilities surface through to the view
    // model so RoleSync can publish them to RoleAvailabilityCubit and the shell
    // can LAND a dual-role jeeber on the Jeeber surface. Roles are normalised to
    // the canonical `client` / `jeeber` vocab so `driver`/`delivery` aliases the
    // gateway may emit still resolve to `jeeber` downstream.
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

    // The account is "verified" once it carries an active, non-pending status
    // (D5 USER.status machine). getMe always surfaces `status` (U1); default to
    // verified=false when absent so the badge is opt-in, not assumed.
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

  /// Normalise the getMe `availableRoles` list to the canonical `client` /
  /// `jeeber` vocab, de-duped and order-stable, dropping anything unrecognised.
  /// A non-list (older/malformed gateway) yields an empty list so the additive
  /// shell falls back to the client surface rather than crashing.
  List<String> _normaliseRoles(Object? roles) {
    if (roles is! List) return const <String>[];
    final out = <String>[];
    for (final role in roles) {
      final canonical = _normaliseRole(role);
      if (canonical != null && !out.contains(canonical)) out.add(canonical);
    }
    return List<String>.unmodifiable(out);
  }

  /// Map a single raw role value to canonical `client` / `jeeber`, or `null`
  /// when it is empty / unrecognised.
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

  /// Normalise a JSON value to a non-empty trimmed `String`, else `null`.
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
