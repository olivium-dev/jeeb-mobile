import 'dart:async';

import 'package:flutter/foundation.dart';

import '../diagnostics/diag.dart';
import 'app_failure.dart';

const Duration kNetworkReachabilityMinInterval = Duration(seconds: 2);

/// Only these two kinds blame the connection, so only these are the ones a
/// reconnect can make stale (F6). A 500 stays on screen until it is answered.
bool failureBlamesConnectivity(AppFailure failure) =>
    failure.kind == AppFailureKind.network ||
    failure.kind == AppFailureKind.timeout;

class NetworkReachabilitySignals {
  NetworkReachabilitySignals({
    this.minInterval = kNetworkReachabilityMinInterval,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final Duration minInterval;

  final DateTime Function() _now;

  final StreamController<void> _controller =
      StreamController<void>.broadcast(sync: true);

  final StreamController<void> _offlineController =
      StreamController<void>.broadcast(sync: true);

  final StreamController<bool> _stateController =
      StreamController<bool>.broadcast(sync: true);

  StreamSubscription<bool>? _sourceSub;

  bool? _online;

  DateTime? _lastEmit;

  int emitCount = 0;

  int suppressedCount = 0;

  int offlineEmitCount = 0;

  /// Offline -> online edge.
  Stream<void> get stream => _controller.stream;

  /// OFF-18: the online -> offline edge. [stateStream] carries both directions.
  Stream<void> get offlineStream => _offlineController.stream;

  /// Unthrottled mirror of [isOnline] for persistent UI. Refresh triggers stay
  /// on the throttled [stream]; this channel never drops a state transition.
  Stream<bool> get stateStream => _stateController.stream;

  /// Unknown reads as online: never blame connectivity without evidence.
  bool get isOnline => _online ?? true;

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
      if (_online == null) _observe(online);
    } catch (error) {
      Diag.event('network_reachability_seed_failed', <String, Object?>{
        'error': '$error',
      });
    }
  }

  void _observe(bool online) {
    final previous = _online;
    final wasOnline = isOnline;
    _online = online;
    if (wasOnline != isOnline && !_stateController.isClosed) {
      _stateController.add(isOnline);
    }
    if (!online) {
      if (previous == false) return;
      _emitOffline();
      return;
    }
    if (previous != false) return;

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

  void _emitOffline() {
    if (_offlineController.isClosed) return;
    offlineEmitCount++;
    Diag.event('network_unreachable', <String, Object?>{
      'count': offlineEmitCount,
    });
    _offlineController.add(null);
  }

  @visibleForTesting
  void debugObserve({required bool online}) => _observe(online);

  Future<void> dispose() async {
    await _sourceSub?.cancel();
    _sourceSub = null;
    await _controller.close();
    await _offlineController.close();
    await _stateController.close();
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
