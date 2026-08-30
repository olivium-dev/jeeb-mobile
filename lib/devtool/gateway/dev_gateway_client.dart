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
  static const String _kycQueuePath = '/admin/kyc/queue';
  static const String _partnerCredentialPath = '/dev/partner/credentials';
  static const String _partnerLoginPath = '/v1/partner/auth/login';
  static const String _partnerWalletPath = '/v1/partner/wallet';
  static const String _partnerTransferPath = '/v1/partner/wallet/transfers';

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

  // JEB roster-diagnosis fix — the Super-Login+ "all users" picker needs ONLY
  // the super-login roster (it needs `roles` to log in as a role; the
  // `/dev/data/users` directory fallback used by listUsers() has no roles
  // field, so merging it in would not help this specific screen). Calling it
  // directly (rather than through listUsers()'s merge) also lets us give an
  // ACCURATE 404 reason: this route's real gate is SuperLogin:OpenMode +
  // DemoUsers:Enabled (see UserController.SuperLoginUsers), NOT
  // Features:DevEndpoints — the default fromDio() 404 text names the wrong
  // flag for this route, so it is overridden here.
  Future<List<DevUser>> fetchSuperLoginRoster() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _superLoginRosterPath,
      );
      return _parseUsers(response.data);
    } on DioException catch (error) {
      throw DevGatewayException.fromDio(
        error,
        action: 'load the full user roster',
        notFoundMessage:
            'Could not load the full user roster: this environment has the '
            'Super-Login+ roster turned off (404). SuperLogin:OpenMode and '
            'DemoUsers:Enabled must both be true on the target gateway to '
            'serve it — this is a deliberate security gate, not a Server URL '
            'problem.',
      );
    }
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

  // Like mintTokenForUser but returns the refresh token too, so the caller
  // can persist a full session (used to make a seeded jeeber online-ready).
  Future<({String accessToken, String refreshToken})> mintSession(
    String userId, {
    List<String>? roles,
  }) async {
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
      );
      final access = response.data?['accessToken'] as String?;
      final refresh = response.data?['refreshToken'] as String?;
      if (access == null || access.isEmpty) {
        throw const DevGatewayException(
          'The token mint returned no accessToken.',
        );
      }
      if (refresh == null || refresh.isEmpty) {
        throw const DevGatewayException(
          'The token mint returned no refreshToken — the session would be '
          'non-refreshable and drop to logged-out on first token expiry.',
        );
      }
      return (accessToken: access, refreshToken: refresh);
    } on DioException catch (e) {
      throw DevGatewayException.fromDio(e, action: 'mint jeeber session');
    }
  }

  // 200/404 => availability loads (404 = no row yet, mirrors production
  // DioAvailabilityGateway); 403 => missing driver capability (not ready).
  Future<bool> availabilityLoads(String accessToken) async {
    try {
      await _dio.get<Map<String, dynamic>>(
        '/jeebers/me/availability',
        options: _bearer(accessToken),
      );
      return true;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 403) return false;
      if (status == 404) return true;
      throw DevGatewayException.fromDio(
        e,
        action: 'verify jeeber availability',
      );
    }
  }

  // Finds the pending KYC submission id for [userId] in the admin review
  // queue, or null when the jeeber has no submission awaiting review.
  Future<String?> findKycSubmissionId(String userId, String adminToken) async {
    const pageSize = 100;
    try {
      for (var page = 1; page <= 50; page++) {
        final response = await _dio.get<Map<String, dynamic>>(
          _kycQueuePath,
          queryParameters: <String, dynamic>{
            'page': page,
            'pageSize': pageSize,
          },
          options: _bearer(adminToken),
        );
        final data = response.data ?? const <String, dynamic>{};
        final items = data['items'];
        if (items is! List || items.isEmpty) return null;
        for (final item in items.whereType<Map<String, dynamic>>()) {
          if (item['userId'] == userId) {
            final id = item['id'] as String?;
            if (id != null && id.isNotEmpty) return id;
          }
        }
        final total = (data['total'] as num?)?.toInt();
        if (total == null || page * pageSize >= total) return null;
      }
      return null;
    } on DioException catch (e) {
      throw DevGatewayException.fromDio(
        e,
        action: 'resolve the jeeber KYC submission',
      );
    }
  }

  // Approves the jeeber's KYC via the sanctioned admin review route;
  // returns the gateway's roleGranted flag (driver capability granted).
  Future<bool> approveKyc(String kycId, String adminToken) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/admin/kyc/$kycId/review',
        data: <String, dynamic>{'action': 'approve'},
        options: _bearer(adminToken),
      );
      return response.data?['roleGranted'] == true;
    } on DioException catch (e) {
      throw DevGatewayException.fromDio(e, action: 'approve jeeber KYC');
    }
  }

  Future<void> provisionPartnerCredential({
    required String identifier,
    required String holderId,
    required String displayName,
    required String password,
  }) async {
    try {
      await _dio.post<void>(
        _partnerCredentialPath,
        data: <String, dynamic>{
          'identifier': identifier,
          'holderId': holderId,
          'displayName': displayName,
          'password': password,
        },
      );
    } on DioException catch (e) {
      throw DevGatewayException.fromDio(
        e,
        action: 'provision the demo partner wallet',
      );
    }
  }

  Future<void> removePartnerCredential(
    String identifier, {
    required String holderId,
  }) async {
    try {
      await _dio.delete<void>(
        '$_partnerCredentialPath/$identifier',
        queryParameters: <String, dynamic>{'holderId': holderId},
      );
    } on DioException catch (e) {
      throw DevGatewayException.fromDio(
        e,
        action: 'remove the temporary partner credential',
      );
    }
  }

  Future<void> ensureJeeberWallet(String holderId) async {
    try {
      await _dio.put<void>('/dev/wallets/jeeber/$holderId/ensure');
    } on DioException catch (e) {
      throw DevGatewayException.fromDio(
        e,
        action: 'provision the Jeeber wallet',
      );
    }
  }

  Future<DevPartnerSession> loginPartner({
    required String identifier,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _partnerLoginPath,
        data: <String, dynamic>{'identifier': identifier, 'password': password},
      );
      final data = response.data ?? const <String, dynamic>{};
      final partner = data['partner'];
      final token = (data['accessToken'] ?? data['token']) as String?;
      final partnerId = partner is Map<String, dynamic>
          ? partner['partnerId'] as String?
          : null;
      if (token == null ||
          token.isEmpty ||
          partnerId == null ||
          partnerId.isEmpty) {
        throw const DevGatewayException(
          'The partner login returned an incomplete session.',
        );
      }
      return DevPartnerSession(accessToken: token, partnerId: partnerId);
    } on DioException catch (e) {
      throw DevGatewayException.fromDio(e, action: 'sign in the demo partner');
    }
  }

  Future<DevWalletBalance> readJeeberWallet({
    required String userId,
    required String accessToken,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/jeeb/wallet',
        options: _bearer(accessToken),
      );
      final data = response.data ?? const <String, dynamic>{};
      return DevWalletBalance(
        holderId: userId,
        amount: (data['availableBalance'] as num?)?.toDouble() ?? 0,
        currency: data['currency'] as String?,
      );
    } on DioException catch (e) {
      throw DevGatewayException.fromDio(e, action: 'read the Jeeber wallet');
    }
  }

  Future<DevWalletBalance> readPartnerWallet({
    required String accessToken,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _partnerWalletPath,
        options: _bearer(accessToken),
      );
      final data = response.data ?? const <String, dynamic>{};
      return DevWalletBalance(
        holderId: data['partnerId'] as String? ?? '',
        amount: (data['balance'] as num?)?.toDouble() ?? 0,
        currencyId: (data['currencyId'] as num?)?.toInt(),
      );
    } on DioException catch (e) {
      throw DevGatewayException.fromDio(e, action: 'read the partner wallet');
    }
  }

  Future<DevWalletMove> creditPartner({
    required String partnerId,
    required double amount,
    required String adminToken,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/admin/partners/$partnerId/wallet/credits',
        data: <String, dynamic>{
          'amount': amount,
          'evidenceNote': 'Dev Tool staging wallet-funding demo',
          'idempotencyKey': idempotencyKey,
        },
        options: _bearer(adminToken),
      );
      return DevWalletMove.fromJson(response.data);
    } on DioException catch (e) {
      throw DevGatewayException.fromDio(
        e,
        action: 'cash-credit the demo partner',
        uncertainOnMoneyTransport: true,
      );
    }
  }

  Future<DevTopupPreview> predictPartnerTopup({
    required String jeeberId,
    required double amount,
    required String partnerToken,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_partnerTransferPath/predict',
        data: <String, dynamic>{'jeeberId': jeeberId, 'amount': amount},
        options: _bearer(partnerToken),
      );
      return DevTopupPreview.fromJson(response.data);
    } on DioException catch (e) {
      throw DevGatewayException.fromDio(e, action: 'preview the Jeeber top-up');
    }
  }

  Future<DevPartnerOtp> requestPartnerTopupOtp({
    required String jeeberId,
    required double amount,
    required String partnerToken,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_partnerTransferPath/otp/challenge',
        data: <String, dynamic>{'jeeberId': jeeberId, 'amount': amount},
        options: _bearer(partnerToken),
      );
      final data = response.data ?? const <String, dynamic>{};
      final challengeId = data['challengeId'] as String?;
      final devCode = data['devCode'] as String?;
      if (challengeId == null ||
          challengeId.isEmpty ||
          devCode == null ||
          devCode.isEmpty) {
        throw const DevGatewayException(
          'The staging OTP challenge returned no in-app demo code.',
        );
      }
      return DevPartnerOtp(challengeId: challengeId, code: devCode);
    } on DioException catch (e) {
      throw DevGatewayException.fromDio(e, action: 'request the top-up OTP');
    }
  }

  Future<DevWalletMove> executePartnerTopup({
    required String jeeberId,
    required double amount,
    required String partnerToken,
    required String idempotencyKey,
    DevPartnerOtp? otp,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _partnerTransferPath,
        data: <String, dynamic>{
          'jeeberId': jeeberId,
          'amount': amount,
          'idempotencyKey': idempotencyKey,
          'note': 'Dev Tool staging wallet-funding demo',
          if (otp != null) 'otpChallengeId': otp.challengeId,
          if (otp != null) 'otpCode': otp.code,
        },
        options: _bearer(partnerToken),
      );
      return DevWalletMove.fromJson(response.data);
    } on DioException catch (e) {
      throw DevGatewayException.fromDio(
        e,
        action: 'fund the Jeeber wallet',
        uncertainOnMoneyTransport: true,
      );
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

  static String suggestedUsername(String role) => _derivedDisplayName(role);

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

class DevPartnerSession {
  const DevPartnerSession({required this.accessToken, required this.partnerId});

  final String accessToken;
  final String partnerId;
}

class DevWalletBalance {
  const DevWalletBalance({
    required this.holderId,
    required this.amount,
    this.currency,
    this.currencyId,
  });

  final String holderId;
  final double amount;
  final String? currency;
  final int? currencyId;
}

class DevTopupPreview {
  const DevTopupPreview({
    required this.grossAmount,
    required this.fees,
    required this.netToJeeber,
    required this.otpRequired,
  });

  factory DevTopupPreview.fromJson(Map<String, dynamic>? data) {
    final body = data ?? const <String, dynamic>{};
    final otpRequired = body['otpRequired'];
    if (otpRequired is! bool) {
      throw const DevGatewayException(
        'The top-up preview did not declare its OTP policy.',
      );
    }
    return DevTopupPreview(
      grossAmount: (body['grossAmount'] as num?)?.toDouble() ?? 0,
      fees: (body['fees'] as num?)?.toDouble() ?? 0,
      netToJeeber: (body['netToJeeber'] as num?)?.toDouble() ?? 0,
      otpRequired: otpRequired,
    );
  }

  final double grossAmount;
  final double fees;
  final double netToJeeber;
  final bool otpRequired;
}

class DevWalletMove {
  const DevWalletMove({
    required this.transactionId,
    required this.amount,
    required this.fees,
    required this.status,
  });

  factory DevWalletMove.fromJson(Map<String, dynamic>? data) {
    final body = data ?? const <String, dynamic>{};
    final transactionId = body['transactionId'] as String?;
    if (transactionId == null || transactionId.isEmpty) {
      throw const DevGatewayException.walletVerification(
        'The wallet operation returned no transaction id.',
      );
    }
    return DevWalletMove(
      transactionId: transactionId,
      amount: (body['amount'] as num?)?.toDouble() ?? 0,
      fees: (body['fees'] as num?)?.toDouble() ?? 0,
      status: body['status'] as String? ?? 'unknown',
    );
  }

  final String transactionId;
  final double amount;
  final double fees;
  final String status;
}

class DevPartnerOtp {
  const DevPartnerOtp({required this.challengeId, required this.code});

  final String challengeId;
  final String code;
}

class DevGatewayException implements Exception {
  const DevGatewayException(
    this.message, {
    this.statusCode,
    this.action,
    this.problemType,
  });

  const DevGatewayException.walletVerification(String message)
    : this(
        message,
        problemType:
            'https://jeeb.dev/errors/devtool-wallet-verification-failed',
      );

  factory DevGatewayException.fromDio(
    DioException e, {
    required String action,
    String? notFoundMessage,
    bool uncertainOnMoneyTransport = false,
  }) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    final problem = data is Map<String, dynamic>
        ? data
        : const <String, dynamic>{};
    var problemType = problem['type'] as String?;
    final detail = problem['detail'] as String?;
    final title = problem['title'] as String?;
    final String message;
    if (uncertainOnMoneyTransport &&
        (status == null || status >= 500) &&
        problemType == null) {
      problemType =
          'https://jeeb.dev/errors/devtool-wallet-transport-uncertain';
    }
    if (problemType == 'https://jeeb.dev/errors/partner-wallet-uncertain' ||
        problemType == 'https://jeeb.dev/errors/partner-wallet-in-flight' ||
        problemType ==
            'https://jeeb.dev/errors/devtool-wallet-transport-uncertain') {
      message =
          'The wallet result is uncertain and may already be committed. '
          'Do not retry this operation; reconcile the displayed operation id.';
    } else if (problemType?.contains('/otp-') == true) {
      message =
          detail ?? title ?? 'The staging wallet OTP could not be verified.';
    } else {
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
          message =
              detail ??
              title ??
              'Could not $action: the gateway returned $status.';
      }
    }
    return DevGatewayException(
      message,
      statusCode: status,
      action: action,
      problemType: problemType,
    );
  }

  final String message;

  final int? statusCode;

  final String? action;

  final String? problemType;

  bool get isUncertainWalletMove =>
      problemType == 'https://jeeb.dev/errors/partner-wallet-uncertain' ||
      problemType == 'https://jeeb.dev/errors/partner-wallet-in-flight' ||
      problemType ==
          'https://jeeb.dev/errors/devtool-wallet-transport-uncertain' ||
      problemType ==
          'https://jeeb.dev/errors/devtool-wallet-verification-failed';

  @override
  String toString() => 'DevGatewayException($message)';
}
