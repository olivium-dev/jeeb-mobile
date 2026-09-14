import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../core/config/app_config.dart';
import '../../core/dev_flags.dart';

typedef FirebaseCanaryIdentityLoader =
    Future<FirebaseCanaryIdentity?> Function();
typedef FirebaseCanaryPost =
    Future<FirebaseCanaryHttpResult> Function(
      Uri route,
      Map<String, Object?> payload,
    );
typedef FirebaseCanaryNow = DateTime Function();

abstract interface class FirebaseBackendAuthCanaryRunner {
  Future<FirebaseBackendAuthCanaryResult> run();

  void close();
}

class FirebaseCanaryIdentity {
  const FirebaseCanaryIdentity({
    required this.uid,
    required this.token,
    required this.projectId,
  });

  final String uid;
  final String token;
  final String projectId;
}

class FirebaseCanaryHttpResult {
  const FirebaseCanaryHttpResult({
    required this.status,
    this.verified,
    this.projectId,
    this.provider,
    this.subjectSha256,
  });

  final int status;
  final bool? verified;
  final String? projectId;
  final String? provider;
  final String? subjectSha256;
}

class FirebaseBackendAuthCanaryResult {
  const FirebaseBackendAuthCanaryResult({
    required this.passed,
    required this.reason,
    this.environment,
    this.projectId,
    this.route,
    this.provider,
    this.validTokenStatus,
    this.invalidSignatureStatus,
    this.userSha256Prefix,
    this.tokenSha256Prefix,
  });

  final bool passed;
  final String reason;
  final String? environment;
  final String? projectId;
  final String? route;
  final String? provider;
  final int? validTokenStatus;
  final int? invalidSignatureStatus;
  final String? userSha256Prefix;
  final String? tokenSha256Prefix;
}

class FirebaseBackendAuthCanary implements FirebaseBackendAuthCanaryRunner {
  FirebaseBackendAuthCanary({
    required FirebaseCanaryIdentityLoader loadIdentity,
    required FirebaseCanaryPost post,
    bool enabled = kDevToolEnabled,
    String appFlavor = AppConfig.appFlavor,
    FirebaseCanaryNow now = DateTime.now,
    void Function()? onClose,
  }) : _loadIdentity = loadIdentity,
       _post = post,
       _enabled = enabled,
       _appFlavor = appFlavor,
       _now = now,
       _onClose = onClose;

  factory FirebaseBackendAuthCanary.live({
    FirebaseAuth? firebaseAuth,
    FirebaseApp? firebaseApp,
  }) {
    final auth = firebaseAuth ?? FirebaseAuth.instance;
    final app = firebaseApp ?? Firebase.app();
    final client = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        headers: const <String, Object?>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    return FirebaseBackendAuthCanary(
      loadIdentity: () async {
        final user = auth.currentUser;
        if (user == null) return null;
        final token = await user.getIdToken(true);
        if (token == null || token.isEmpty) return null;
        return FirebaseCanaryIdentity(
          uid: user.uid,
          token: token,
          projectId: app.options.projectId,
        );
      },
      post: (route, payload) => _postAndDiscard(client, route, payload),
      onClose: () => client.close(force: true),
    );
  }

  final FirebaseCanaryIdentityLoader _loadIdentity;
  final FirebaseCanaryPost _post;
  final bool _enabled;
  final String _appFlavor;
  final FirebaseCanaryNow _now;
  final void Function()? _onClose;

