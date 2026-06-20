/// Port over a device-connectivity signal (global-offline-banner / SC-129).
///
/// Drives `OfflineCubit.setOffline()/setOnline()` so the global `OfflineBanner`
/// can actually appear from airplane mode. Kept behind a port so the cubit and
/// its tests stay platform-free; DI binds the `connectivity_plus`-backed impl.
abstract class ConnectivitySource {
  const ConnectivitySource();

  /// `true` when the device currently has at least one active network
  /// transport; `false` for the "none" / airplane-mode state.
  Future<bool> isOnline();

  /// Emits `true`/`false` on every connectivity transition.
  Stream<bool> get onConnectivityChanged;
}
