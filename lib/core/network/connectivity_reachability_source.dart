import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityReachabilitySource {
  const ConnectivityReachabilitySource();

  static bool isOnline(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);

  Stream<bool> onlineStates() =>
      Connectivity().onConnectivityChanged.map(isOnline);

  Future<bool> currentlyOnline() async =>
      isOnline(await Connectivity().checkConnectivity());
}
