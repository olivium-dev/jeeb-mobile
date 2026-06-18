import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/dev_seam/dev_seam_config.dart';

void main() {
  group('DevSeamConfig.fromMap', () {
    test('maps intent-extra keys onto fields', () {
      final config = DevSeamConfig.fromMap({
        'jeeb.route': '/settings',
        'jeeb.state': 'broadcasting',
        'jeeb.locale': 'ar',
        'jeeb.mock_base_url': ' http://192.168.1.42:3055 ',
        'jeeb.hold_splash': 'true',
      });

      expect(config.route, '/settings');
      expect(config.chatSelector, 'broadcasting');
      expect(config.forcedLocale, 'ar');
      expect(config.mockBaseUrl, 'http://192.168.1.42:3055');
      expect(config.holdSplash, isTrue);
      expect(config.isEmpty, isFalse);
    });

    test('trims whitespace and ignores unknown keys', () {
      final config = DevSeamConfig.fromMap({
        'jeeb.route': '  /chat  ',
        'jeeb.unknown': 'ignored',
      });

      expect(config.route, '/chat');
      expect(config.chatSelector, isEmpty);
    });

    test('maps jeeb.home_tab onto homeTab and flags hasHomeTab', () {
      final config = DevSeamConfig.fromMap({
        'jeeb.route': '/',
        'jeeb.home_tab': '  replies ',
      });

      expect(config.homeTab, 'replies');
      expect(config.hasHomeTab, isTrue);
      expect(config.isEmpty, isFalse);
    });

    test('maps jeeb.feed onto feed and flags hasFeed', () {
      final config = DevSeamConfig.fromMap({
        'jeeb.route': '/',
        'jeeb.feed': '  pending ',
      });

      expect(config.feed, 'pending');
      expect(config.hasFeed, isTrue);
      expect(config.isEmpty, isFalse);
    });

    test(
      'maps jeeb.mock_base_url onto mockBaseUrl and flags hasMockBaseUrl',
      () {
        final config = DevSeamConfig.fromMap({
          'jeeb.mock_base_url': ' http://10.0.2.2:3055 ',
        });

        expect(config.mockBaseUrl, 'http://10.0.2.2:3055');
        expect(config.hasMockBaseUrl, isTrue);
        expect(config.isEmpty, isFalse);
      },
    );

    test('accepts 1/yes as truthy hold_splash, everything else false', () {
      expect(
        DevSeamConfig.fromMap({'jeeb.hold_splash': '1'}).holdSplash,
        isTrue,
      );
      expect(
        DevSeamConfig.fromMap({'jeeb.hold_splash': 'YES'}).holdSplash,
        isTrue,
      );
      expect(
        DevSeamConfig.fromMap({'jeeb.hold_splash': 'no'}).holdSplash,
        isFalse,
      );
      expect(
        DevSeamConfig.fromMap({'jeeb.hold_splash': ''}).holdSplash,
        isFalse,
      );
    });

    test('empty map yields the inert empty config', () {
      final config = DevSeamConfig.fromMap({});
      expect(config, DevSeamConfig.empty);
      expect(config.isEmpty, isTrue);
    });
  });

  group('DevSeamConfig.fromJsonString', () {
    test('parses a well-formed device-file payload', () {
      final config = DevSeamConfig.fromJsonString(
        '{"jeeb.route":"/","jeeb.locale":"ar",'
        '"jeeb.mock_base_url":"http://192.168.1.42:3055",'
        '"jeeb.hold_splash":true}',
      );

      expect(config.route, '/');
      expect(config.forcedLocale, 'ar');
      expect(config.mockBaseUrl, 'http://192.168.1.42:3055');
      expect(config.holdSplash, isTrue);
    });

    test('coerces non-string JSON values via toString', () {
      final config = DevSeamConfig.fromJsonString('{"jeeb.hold_splash":1}');
      expect(config.holdSplash, isTrue);
    });

    test('returns empty on malformed JSON (never throws)', () {
      expect(DevSeamConfig.fromJsonString('not json'), DevSeamConfig.empty);
      expect(DevSeamConfig.fromJsonString('[1,2,3]'), DevSeamConfig.empty);
      expect(DevSeamConfig.fromJsonString(''), DevSeamConfig.empty);
    });
  });

  group('DevSeamConfig predicates and equality', () {
    test('has* getters reflect populated fields', () {
      const config = DevSeamConfig(
        route: '/',
        chatSelector: 'dm',
        forcedLocale: 'en',
        mockBaseUrl: 'http://10.0.2.2:3055',
      );
      expect(config.hasRoute, isTrue);
      expect(config.hasChatSelector, isTrue);
      expect(config.hasForcedLocale, isTrue);
      expect(config.hasMockBaseUrl, isTrue);
    });

    test('value equality and hashCode are field-based', () {
      const a = DevSeamConfig(
        route: '/',
        forcedLocale: 'ar',
        mockBaseUrl: 'http://10.0.2.2:3055',
      );
      const b = DevSeamConfig(
        route: '/',
        forcedLocale: 'ar',
        mockBaseUrl: 'http://10.0.2.2:3055',
      );
      const c = DevSeamConfig(route: '/', forcedLocale: 'ar');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });
}
