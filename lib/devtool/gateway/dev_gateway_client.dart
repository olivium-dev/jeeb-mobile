import 'package:dio/dio.dart';

import '../../core/di/injection_container.dart';

/// Typed client for the gateway's flag-gated developer endpoints
/// (`/dev/*`) plus the "act-as" product actions the Dev Tool drives on
/// behalf of a seeded user (DT-06 Actions, DT-07 Scenario Users).
///
/// Wraps the app's shared [Dio] (resolved from `sl<Dio>()`), so it
/// automatically honours the Dev Tool's persisted Server-URL override —
/// the same client every other gateway data source uses.
///
/// ## Endpoint map (verified against `JeebGateway` source)
/// - `GET  /dev/data/users`              → [listUsers]
/// - `POST /dev/seed/user`               → [seedUser]
/// - `POST /auth/tokens`                 → [mintTokenForUser] (act-as mint)
/// - `POST /v1/requests/{id}/offers`     → [initiateOffer]
/// - `POST /v1/offers/{id}/accept`       → [acceptOffer]
/// - `GET  /v1/conversations?correlationKey={requestId}` → [sendMessage] (resolve)
/// - `POST /v1/conversations/{id}/messages` → [sendMessage] (append)
///
/// ## Why "send message" is keyed on a REQUEST id, not a channel id
/// The Dev Tool used to `POST /api/Chat/channels/{channelId}/messages`.
/// `jeeb-gateway` #350 retired that route: it wrote documents under a
/// superseded `Channels/{id}/Messages/{guid}` Firestore schema that nothing
/// could read, and it now answers **410 Gone**
/// (`https://jeeb.dev/errors/legacy-channel-write-retired`).
///
/// The live surface, `POST /v1/conversations/{conversationId}/messages`, keys
/// on a **conversation id** — a different aggregate from a channel id, with no
/// mapping between them. A channel id therefore cannot be translated, and this
/// client does not pretend otherwise. What the gateway DOES expose is
/// `correlation_key == request_id` (see `JeebConversationResponse`), so the
/// action is re-scoped onto the request id — the handle a reviewer already
/// holds and already types into "Initiate offer". [sendMessage] resolves
/// requestId → conversationId over the same route the product chat path uses
/// (`DioChatGateway.loadPhase`), then appends.
///
/// ## Gating
/// The `/dev/*` routes carry `[DevOnly]` and are anonymous-by-design: they
/// need **no** secret header, but return **404** when
/// `Features:DevEndpoints:Enabled` is off. The token mint
/// (`POST /auth/tokens`) is gated by the `X-Service-Auth-Key` header unless
/// the gateway runs with `SuperLogin:OpenMode=true` (the demo default). Pass
/// [serviceAuthKey] when the target gateway requires the key; leave it empty
/// for an open-mode / local gateway. A flag-off gateway surfaces as a
/// [DevGatewayException] with a clear message rather than a crash.
class DevGatewayClient {
  /// Creates a client bound to [dio] (defaults to the app's shared
  /// `sl<Dio>()`), optionally carrying the privileged token-mint key.
  ///
  /// [serviceAuthKey] is sent in the [serviceAuthHeaderName] header on
  /// [mintTokenForUser]; when empty the header is omitted (open-mode
  /// gateways mint without it).
  DevGatewayClient({
    Dio? dio,
    this.serviceAuthKey = '',
    this.serviceAuthHeaderName = 'X-Service-Auth-Key',
  }) : _dio = dio ?? sl<Dio>();

  final Dio _dio;

  /// Privileged key for the `POST /auth/tokens` mint gate. Empty ⇒ omitted.
  final String serviceAuthKey;

  /// Header name carrying [serviceAuthKey] (gateway default
  /// `X-Service-Auth-Key`; overridable for a differently-configured env).
  final String serviceAuthHeaderName;

  // --- Route constants (exact gateway paths). -----------------------------
  static const String _usersPath = '/dev/data/users';
  static const String _seedUserPath = '/dev/seed/user';
  static const String _mintPath = '/auth/tokens';

