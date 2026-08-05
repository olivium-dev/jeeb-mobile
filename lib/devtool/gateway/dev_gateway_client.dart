import 'package:dio/dio.dart';

import '../../core/di/injection_container.dart';

class DevGatewayClient {
  DevGatewayClient({
    Dio? dio,
    this.serviceAuthKey = '',
    this.serviceAuthHeaderName = 'X-Service-Auth-Key',
  }) : _dio = dio ?? sl<Dio>();

  final Dio _dio;

  final String serviceAuthKey;

  final String serviceAuthHeaderName;

  static const String _usersPath = '/dev/data/users';
  static const String _superLoginRosterPath = '/api/User/super-login/users';
  static const String _seedUserPath = '/dev/seed/user';
  static const String _mintPath = '/auth/tokens';

  static const String _conversationsPath = '/v1/conversations';

  Future<List<DevUser>> listUsers({int skip = 0, int limit = 100}) async {
    if (skip < 0) {
      throw ArgumentError.value(skip, 'skip', 'Must not be negative.');
    }
    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(limit, 'limit', 'Must be within 1..100.');
    }
    DioException? rosterError;
    DioException? directoryError;
    List<DevUser>? roster;
    List<DevUser>? directory;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _superLoginRosterPath,
      );
      roster = _parseUsers(response.data);
    } on DioException catch (error) {
      rosterError = error;
    }
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _usersPath,
        queryParameters: <String, dynamic>{'skip': skip, 'limit': limit},
      );
      directory = _parseUsers(response.data);
    } on DioException catch (error) {
      directoryError = error;
    }

    if (roster == null && directory == null) {
      throw DevGatewayException.fromDio(
        rosterError ?? directoryError!,
        action: 'list the super-login user roster',
      );
    }

    final directoryById = <String, DevUser>{
      for (final user in directory ?? const <DevUser>[])
        if (user.id.isNotEmpty) user.id: user,
    };
    final merged = <DevUser>[];
    for (final user in roster ?? const <DevUser>[]) {
      if (user.id.isEmpty) continue;
      merged.add(user.mergeDirectory(directoryById.remove(user.id)));
    }
    merged.addAll(directoryById.values);
    return List<DevUser>.unmodifiable(merged);
  }

  static List<DevUser> _parseUsers(Map<String, dynamic>? data) {
    final rawUsers = data?['users'];
    if (rawUsers is! List) return const <DevUser>[];
    return rawUsers
        .whereType<Map<String, dynamic>>()
        .map(DevUser.fromJson)
        .where((user) => user.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<DevUser> seedUser({
    required String role,
    String? scenario,
    String? phone,
    String? displayName,
  }) async {
    final body = <String, dynamic>{
      'role': role,
      'phone': phone ?? _derivedPhone(),
      'displayName': displayName ?? _derivedDisplayName(role),
      if (scenario != null && scenario.isNotEmpty) 'scenario': scenario,
    };
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _seedUserPath,
        data: body,
      );
      final data = response.data;
      if (data == null) {
        throw const DevGatewayException(
          'The gateway returned an empty seed response.',
        );
      }
      return DevUser.fromJson(data);
    } on DioException catch (e) {
      throw DevGatewayException.fromDio(e, action: 'seed dev user');
    }
  }

  Future<String> mintTokenForUser(String userId, {List<String>? roles}) async {
    final headers = <String, dynamic>{
      if (serviceAuthKey.isNotEmpty) serviceAuthHeaderName: serviceAuthKey,
    };
    final nonEmptyRoles = roles
        ?.where((r) => r.trim().isNotEmpty)
        .toList(growable: false);
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _mintPath,
        data: <String, dynamic>{
          'userId': userId,
          if (nonEmptyRoles != null && nonEmptyRoles.isNotEmpty)
            'roles': nonEmptyRoles,
        },
        options: Options(headers: headers),
      );
      final token = response.data?['accessToken'] as String?;
      if (token == null || token.isEmpty) {
        throw const DevGatewayException(
          'The token mint returned no accessToken.',
        );
      }
      return token;
    } on DioException catch (e) {
      throw DevGatewayException.fromDio(e, action: 'mint act-as token');
    }
  }

  Future<void> initiateOffer({
    required String asUserId,
    required String requestId,
    required double fee,
    required int etaMinutes,
    String? note,
    String? asRole,
  }) async {
    final token = await mintTokenForUser(asUserId, roles: _roles(asRole));
    final body = <String, dynamic>{
      'fee': fee,
      'etaMinutes': etaMinutes,
      if (note != null && note.isNotEmpty) 'note': note,
    };
    try {
      await _dio.post<Map<String, dynamic>>(
        '/v1/requests/$requestId/offers',
        data: body,
        options: _bearer(token),
      );
    } on DioException catch (e) {
      throw DevGatewayException.fromDio(e, action: 'initiate offer');
    }
  }

  Future<void> acceptOffer({
    required String asUserId,
    required String offerId,
    String? idempotencyKey,
    String? asRole,
  }) async {
    final token = await mintTokenForUser(asUserId, roles: _roles(asRole));
    final extra = <String, dynamic>{
      if (idempotencyKey != null && idempotencyKey.isNotEmpty)
        'Idempotency-Key': idempotencyKey,
    };
    try {
      await _dio.post<Map<String, dynamic>>(
        '/v1/offers/$offerId/accept',
        options: _bearer(token, extraHeaders: extra),
      );
    } on DioException catch (e) {
      throw DevGatewayException.fromDio(e, action: 'accept offer');
    }
  }

  Future<String> sendMessage({
    required String asUserId,
    required String requestId,
    required String text,
    String? asRole,
  }) async {
    final token = await mintTokenForUser(asUserId, roles: _roles(asRole));
    final conversationId = await _resolveConversationId(requestId, token);
    try {
      await _dio.post<Map<String, dynamic>>(
        '$_conversationsPath/$conversationId/messages',
        data: <String, dynamic>{'kind': 'text', 'body': text},
        options: _bearer(
          token,
          extraHeaders: <String, dynamic>{
            'Idempotency-Key':
                'devtool-send-${DateTime.now().microsecondsSinceEpoch}',
          },
        ),
      );
      return conversationId;
    } on DioException catch (e) {
      throw DevGatewayException.fromDio(e, action: 'send message');
    }
  }

  Future<String> _resolveConversationId(String requestId, String token) async {
    const action = 'resolve the conversation for that request';
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _conversationsPath,
        queryParameters: <String, dynamic>{'correlationKey': requestId},
        options: _bearer(token),
      );
      final conversationId = response.data?['conversation_id'] as String?;
      if (conversationId == null || conversationId.isEmpty) {
        throw const DevGatewayException(
          'The gateway returned a conversation row without a '
          '`conversation_id`.',
        );
      }
      return conversationId;
    } on DioException catch (e) {
      throw DevGatewayException.fromDio(
        e,
        action: action,
        notFoundMessage:
            'Could not $action: no conversation is correlated with that '
            'request id (404). A request has no conversation until one is '
            'provisioned for it — check the ID, or drive the order far enough '
            'for chat to exist.',
      );
    }
  }

  Options _bearer(String token, {Map<String, dynamic>? extraHeaders}) {
    return Options(
      headers: <String, dynamic>{
        'Authorization': 'Bearer $token',
        ...?extraHeaders,
      },
    );
  }

  static String _derivedPhone() =>
      '+100${DateTime.now().microsecondsSinceEpoch % 10000000}';

  static String _derivedDisplayName(String role) =>
      'devtool_${role}_${DateTime.now().millisecondsSinceEpoch}';

  static List<String>? _roles(String? role) =>
      (role == null || role.trim().isEmpty) ? null : <String>[role.trim()];
}

