import 'package:dio/dio.dart';

/// One active-user row used by the "Super user login plus" picker (debug-only).
///
/// Sourced from the passcode-gated `POST /api/User/super-login/users` LIST
/// endpoint. A row carries ONLY identity + role display data — it deliberately
/// carries NO passcode. On tap the picker logs in with the tapped row's
/// [userId] + the single real SuperAdmin passcode (from `AppConfig`), never a
/// per-user secret. The whole surface is compiled out of release builds (the
/// links are `kDebugMode`-gated on the registration screen).
class SuperLoginDemoUser {
  const SuperLoginDemoUser({
    required this.userId,
    required this.name,
    required this.role,
    this.availableRoles = const <String>[],
  });

  /// Real backend user id (UUID) the picker logs in as.
  final String userId;

  /// Display name shown in the picker row — the backend `username`.
  final String name;

  /// The user's `active_role` (e.g. `customer`, `driver`); drives the badge.
  final String role;

  /// All roles the account can assume (`available_roles`). Used so a customer
  /// who can also drive is badged as a jeeber.
  final List<String> availableRoles;

  /// True when the row represents a jeeber/driver (dual-role) user; drives the
  /// OMDS role-badge colour. Any `driver`/`jeeber` in the active or available
  /// roles flips it.
  bool get isJeeber {
    bool isJeeberToken(String v) {
      final t = v.toLowerCase();
      return t == 'jeeber' || t == 'driver';
    }

    return isJeeberToken(role) || availableRoles.any(isJeeberToken);
  }

  /// Parses one row from the `POST /api/User/super-login/users` payload:
  /// `{ userId, username, active_role, available_roles:[String] }`. Returns
  /// `null` when `userId`/`username` is missing or blank so a malformed row is
  /// dropped rather than crashing the whole picker.
  static SuperLoginDemoUser? fromJson(Map<String, dynamic> json) {
    final userId = json['userId'] as String?;
    final username = json['username'] as String?;
    final activeRole = json['active_role'] as String?;
    final rawRoles = json['available_roles'];
    final availableRoles = rawRoles is List
        ? rawRoles.whereType<String>().toList(growable: false)
        : const <String>[];
    if (userId == null ||
        userId.isEmpty ||
        username == null ||
        username.isEmpty) {
      return null;
    }
    return SuperLoginDemoUser(
      userId: userId,
      name: username,
      role: (activeRole == null || activeRole.isEmpty)
          ? (availableRoles.isNotEmpty ? availableRoles.first : 'customer')
          : activeRole,
      availableRoles: availableRoles,
    );
  }
}

/// Error categories surfaced by [SuperLoginDemoUserService.fetchDemoUsers].
/// The picker only distinguishes "could not load" — both transport and
/// malformed-payload failures map to a single user-facing error string.
enum SuperLoginDemoUserError { network, unknown }

/// Thrown by [SuperLoginDemoUserService.fetchDemoUsers] on a fetch failure so
/// the picker can render an OMDS error state with a Retry CTA.
class SuperLoginDemoUserException implements Exception {
  const SuperLoginDemoUserException(this.error);
  final SuperLoginDemoUserError error;

  @override
  String toString() => 'SuperLoginDemoUserException($error)';
}

/// Fetches ALL active users the picker lists. Paginates through the
/// passcode-gated LIST endpoint until `hasMore == false`.
///
/// Contract: `POST /api/User/super-login/users` (anonymous, no bearer) with
/// body `{ superAdminPassCode, skip, limit, onActive:true }` →
/// `{ users:[{userId, username, active_role, available_roles}], totalCount,
/// skip, limit, hasMore }`.
abstract class SuperLoginDemoUserService {
  Future<List<SuperLoginDemoUser>> fetchDemoUsers();
}

/// [Dio]-backed implementation talking to the live gateway via the app's
/// shared client. Reuses the same `Dio` instance every other gateway data
/// source uses (DI `sl<Dio>()`). The SuperAdmin passcode is injected from
/// `AppConfig` (build-time `--dart-define` or the debug fallback); it is sent
/// in the POST body and is NEVER logged.
class DefaultSuperLoginDemoUserService implements SuperLoginDemoUserService {
  DefaultSuperLoginDemoUserService({
    required Dio dio,
    required String superAdminPassCode,
  })  : _dio = dio,
        _passcode = superAdminPassCode;

  final Dio _dio;
  final String _passcode;

  static const String _endpoint = '/api/User/super-login/users';

  /// Page size; the contract caps `limit` at 100.
  static const int _pageLimit = 100;

  /// Safety cap so a misbehaving `hasMore` can never loop forever
  /// (50 pages * 100 = 5000 users, far above the ~56 active expected).
  static const int _maxPages = 50;

  @override
  Future<List<SuperLoginDemoUser>> fetchDemoUsers() async {
    final all = <SuperLoginDemoUser>[];
    try {
      for (var page = 0, skip = 0;
          page < _maxPages;
          page++, skip += _pageLimit) {
        final data = await _fetchPage(skip);
        all.addAll(_parseRows(data));
        if (data['hasMore'] != true) break;
      }
    } on DioException {
      throw const SuperLoginDemoUserException(SuperLoginDemoUserError.network);
    }
    return List<SuperLoginDemoUser>.unmodifiable(all);
  }

  Future<Map<String, dynamic>> _fetchPage(int skip) async {
    final response = await _dio.post<Map<String, dynamic>>(
      _endpoint,
      data: <String, dynamic>{
        'superAdminPassCode': _passcode,
        'skip': skip,
        'limit': _pageLimit,
        'onActive': true,
      },
    );
    final data = response.data;
    if (data == null) {
      throw const SuperLoginDemoUserException(SuperLoginDemoUserError.unknown);
    }
    return data;
  }

  Iterable<SuperLoginDemoUser> _parseRows(Map<String, dynamic> data) {
    final raw = data['users'];
    if (raw is! List) {
      throw const SuperLoginDemoUserException(SuperLoginDemoUserError.unknown);
    }
    return raw
        .whereType<Map<String, dynamic>>()
        .map(SuperLoginDemoUser.fromJson)
        .whereType<SuperLoginDemoUser>();
  }
}
