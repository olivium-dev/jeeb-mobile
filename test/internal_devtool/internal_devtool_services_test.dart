import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/internal_devtool/internal_devtool_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'local clear tears down Firebase identity and both local stores',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'session': 'live',
      });
      final storage = _FakeSecureStorage();
      var firebaseSignOutCalls = 0;
      final clearer = PlatformInternalLocalDataClearer(
        secureStorage: storage,
        firebaseSignOut: () async => firebaseSignOutCalls++,
      );

      await clearer.clear();

      expect(firebaseSignOutCalls, 1);
      expect(storage.deleteAllCalls, 1);
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    },
  );
}

final class _FakeSecureStorage extends Fake implements FlutterSecureStorage {
  int deleteAllCalls = 0;

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    deleteAllCalls++;
  }
}
