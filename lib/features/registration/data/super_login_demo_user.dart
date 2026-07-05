import 'package:dio/dio.dart';

/// One active-user row used by the "Super user login plus" picker (debug-only).
///
/// Sourced from the `GET /api/User/super-login/users` full-roster LIST endpoint
/// (every live user-management user). A row carries ONLY identity + role
/// display data — it deliberately carries NO passcode. On tap the picker logs in with the tapped row's
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

  /// Parses one row from the gateway `GET /api/User/super-login/users` FULL
  /// roster (`{ userId, name, role, roles:[String] }` — real users carry NO
  /// passcode; the picker re-uses the single `AppConfig` SuperAdmin passcode).
  /// Also accepts the demo-users shape (`{ userId, name, role, passcode }` —
  /// the `passcode` is deliberately IGNORED) and the legacy LIST shape
  /// (`{ userId, username, active_role, available_roles:[String] }`) so every
  /// contract parses. Returns `null` when `userId`/name is missing or blank so
  /// a malformed row is dropped rather than crashing the whole picker.
  static SuperLoginDemoUser? fromJson(Map<String, dynamic> json) {
    final userId = json['userId'] as String?;
    // Gateway roster uses `name`/`role`; the legacy LIST contract used
    // `username`/`active_role`/`available_roles`. Accept whichever is present.
    final username = (json['name'] ?? json['username']) as String?;
    final activeRole = (json['active_role'] ?? json['role']) as String?;
    // Full-roster endpoint emits `roles`; the legacy LIST shape used
    // `available_roles`. Accept whichever is present.
    final rawRoles = json['roles'] ?? json['available_roles'];
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

/// Fetches the FULL user roster the picker lists.
///
/// Contract: `GET /api/User/super-login/users` (anonymous, no bearer, no body —
/// the gateway gates it behind `SuperLogin:OpenMode` + `DemoUsers:Enabled` and
/// sources it from user-management's own list API) →
/// `{ users:[{userId, name, role, roles:[String]}] }` for EVERY live user (~84),
/// not just the 3 seeded demo rows. The gateway aggregates all pages, so the
/// whole roster comes back in one shot. Real-user rows carry NO passcode; the
/// tap→login re-uses the single `AppConfig` SuperAdmin passcode.
abstract class SuperLoginDemoUserService {
  Future<List<SuperLoginDemoUser>> fetchDemoUsers();
}

/// [Dio]-backed implementation talking to the live gateway via the app's
/// shared client. Reuses the same `Dio` instance every other gateway data
/// source uses (DI `sl<Dio>()`). The roster GET is anonymous — no passcode is
/// sent on the wire, and the row-level `passcode` in the response is never
/// read or logged (the debug redacting logger scrubs it defensively).
class DefaultSuperLoginDemoUserService implements SuperLoginDemoUserService {
  DefaultSuperLoginDemoUserService({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const String _endpoint = '/api/User/super-login/users';

  @override
  Future<List<SuperLoginDemoUser>> fetchDemoUsers() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(_endpoint);
      final data = response.data;
      if (data == null) {
        throw const SuperLoginDemoUserException(
          SuperLoginDemoUserError.unknown,
        );
      }
      return List<SuperLoginDemoUser>.unmodifiable(_parseRows(data));
    } on DioException {
      throw const SuperLoginDemoUserException(SuperLoginDemoUserError.network);
    }
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
