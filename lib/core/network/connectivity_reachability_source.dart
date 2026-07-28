import 'package:connectivity_plus/connectivity_plus.dart';

/// The ONLY file in `lib/` that imports `package:connectivity_plus`.
///
/// Everything else consumes [NetworkReachabilitySignals], which takes a plain
/// `Stream<bool>`. Keeping the plugin behind this adapter is the same
/// ports-and-adapters discipline the repo already applies to `MapPickerLauncher`
/// (geolocator / google_maps_flutter), `BiometricGateway` (local_auth) and
/// `VoiceRecorder` (record): the cubits, screens and their tests never import a
/// plugin, so the unit-test seam stays an in-memory fake and `dart analyze`
/// stays green with no platform channel registered.
///
/// ## Mapping
///
/// `onConnectivityChanged` emits `List<ConnectivityResult>` — a device can hold
/// several transports at once (WiFi + mobile during a handover), and the list is
/// never empty: `[ConnectivityResult.none]` is the offline representation and
/// `none` appears in no other case. So "the OS reports a usable network" is
/// exactly "at least one element that is not `none`".
///
/// The plugin already applies `Stream.distinct` internally, and
/// [NetworkReachabilitySignals] applies its own offline→online edge filter on
/// top, so a transport swap that never passes through `none`
/// (`[wifi] → [mobile]`) correctly produces NO reconnect signal: the network
/// never went away.
class ConnectivityReachabilitySource {
  const ConnectivityReachabilitySource();

  /// True when at least one reported transport is not [ConnectivityResult.none].
  static bool isOnline(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);

  /// The live OS reachability stream.
  Stream<bool> onlineStates() =>
      Connectivity().onConnectivityChanged.map(isOnline);

  /// One-shot read of the CURRENT reachability, used to seed the bus baseline
  /// so a cold start that is already offline still yields a real offline→online
  /// edge when the network returns.
  ///
  /// This is a platform-channel read of the radio state, NOT a network request
  /// and NOT a cadence: it is called exactly once, at app start.
  Future<bool> currentlyOnline() async =>
      isOnline(await Connectivity().checkConnectivity());
}
