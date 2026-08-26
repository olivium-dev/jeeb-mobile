import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/config/dev_base_url.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('release builds ignore every persisted development URL', () {
    expect(
      DevBaseUrl.resolve(
        debugBuild: false,
        persistedValue: 'https://example.invalid',
      ),
      isNull,
    );
  });

  test(
    'release writes remove a stale override instead of persisting it',
    () async {
      SharedPreferences.setMockInitialValues({
        DevBaseUrl.prefsKey: 'https://example.invalid',
      });
      final prefs = await SharedPreferences.getInstance();
      await DevBaseUrl.writeForBuild(
        prefs,
        'https://another.invalid',
        debugBuild: false,
      );
      expect(prefs.containsKey(DevBaseUrl.prefsKey), isFalse);
    },
  );

  test('debug builds retain the existing explicit override behavior', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await DevBaseUrl.writeForBuild(
      prefs,
      ' https://gateway.dev.invalid ',
      debugBuild: true,
    );
    expect(
      DevBaseUrl.resolve(
        debugBuild: true,
        persistedValue: prefs.getString(DevBaseUrl.prefsKey),
      ),
      'https://gateway.dev.invalid',
    );
  });
}