  /// Correlation-key resolver: `?correlationKey={requestId}` → the conversation
  /// row. This is the route `DioChatGateway` uses, so the Dev Tool exercises
  /// the same surface the product does rather than a tooling-only alias.
  static const String _conversationsPath = '/v1/conversations';

  // ------------------------------------------------------------------------
  // Dev data / seed endpoints.
  // ------------------------------------------------------------------------

  /// `GET /dev/data/users` — the seeded-user roster.
  ///
  /// Returns the shaped `DevUserView[]` from `DevUsersResponse.users`.
  /// Throws [DevGatewayException] on transport failure or when the dev flag
  /// is off (404).
  Future<List<DevUser>> listUsers() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(_usersPath);
      final data = response.data ?? const <String, dynamic>{};
      final rawUsers = data['users'];
      if (rawUsers is! List) {
        return const <DevUser>[];
      }
      return rawUsers
          .whereType<Map<String, dynamic>>()
          .map(DevUser.fromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      throw DevGatewayException.fromDio(e, action: 'list dev users');
    }
  }

  /// `POST /dev/seed/user` — create a REAL user-management user.
  ///
  /// [role] is `client` | `jeeber` | `admin`. [scenario] (DT-07) requests a
  /// richer post-seed lifecycle state when the gateway supports it. [phone]
  /// and [displayName] fall back to deterministic derived values when null.
  /// Returns the seeded [DevUser] (carries the canonical `userId`).
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

  // ------------------------------------------------------------------------
  // Act-as mint + product actions.
  // ------------------------------------------------------------------------

  /// `POST /auth/tokens` — mint an act-as access token for [userId].
  ///
  /// Body `{ "userId": ... }`; carries [serviceAuthHeaderName] when
  /// [serviceAuthKey] is set. Returns the bearer **access token** string.
  /// A missing/invalid key surfaces as a [DevGatewayException] (401/403).
  ///
  /// [roles] (e.g. `['jeeber']`) is threaded into the mint so the act-as token
  /// carries the user's capability claims — without it the gateway rejects
  /// role-gated product calls (e.g. a jeeber-only offer). Pass the picked user's
  /// role from `GET /dev/data/users` ([DevUser.role]); omitted when null/empty.
  Future<String> mintTokenForUser(String userId, {List<String>? roles}) async {
    final headers = <String, dynamic>{
      if (serviceAuthKey.isNotEmpty) serviceAuthHeaderName: serviceAuthKey,
    };
    final nonEmptyRoles =
        roles?.where((r) => r.trim().isNotEmpty).toList(growable: false);
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

  /// Initiate an offer AS [asUserId] on [requestId].
  ///
  /// Mints an act-as token, then `POST /v1/requests/{requestId}/offers` with
  /// body `{ fee, etaMinutes, note? }` (`CreateOfferBody`). [fee] is the
  /// gross fee in the client's currency (gateway floor $1); [etaMinutes] must
  /// be a positive integer.
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

  /// Accept an offer AS [asUserId] (the request-owning client).
  ///
  /// Mints an act-as token, then `POST /v1/offers/{offerId}/accept` (no
  /// body). [idempotencyKey] is forwarded as the `Idempotency-Key` header
  /// when supplied.
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

  /// Send a chat message AS [asUserId] into the conversation correlated with
  /// [requestId]. Returns the resolved conversation id so the caller can show
  /// which aggregate the message actually landed in.
  ///
  /// Three hops, all against live product routes:
  ///  1. mint an act-as token for [asUserId];
  ///  2. `GET /v1/conversations?correlationKey={requestId}` → `conversation_id`;
  ///  3. `POST /v1/conversations/{conversationId}/messages` with the FROZEN
  ///     Contract E text body `{ "kind": "text", "body": … }`.
  ///
  /// `author_id` is stamped by the gateway from the bearer sub and is NEVER
  /// read from the body, so the act-as token is what decides who "sent" it.
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
          // Unique per Run: the gateway keys replay suppression off this
          // header, so a reusable key would make the second "Send message"
          // silently replay the first instead of posting a new line.
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

  /// Resolve `requestId` (the conversation's `correlation_key`) to its
  /// `conversation_id`.
  ///
  /// Reads **`conversation_id`** and nothing else. The gateway serializes this
  /// projection snake_case (`JeebConversationResponse`,
  /// `[Stj.JsonPropertyName("conversation_id")]`) — a live read confirms the
  /// body carries neither `id` nor `conversationId`. Accepting those spellings
  /// "just in case" is how a read path goes quietly blind, so a body without
  /// the proven key fails loudly here instead.
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
        // A 404 here is NOT the dev-endpoints flag — it is chat-service saying
        // this request has no conversation yet. Saying "enable
        // Features:DevEndpoints" would send the reviewer after the wrong knob.
        notFoundMessage:
            'Could not $action: no conversation is correlated with that '
            'request id (404). A request has no conversation until one is '
            'provisioned for it — check the ID, or drive the order far enough '
            'for chat to exist.',
      );
    }
  }

  // ------------------------------------------------------------------------
  // Helpers.
  // ------------------------------------------------------------------------

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

  /// A single-role list for the token mint, or null when [role] is blank.
  static List<String>? _roles(String? role) =>
      (role == null || role.trim().isEmpty) ? null : <String>[role.trim()];
}

