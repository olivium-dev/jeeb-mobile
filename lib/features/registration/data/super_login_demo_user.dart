import 'package:dio/dio.dart';

/// One active-user row from GET /api/User/super-login/users.
class SuperLoginDemoUser {
  const SuperLoginDemoUser({
    required this.userId,
    required this.name,
    required this.role,
    this.availableRoles = const <String>[],
  });

  final String userId;
  final String name;

  /// active_role; drives the role badge.
  final String role;

  /// available_roles; customer who can also drive badged as jeeber.
  final List<String> availableRoles;

  /// True when user is jeeber/driver.
  bool get isJeeber {
    bool isJeeberToken(String v) {
      final t = v.toLowerCase();
      return t == 'jeeber' || t == 'driver';
    }

    return isJeeberToken(role) || availableRoles.any(isJeeberToken);
  }

  /// Parses multiple contract versions; returns null if userId/name missing.
  static SuperLoginDemoUser? fromJson(Map<String, dynamic> json) {
    final userId = json['userId'] as String?;
    final username = (json['name'] ?? json['username']) as String?;
    final activeRole = (json['active_role'] ?? json['role']) as String?;
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

enum SuperLoginDemoUserError { network, unknown }

class SuperLoginDemoUserException implements Exception {
  const SuperLoginDemoUserException(this.error);
  final SuperLoginDemoUserError error;

  @override
  String toString() => 'SuperLoginDemoUserException($error)';
}

/// Fetches full user roster from GET /api/User/super-login/users.
abstract class SuperLoginDemoUserService {
  Future<List<SuperLoginDemoUser>> fetchDemoUsers();
}

/// Dio-backed implementation using shared client (sl`<Dio>`()).
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
