import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/config/dev_base_url.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test(
    'selectEnvironment persists both the environment id and gateway URL',
    () async {
      final prefs = await SharedPreferences.getInstance();

      await DevBaseUrl.selectEnvironment(prefs, DevBackendEnvironment.staging);

      expect(DevBaseUrl.readEnvironment(prefs), DevBackendEnvironment.staging);
      expect(DevBaseUrl.read(prefs), kStagingGatewayBaseUrl);
    },
  );

  test('known URL-only preference migrates to its named environment', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      DevBaseUrl.prefsKey: '$kStagingGatewayBaseUrl/',
    });
    final prefs = await SharedPreferences.getInstance();

    expect(DevBaseUrl.readEnvironment(prefs), DevBackendEnvironment.staging);
  });

  test('named environment id is authoritative over a stale raw URL', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      DevBaseUrl.environmentPrefsKey: DevBackendEnvironment.staging.id,
      DevBaseUrl.prefsKey: kDevelopmentGatewayBaseUrl,
    });
    final prefs = await SharedPreferences.getInstance();

    expect(DevBaseUrl.read(prefs), kStagingGatewayBaseUrl);
    expect(DevBaseUrl.readEnvironment(prefs), DevBackendEnvironment.staging);
  });

  test('custom gateway accepts origins only', () {
    expect(
      DevBaseUrl.canonicalOrigin(' https://gateway.example.test/ '),
      'https://gateway.example.test',
    );
    expect(DevBaseUrl.canonicalOrigin('ftp://gateway.example.test'), isNull);
    expect(DevBaseUrl.canonicalOrigin('https://user@gateway.test'), isNull);
    expect(DevBaseUrl.canonicalOrigin('https://gateway.test/v1'), isNull);
    expect(DevBaseUrl.canonicalOrigin('https://gateway.test?q=1'), isNull);
    expect(DevBaseUrl.canonicalOrigin('https://gateway.test/#x'), isNull);
  });

  test('launch clears credentials when selected environment changed', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      DevBaseUrl.appliedBaseUrlPrefsKey: kDevelopmentGatewayBaseUrl,
      DevBaseUrl.environmentPrefsKey: DevBackendEnvironment.staging.id,
      DevBaseUrl.prefsKey: kStagingGatewayBaseUrl,
    });
    final prefs = await SharedPreferences.getInstance();
    var clears = 0;

    await DevBaseUrl.activateForLaunch(
      prefs,
      defaultBaseUrl: kDevelopmentGatewayBaseUrl,
      clearCredentials: () async => clears++,
    );

    expect(clears, 1);
    expect(
      prefs.getString(DevBaseUrl.appliedBaseUrlPrefsKey),
      kStagingGatewayBaseUrl,
    );
  });

  test(
    'launch does not clear credentials again for the applied environment',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        DevBaseUrl.appliedBaseUrlPrefsKey: kStagingGatewayBaseUrl,
        DevBaseUrl.environmentPrefsKey: DevBackendEnvironment.staging.id,
      });
      final prefs = await SharedPreferences.getInstance();
      var clears = 0;

      await DevBaseUrl.activateForLaunch(
        prefs,
        defaultBaseUrl: kDevelopmentGatewayBaseUrl,
        clearCredentials: () async => clears++,
      );

      expect(clears, 0);
    },
  );

  test(
    'launch leaves applied marker unchanged when credential clear fails',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        DevBaseUrl.appliedBaseUrlPrefsKey: kDevelopmentGatewayBaseUrl,
        DevBaseUrl.environmentPrefsKey: DevBackendEnvironment.staging.id,
      });
      final prefs = await SharedPreferences.getInstance();

      await expectLater(
        DevBaseUrl.activateForLaunch(
          prefs,
          defaultBaseUrl: kDevelopmentGatewayBaseUrl,
          clearCredentials: () => Future<void>.error(StateError('keychain')),
        ),
        throwsStateError,
      );
      expect(
        prefs.getString(DevBaseUrl.appliedBaseUrlPrefsKey),
        kDevelopmentGatewayBaseUrl,
      );
    },
  );

  test('custom URL clears a previously selected named environment', () async {
    final prefs = await SharedPreferences.getInstance();
    await DevBaseUrl.selectEnvironment(
      prefs,
      DevBackendEnvironment.development,
    );

    await DevBaseUrl.write(prefs, 'https://custom.example.test');

    expect(DevBaseUrl.readEnvironment(prefs), isNull);
    expect(DevBaseUrl.read(prefs), 'https://custom.example.test');
  });
}
