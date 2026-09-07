import 'dart:async';

import 'package:dio/dio.dart';

import '../session/auth_loss_signals.dart';

class SingleFlightGet {
  SingleFlightGet(this._dio, {Stream<AuthLossReason>? authLoss}) {
    _authLossSub =
        (authLoss ?? AuthLossSignals.instance.stream).listen((_) => clear());
  }

  final Dio _dio;

  StreamSubscription<AuthLossReason>? _authLossSub;

  /// NET-24: a response fetched for the previous session must never be handed
  /// to the next one, so the identity epoch is part of the key.
  int _epoch = 0;

  final Map<String, Future<Response<dynamic>>> _inFlight =
      <String, Future<Response<dynamic>>>{};

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    final key = _key(path, queryParameters);
    final existing = _inFlight[key];
    if (existing != null) return existing;

    final future = _dio.get<dynamic>(path, queryParameters: queryParameters);
    _inFlight[key] = future;
    future.whenComplete(() {
      if (identical(_inFlight[key], future)) _inFlight.remove(key);
    }).ignore();
    return future;
  }

  /// Drops every coalescing slot; in-flight futures still resolve for their
  /// own callers but can no longer be joined by a later, different identity.
  void clear() {
    _epoch++;
    _inFlight.clear();
  }

  Future<void> dispose() async {
    await _authLossSub?.cancel();
    _authLossSub = null;
    _inFlight.clear();
  }

  String _key(String path, Map<String, dynamic>? query) {
    final buffer = StringBuffer('$_epoch|')
      ..write(path)
      ..write('?');
    if (query != null && query.isNotEmpty) {
      final entries = query.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      for (final entry in entries) {
        buffer
          ..write(entry.key)
          ..write('=')
          ..write(entry.value)
          ..write('&');
      }
    }
    return buffer.toString();
  }
}
