import 'dart:async';

import 'package:flutter/foundation.dart';

import '../diagnostics/diag.dart';

const Duration kNetworkReachabilityMinInterval = Duration(seconds: 2);

class NetworkReachabilitySignals {
  NetworkReachabilitySignals({
    this.minInterval = kNetworkReachabilityMinInterval,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final Duration minInterval;

  final DateTime Function() _now;

  final StreamController<void> _controller =
      StreamController<void>.broadcast(sync: true);

  StreamSubscription<bool>? _sourceSub;

  bool? _online;

  DateTime? _lastEmit;

  int emitCount = 0;

  int suppressedCount = 0;

  Stream<void> get stream => _controller.stream;

  bool? get debugOnline => _online;

  void bindSource(Stream<bool> source, {Future<bool>? seed}) {
    _sourceSub?.cancel();
    _sourceSub = source.listen(
      _observe,
      onError: (Object error) {
        Diag.event('network_reachability_source_error', <String, Object?>{
          'error': '$error',
        });
      },
      cancelOnError: false,
    );
    if (seed != null) unawaited(_applySeed(seed));
  }

  Future<void> _applySeed(Future<bool> seed) async {
    try {
      final online = await seed;
      _online ??= online;
    } catch (error) {
      Diag.event('network_reachability_seed_failed', <String, Object?>{
        'error': '$error',
      });
    }
  }

  void _observe(bool online) {
    final previous = _online;
    _online = online;
    if (previous != false || !online) return;

    final now = _now();
    final last = _lastEmit;
    if (last != null && now.difference(last) < minInterval) {
      suppressedCount++;
      Diag.event('network_reachable_suppressed', <String, Object?>{
        'reason': 'throttled',
        'count': suppressedCount,
      });
      return;
    }
    _emit(now);
  }

  void _emit(DateTime at) {
    if (_controller.isClosed) return;
    _lastEmit = at;
    emitCount++;
    Diag.event('network_reachable', <String, Object?>{'count': emitCount});
    _controller.add(null);
  }

  @visibleForTesting
  void debugObserve({required bool online}) => _observe(online);

  Future<void> dispose() async {
    await _sourceSub?.cancel();
    _sourceSub = null;
    await _controller.close();
  }


  static NetworkReachabilitySignals? _instance;

  static NetworkReachabilitySignals get instance =>
      _instance ??= NetworkReachabilitySignals();

  @visibleForTesting
  static set instance(NetworkReachabilitySignals value) => _instance = value;

  @visibleForTesting
  static Future<void> debugReset() async {
    final existing = _instance;
    _instance = null;
    if (existing != null) await existing.dispose();
  }
}