  @override
  Future<FirebaseBackendAuthCanaryResult> run() async {
    if (!_enabled) {
      return const FirebaseBackendAuthCanaryResult(
        passed: false,
        reason: 'dev_tool_disabled',
      );
    }

    FirebaseCanaryIdentity? identity;
    try {
      identity = await _loadIdentity();
      if (identity == null) {
        return const FirebaseBackendAuthCanaryResult(
          passed: false,
          reason: 'firebase_user_not_signed_in',
        );
      }
      final target = _targetForBuild(
        appFlavor: _appFlavor,
        projectId: identity.projectId,
      );
      final claims = _inspectToken(identity, target, now: _now());
      final payload = <String, Object?>{
        'idToken': identity.token,
        'expectedProjectId': target.projectId,
        'expectedSubject': identity.uid,
      };
      final validResponse = await _post(target.route, payload);
      final invalidToken = _corruptSignature(identity.token);
      final invalidPayload = <String, Object?>{
        ...payload,
        'idToken': invalidToken,
      };
      final invalidResponse = await _post(target.route, invalidPayload);
      final subjectSha256 = _sha256(identity.uid);
      final validStatus = validResponse.status;
      final invalidStatus = invalidResponse.status;
      final passed =
          validStatus == 200 &&
          validResponse.verified == true &&
          validResponse.projectId == target.projectId &&
          validResponse.provider == claims.provider &&
          validResponse.subjectSha256 == subjectSha256 &&
          invalidStatus == 401;
      return FirebaseBackendAuthCanaryResult(
        passed: passed,
        reason: passed
            ? 'firebase_backend_token_verification_pass'
            : validStatus != 200
            ? 'valid_token_rejected'
            : validResponse.verified != true ||
                  validResponse.projectId != target.projectId ||
                  validResponse.provider != claims.provider ||
                  validResponse.subjectSha256 != subjectSha256
            ? 'valid_verifier_evidence_mismatch'
            : 'invalid_signature_accepted',
        environment: target.environment,
        projectId: target.projectId,
        route: target.route.toString(),
        provider: claims.provider,
        validTokenStatus: validStatus,
        invalidSignatureStatus: invalidStatus,
        userSha256Prefix: subjectSha256.substring(0, 16),
        tokenSha256Prefix: _shaPrefix(identity.token),
      );
    } on _CanaryRejected catch (error) {
      return FirebaseBackendAuthCanaryResult(
        passed: false,
        reason: error.reason,
        projectId: identity?.projectId,
      );
    } catch (_) {
      return FirebaseBackendAuthCanaryResult(
        passed: false,
        reason: 'canary_execution_failed',
        projectId: identity?.projectId,
      );
    }
  }

  @override
  void close() => _onClose?.call();
}

Future<FirebaseCanaryHttpResult> _postAndDiscard(
  Dio client,
  Uri route,
  Map<String, Object?> payload,
) async {
  final response = await client.post<ResponseBody>(
    route.toString(),
    data: payload,
    options: Options(
      responseType: ResponseType.stream,
      validateStatus: (_) => true,
    ),
  );
  final status = response.statusCode ?? 0;
  final stream = response.data?.stream;
  if (stream == null) return FirebaseCanaryHttpResult(status: status);
  if (status != 200) {
    await stream.drain<void>();
    return FirebaseCanaryHttpResult(status: status);
  }

  const maxResponseBytes = 4096;
  final bytes = <int>[];
  await for (final chunk in stream) {
    if (bytes.length + chunk.length > maxResponseBytes) {
      throw const _CanaryRejected('valid_response_too_large');
    }
    bytes.addAll(chunk);
  }
  try {
    final decoded = jsonDecode(utf8.decode(bytes));
    const expectedKeys = <String>{
      'verified',
      'projectId',
      'provider',
      'subjectSha256',
    };
    if (decoded is! Map ||
        decoded.keys.map((key) => key.toString()).toSet().length !=
            expectedKeys.length ||
        !decoded.keys
            .map((key) => key.toString())
            .toSet()
            .containsAll(expectedKeys)) {
      throw const _CanaryRejected('valid_response_shape_invalid');
    }
    return FirebaseCanaryHttpResult(
      status: status,
      verified: decoded['verified'] is bool
          ? decoded['verified'] as bool
          : null,
      projectId: decoded['projectId'] is String
          ? decoded['projectId'] as String
          : null,
      provider: decoded['provider'] is String
          ? decoded['provider'] as String
          : null,
      subjectSha256: decoded['subjectSha256'] is String
          ? decoded['subjectSha256'] as String
          : null,
    );
  } on _CanaryRejected {
    rethrow;
  } catch (_) {
    throw const _CanaryRejected('valid_response_shape_invalid');
  }
}

