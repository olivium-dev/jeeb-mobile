import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/config/dev_base_url.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('release builds ignore every persisted development URL', () {
    expect(
      DevBaseUrl.resolve(
        overrideAllowed: false,
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
        overrideAllowed: false,
      );
      expect(prefs.containsKey(DevBaseUrl.prefsKey), isFalse);
    },
  );

  test('full Dev Tool builds retain the explicit override behavior', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await DevBaseUrl.writeForBuild(
      prefs,
      ' https://gateway.dev.invalid ',
      overrideAllowed: true,
    );
    expect(
      DevBaseUrl.resolve(
        overrideAllowed: true,
        persistedValue: prefs.getString(DevBaseUrl.prefsKey),
      ),
      'https://gateway.dev.invalid',
    );
  });
}