class DevUser {
  const DevUser({
    required this.id,
    required this.username,
    required this.status,
    this.role,
    this.roles = const <String>[],
    this.email,
    this.phone,
    this.displayName,
  });

  factory DevUser.fromJson(Map<String, dynamic> json) {
    return DevUser(
      id: (json['userId'] as String?) ?? (json['id'] as String?) ?? '',
      username:
          (json['username'] as String?) ?? (json['name'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'unknown',
      role: _roleFromJson(json),
      roles: _rolesFromJson(json),
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      displayName:
          (json['displayName'] as String?) ?? (json['name'] as String?),
    );
  }

  final String id;

  final String username;

  final String status;

  final String? role;
  final List<String> roles;

  final String? email;

  /// E.164 phone echoed on seed; null on the list view.
  final String? phone;

  final String? displayName;

  bool get isJeeber => roles.any(_isJeeberRole);

  String? get roleForOfferInitiation {
    for (final availableRole in roles) {
      if (_isJeeberRole(availableRole)) return availableRole;
    }
    return role != null && _isJeeberRole(role!) ? role : null;
  }

  DevUser mergeDirectory(DevUser? directory) {
    if (directory == null) return this;
    return DevUser(
      id: id,
      username: username.isNotEmpty ? username : directory.username,
      status: directory.status,
      role: role,
      roles: roles,
      email: directory.email ?? email,
      phone: directory.phone ?? phone,
      displayName: displayName ?? directory.displayName,
    );
  }

  static String? _roleFromJson(Map<String, dynamic> json) {
    final role = json['active_role'] ?? json['role'];
    if (role is String && role.trim().isNotEmpty) return role.trim();
    return null;
  }

  static List<String> _rolesFromJson(Map<String, dynamic> json) {
    final roles = json['roles'] ?? json['available_roles'];
    if (roles is! List) return const <String>[];
    return List<String>.unmodifiable(
      roles
          .whereType<String>()
          .map((role) => role.trim())
          .where((role) => role.isNotEmpty),
    );
  }

  static bool _isJeeberRole(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'driver' || normalized == 'jeeber';
  }
}

class DevGatewayException implements Exception {
  const DevGatewayException(this.message, {this.statusCode, this.action});

  factory DevGatewayException.fromDio(
    DioException e, {
    required String action,
    String? notFoundMessage,
  }) {
    final status = e.response?.statusCode;
    final String message;
    switch (status) {
      case 404:
        message =
            notFoundMessage ??
            'Could not $action: the gateway dev endpoints are disabled '
                '(404). Enable Features:DevEndpoints on the target gateway.';
      case 410:
        message =
            'Could not $action: that gateway route is RETIRED (410 Gone). '
            'This is permanent, not a transient fault — the Dev Tool is '
            'calling a surface the gateway no longer serves.';
      case 401:
        message =
            'Could not $action: unauthorized (401). The token mint needs a '
            'valid service-auth key (or SuperLogin OpenMode).';
      case 403:
        message =
            'Could not $action: forbidden (403). The provided service-auth '
            'key was rejected by the gateway mint gate.';
      case null:
        message =
            'Could not $action: could not reach the gateway '
            '(${e.type.name}). Check the Dev Tool Server URL.';
      default:
        message = 'Could not $action: the gateway returned $status.';
    }
    return DevGatewayException(message, statusCode: status, action: action);
  }

  final String message;

  final int? statusCode;

  final String? action;

  @override
  String toString() => 'DevGatewayException($message)';
}
