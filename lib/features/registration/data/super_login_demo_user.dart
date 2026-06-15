import 'package:dio/dio.dart';

/// A predefined demo-user roster row used by the "Super user login plus"
/// picker (debug-only). Each row carries the credential the picker pre-fills
/// into the existing super-login sheet.
///
/// SECURITY: these are obviously-fake dev passcodes (e.g. `demo-nour`), never
/// the org secret. The whole surface is compiled out of release builds — the
/// picker is only ever mounted under `kDebugMode`.
class SuperLoginDemoUser {
  const SuperLoginDemoUser({
    required this.userId,
    required this.name,
    required this.role,
    required this.passcode,
  });

  /// Pinned UUIDv4 the picker pre-fills into the sheet's userId field.
  final String userId;

  /// Display name shown in the picker row (e.g. "Nour").
  final String name;

  /// `"client"` or `"jeeber"` — drives the OMDS role badge colour.
  final String role;

  /// Dev passcode the picker pre-fills into the sheet's passcode field. The
  /// sheet still POSTs this to the gateway for real server-side validation;
  /// it is NEVER compared client-side.
  final String passcode;

  /// True when the row represents a jeeber (dual-role) user; drives the badge.
  bool get isJeeber => role.toLowerCase() == 'jeeber';

  /// Parses one roster row from the `GET /api/User/demo-users` payload. Returns
  /// `null` when a required field is missing or blank so a malformed row is
  /// dropped rather than crashing the whole picker.
  static SuperLoginDemoUser? fromJson(Map<String, dynamic> json) {
    final userId = json['userId'] as String?;
    final name = json['name'] as String?;
    final role = json['role'] as String?;
    final passcode = json['passcode'] as String?;
    if (userId == null ||
        userId.isEmpty ||
        name == null ||
        name.isEmpty ||
        role == null ||
        role.isEmpty ||
        passcode == null ||
        passcode.isEmpty) {
      return null;
    }
    return SuperLoginDemoUser(
      userId: userId,
      name: name,
      role: role,
      passcode: passcode,
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

/// Fetches the predefined demo-user roster the picker lists. Mirrors
/// [SuperLoginService] in shape so the two dev/auth data sources share one
/// mental model.
///
/// Contract: `GET /api/User/demo-users` →
/// `{ "users": [ { "userId", "name", "role", "passcode" }, ... ] }`.
/// The endpoint is a dev/demo surface (anon-accessible, no auth header).
abstract class SuperLoginDemoUserService {
  Future<List<SuperLoginDemoUser>> fetchDemoUsers();
}

/// [Dio]-backed implementation talking to the mock gateway (`:3055`) via the
/// app's shared client. Reuses the same `Dio` instance every other gateway
/// data source uses (DI `sl<Dio>()`).
class DefaultSuperLoginDemoUserService implements SuperLoginDemoUserService {
  DefaultSuperLoginDemoUserService({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const String _endpoint = '/api/User/demo-users';

  @override
  Future<List<SuperLoginDemoUser>> fetchDemoUsers() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(_endpoint);
      final raw = response.data?['users'];
      if (raw is! List) {
        throw const SuperLoginDemoUserException(
          SuperLoginDemoUserError.unknown,
        );
      }
      return raw
          .whereType<Map<String, dynamic>>()
          .map(SuperLoginDemoUser.fromJson)
          .whereType<SuperLoginDemoUser>()
          .toList(growable: false);
    } on DioException {
      throw const SuperLoginDemoUserException(
        SuperLoginDemoUserError.network,
      );
    }
  }
}
