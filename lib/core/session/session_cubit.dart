import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../diagnostics/diag.dart';
import '../network/auth_token_store.dart';
import '../network/jwt_expiry.dart';
import 'auth_loss_signals.dart';
import 'session_gate.dart';
import 'session_state.dart';

class SessionCubit extends Cubit<SessionState> implements SessionGate {
  SessionCubit({required AuthTokenStore tokenStore, DateTime Function()? clock})
    : _tokenStore = tokenStore,
      _clock = clock ?? DateTime.now,
      super(const SessionState.unknown()) {
    _authLossSubscription = AuthLossSignals.instance.stream.listen((_) {
      _authEpoch++;
      emit(const SessionState(SessionStatus.unauthenticated));
    });
  }

  final AuthTokenStore _tokenStore;
  final DateTime Function() _clock;
  late final StreamSubscription<void> _authLossSubscription;
  int _authEpoch = 0;

  @override
  bool get isUnauthenticated => state.isUnauthenticated;

  Future<void> refresh() async {
    final epoch = _authEpoch;
    try {
      final token = await _tokenStore.accessToken;
      if (epoch != _authEpoch) return;
      final status = _classify(token);
      emit(SessionState(status));

      Diag.event('session_auth', <String, Object?>{'status': status.name});
    } catch (_) {
      if (epoch != _authEpoch) return;
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
    // NET-03: `jwtExpiry` returns null for opaque tokens too. Expiry unknown
    // is not expiry proven — only the reactive 401 lane declares death.
    final exp = jwtExpiry(token);
    if (exp == null) {
      return SessionStatus.authenticated;
    }
    final isExpired = !exp.isAfter(_clock().toUtc());
    return isExpired
        ? SessionStatus.unauthenticated
        : SessionStatus.authenticated;
  }

  @override
  Future<void> close() async {
    await _authLossSubscription.cancel();
    return super.close();
  }
}