_CanaryTarget _targetForBuild({
  required String appFlavor,
  required String projectId,
}) {
  return switch ((appFlavor, projectId)) {
    ('dev', 'jeeb-development-msi') => _CanaryTarget(
      environment: 'development',
      projectId: projectId,
      route: Uri.https(
        'msi.olivium.space',
        '/gateway/v1/auth/diagnostics/firebase-token',
      ),
    ),
    ('staging', 'jeeb-5a293') => _CanaryTarget(
      environment: 'staging',
      projectId: projectId,
      route: Uri.https(
        'app.jeeb.fds-1.com',
        '/v1/auth/diagnostics/firebase-token',
      ),
    ),
    _ => throw const _CanaryRejected('build_firebase_target_mismatch'),
  };
}

_CanaryClaims _inspectToken(
  FirebaseCanaryIdentity identity,
  _CanaryTarget target, {
  required DateTime now,
}) {
  if (identity.token.length > 16384) {
    throw const _CanaryRejected('firebase_token_too_large');
  }
  final parts = identity.token.split('.');
  if (parts.length != 3 || parts.any((part) => part.isEmpty)) {
    throw const _CanaryRejected('firebase_token_shape_invalid');
  }
  final header = _decodePart(parts[0]);
  final claims = _decodePart(parts[1]);
  final keyId = header['kid'];
  if (header['alg'] != 'RS256' || keyId is! String || keyId.isEmpty) {
    throw const _CanaryRejected('firebase_token_header_invalid');
  }
  if (claims['aud'] != target.projectId) {
    throw const _CanaryRejected('firebase_audience_mismatch');
  }
  if (claims['iss'] != 'https://securetoken.google.com/${target.projectId}') {
    throw const _CanaryRejected('firebase_issuer_mismatch');
  }
  if (claims['sub'] != identity.uid ||
      identity.uid.isEmpty ||
      identity.uid.length > 128) {
    throw const _CanaryRejected('firebase_subject_mismatch');
  }
  final issuedAt = claims['iat'];
  final expiresAt = claims['exp'];
  final nowSeconds = now.toUtc().millisecondsSinceEpoch ~/ 1000;
  if (issuedAt is! int ||
      expiresAt is! int ||
      issuedAt > nowSeconds + 30 ||
      expiresAt <= nowSeconds - 30 ||
      expiresAt - issuedAt > 3700) {
    throw const _CanaryRejected('firebase_token_not_current');
  }
  final firebase = claims['firebase'];
  final provider = firebase is Map<String, Object?>
      ? firebase['sign_in_provider']
      : null;
  if (provider is! String ||
      provider.isEmpty ||
      provider.length > 128 ||
      !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(provider)) {
    throw const _CanaryRejected('firebase_provider_invalid');
  }
  return _CanaryClaims(provider);
}

Map<String, Object?> _decodePart(String part) {
  if (part.length > 32768 || !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(part)) {
    throw const _CanaryRejected('firebase_token_segment_invalid');
  }
  try {
    final decoded = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(part))),
    );
    if (decoded is! Map) {
      throw const _CanaryRejected('firebase_token_json_invalid');
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  } on _CanaryRejected {
    rethrow;
  } catch (_) {
    throw const _CanaryRejected('firebase_token_json_invalid');
  }
}

String _corruptSignature(String token) {
  final parts = token.split('.');
  if (parts.length != 3 || parts[2].isEmpty) {
    throw const _CanaryRejected('firebase_token_shape_invalid');
  }
  final first = parts[2][0] == 'A' ? 'B' : 'A';
  return '${parts[0]}.${parts[1]}.$first${parts[2].substring(1)}';
}

String _sha256(String value) => sha256.convert(utf8.encode(value)).toString();

String _shaPrefix(String value) => _sha256(value).substring(0, 16);

class _CanaryTarget {
  const _CanaryTarget({
    required this.environment,
    required this.projectId,
    required this.route,
  });

  final String environment;
  final String projectId;
  final Uri route;
}

class _CanaryClaims {
  const _CanaryClaims(this.provider);

  final String provider;
}

class _CanaryRejected implements Exception {
  const _CanaryRejected(this.reason);

  final String reason;
}