/// A user shaped by the gateway dev endpoints.
///
/// The list view (`GET /dev/data/users` → `DevUserView`) carries
/// `userId/username/email/status`; the seed response
/// (`POST /dev/seed/user` → `DevSeedUserResponse`) additionally carries
/// `role/phone/displayName`. [fromJson] tolerates both shapes, so fields the
/// list view omits ([role], [phone], [displayName]) are `null` there.
class DevUser {
  const DevUser({
    required this.id,
    required this.username,
    required this.status,
    this.role,
    this.email,
    this.phone,
    this.displayName,
  });

  /// Parses a `DevUserView` or `DevSeedUserResponse` JSON object.
  factory DevUser.fromJson(Map<String, dynamic> json) {
    return DevUser(
      id: (json['userId'] as String?) ?? (json['id'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'unknown',
      role: json['role'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      displayName: json['displayName'] as String?,
    );
  }

  /// Canonical user-management id (`userId`).
  final String id;

  /// Derived login handle.
  final String username;

  /// Lifecycle status (`created` / `active` / …).
  final String status;

  /// `client` | `jeeber` | `admin`; null on the list view.
  final String? role;

  /// Non-deliverable derived email; may be null.
  final String? email;

  /// E.164 phone echoed on seed; null on the list view.
  final String? phone;

  /// Human label echoed on seed; null on the list view.
  final String? displayName;
}

/// A typed, human-readable failure from a dev-gateway call.
///
/// Callers show [message] directly. [statusCode] is the HTTP status when the
/// gateway responded (**404** = dev endpoints disabled on a `/dev/*` route, or
/// the resource is absent on a product route; **401/403** = missing or invalid
/// mint key; **410** = the route is retired) and null on a transport error.
class DevGatewayException implements Exception {
  const DevGatewayException(this.message, {this.statusCode, this.action});

  /// Builds a message from a [DioException], mapping the common dev-flag /
  /// mint-gate statuses to actionable text.
  ///
  /// [notFoundMessage] overrides the 404 branch. The default 404 text assumes
  /// the caller hit a `/dev/*` route, where 404 means the dev-endpoints flag is
  /// off — but a 404 from a *product* route (e.g. the correlation-key
  /// conversation read) means the resource does not exist, and blaming the flag
  /// there points the reviewer at a knob that is not the problem.
  ///
  /// **410 is called out by name.** `jeeb-gateway` #350 retired the legacy
  /// `Channels/` message-write surface with 410 Gone, and the generic
  /// "the gateway returned 410" reads like a transient fault. It is not: it is
  /// permanent, and it means the caller is still on a route that no longer
  /// exists.
  factory DevGatewayException.fromDio(
    DioException e, {
    required String action,
    String? notFoundMessage,
  }) {
    final status = e.response?.statusCode;
    final String message;
    switch (status) {
      case 404:
        message = notFoundMessage ??
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

  /// Human-readable, caller-displayable description.
  final String message;

  /// HTTP status when the gateway responded; null on a transport error.
  final int? statusCode;

  /// The attempted operation (for logging/telemetry).
  final String? action;

  @override
  String toString() => 'DevGatewayException($message)';
}
