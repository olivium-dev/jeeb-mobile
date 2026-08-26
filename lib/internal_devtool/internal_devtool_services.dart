import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/connectivity_reachability_source.dart';
import '../core/session/firebase_identity_teardown.dart';
import '../features/biometric_auth/data/local_auth_biometric_gateway.dart';

abstract interface class InternalDeviceUnlocker {
  Future<bool> unlock({required String reason});
}

final class LocalAuthInternalDeviceUnlocker implements InternalDeviceUnlocker {
  LocalAuthInternalDeviceUnlocker({LocalAuthBiometricGateway? gateway})
    : _gateway = gateway ?? LocalAuthBiometricGateway();

  final LocalAuthBiometricGateway _gateway;

  @override
  Future<bool> unlock({required String reason}) =>
      _gateway.authenticate(reason: reason);
}

final class InternalDevToolStatus {
  const InternalDevToolStatus({
    required this.versionName,
    required this.buildNumber,
    required this.networkAvailable,
  });

  final String versionName;
  final String buildNumber;
  final bool networkAvailable;

  String get buildLabel => '$versionName+$buildNumber';
}

abstract interface class InternalDevToolStatusReader {
  Future<InternalDevToolStatus> read();
}

final class PlatformInternalDevToolStatusReader
    implements InternalDevToolStatusReader {
  const PlatformInternalDevToolStatusReader({
    ConnectivityReachabilitySource connectivity =
        const ConnectivityReachabilitySource(),
  }) : _connectivity = connectivity;

  final ConnectivityReachabilitySource _connectivity;

  @override
  Future<InternalDevToolStatus> read() async {
    final package = await PackageInfo.fromPlatform();
    final networkAvailable = await _connectivity.currentlyOnline();
    return InternalDevToolStatus(
      versionName: package.version,
      buildNumber: package.buildNumber,
      networkAvailable: networkAvailable,
    );
  }
}

abstract interface class InternalLocalDataClearer {
  Future<void> clear();
}

abstract interface class InternalDevToolCloser {
  Future<void> close();
}

final class SystemNavigatorInternalDevToolCloser
    implements InternalDevToolCloser {
  const SystemNavigatorInternalDevToolCloser();

  @override
  Future<void> close() => SystemNavigator.pop();
}

final class PlatformInternalLocalDataClearer
    implements InternalLocalDataClearer {
  const PlatformInternalLocalDataClearer({
    FlutterSecureStorage secureStorage = const FlutterSecureStorage(),
    FirebaseIdentityTeardown firebaseSignOut = signOutFirebaseIdentity,
  }) : _secureStorage = secureStorage,
       _firebaseSignOut = firebaseSignOut;

  final FlutterSecureStorage _secureStorage;
  final FirebaseIdentityTeardown _firebaseSignOut;

  @override
  Future<void> clear() async {
    await _firebaseSignOut();
    await _secureStorage.deleteAll();
    await (await SharedPreferences.getInstance()).clear();
  }
}
