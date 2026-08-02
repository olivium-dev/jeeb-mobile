import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../diagnostics/diag.dart';
import '../network/auth_token_store.dart';
import 'session_gate.dart';
import 'session_state.dart';

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

  Future<void> refresh() async {
    try {
      final token = await _tokenStore.accessToken;
      final status = _classify(token);
      emit(SessionState(status));

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

      return SessionStatus.authenticated;
    }
    final isExpired = !exp.isAfter(_clock().toUtc());
    return isExpired
        ? SessionStatus.unauthenticated
        : SessionStatus.authenticated;
  }

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
