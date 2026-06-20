import 'package:connectivity_plus/connectivity_plus.dart';

import '../domain/connectivity_source.dart';

/// `connectivity_plus`-backed [ConnectivitySource] (global-offline-banner).
///
/// connectivity_plus 6.x emits `List<ConnectivityResult>` (a device can have
/// several active transports). We map any non-empty list that isn't purely
/// `none` to "online". Note: connectivity reflects radio/transport presence,
/// not reachability — that's the right signal for the offline banner (airplane
/// mode flips it), and per-screen fetch-error states handle dead-internet.
class ConnectivityPlusSource implements ConnectivitySource {
  ConnectivityPlusSource({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return _isOnline(results);
  }

  @override
  Stream<bool> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged.map(_isOnline);

  static bool _isOnline(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }
}
