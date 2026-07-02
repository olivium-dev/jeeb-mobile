import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../diagnostics/diag.dart';
import '../network/auth_token_store.dart';
import 'session_gate.dart';
import 'session_state.dart';

/// Owns the "is the user logged in?" decision for the router's first-run gate
/// (FR-P0-3).
///
/// Reads the access token from [AuthTokenStore] (the secure keystore) and
/// classifies it:
///   * absent            → [SessionStatus.unauthenticated] → router → `/register`
///   * present, parseable JWT, `exp` in the past → [SessionStatus.unauthenticated]
///   * present, parseable JWT, `exp` in the future → [SessionStatus.authenticated]
///   * present, NOT a parseable JWT (mock / super-login tokens like
///     `mock-jwt-access-super-user`) → [SessionStatus.authenticated]
///     (presence is sufficient — the mock/demo path has no real `exp`).
///
/// Implements [SessionGate] so the router redirect can read a single boolean,
/// and extends `Cubit<SessionState>` so it can drive `refreshListenable`:
/// every [refresh] (e.g. after a successful OTP verify, after super-login, or
/// after logout) re-evaluates the gate and re-runs route redirects.
class SessionCubit extends Cubit<SessionState> implements SessionGate {
  SessionCubit({
    required AuthTokenStore tokenStore,
    DateTime Function()? clock,
  })  : _tokenStore = tokenStore,
        _clock = clock ?? DateTime.now,
        super(const SessionState.unknown());

  final AuthTokenStore _tokenStore;
  final DateTime Function() _clock;

  @override
  bool get isUnauthenticated => state.isUnauthenticated;

  /// Re-reads the keystore and emits a concrete [SessionState]. Call once at
  /// startup (after bootstrap) and again whenever tokens change. Never throws —
  /// a keystore read failure degrades to [SessionStatus.unauthenticated] (fail
  /// CLOSED: an unreadable token means we cannot prove the user is logged in,
  /// so we force login rather than silently admit them to Home).
  Future<void> refresh() async {
    try {
      final token = await _tokenStore.accessToken;
      final status = _classify(token);
      emit(SessionState(status));
      // Domain event: session auth-state resolution. NO token in the payload —
      // only the classified status (the whole point of the redaction rule).
      Diag.event('session_auth', <String, Object?>{'status': status.name});
    } catch (_) {
      emit(const SessionState(SessionStatus.unauthenticated));
      Diag.event('session_auth', <String, Object?>{
        'status': SessionStatus.unauthenticated.name,
        'error': 'keystore_read_failed',
      });
    }
  }

  SessionStatus _classify(String? token) {
    if (token == null || token.trim().isEmpty) {
      return SessionStatus.unauthenticated;
    }
    final exp = _jwtExpiry(token);
    if (exp == null) {
      // Not a parseable JWT (mock / super-login token). Presence is enough.
      return SessionStatus.authenticated;
    }
    final isExpired = !exp.isAfter(_clock().toUtc());
    return isExpired
        ? SessionStatus.unauthenticated
        : SessionStatus.authenticated;
  }

  /// Decodes the `exp` (seconds since epoch) claim from a JWT, or null when the
  /// token is not a well-formed 3-segment JWT with a numeric `exp`. Best-effort
  /// and total: any malformed input yields null (treated as a non-JWT token by
  /// the caller), never an exception.
  static DateTime? _jwtExpiry(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final payloadRaw = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final decoded = jsonDecode(payloadRaw);
      if (decoded is! Map) return null;
      final exp = decoded['exp'];
      if (exp is! num) return null;
      return DateTime.fromMillisecondsSinceEpoch(
        (exp * 1000).toInt(),
        isUtc: true,
      );
    } catch (_) {
      return null;
    }
  }
}
