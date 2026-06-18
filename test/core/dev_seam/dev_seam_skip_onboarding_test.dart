// Unit coverage for the FR-P0-1 `DevSeamConfig.skipOnboarding` flag.
//
// The flag is the explicit opt-in that lets the DevSeam route pin bypass the
// first-run (onboarding + session) gate. SECURITY-CRITICAL: it must default to
// false and must round-trip through every source/merge path so a bare route pin
// can never silently flip it on.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/dev_seam/dev_seam.dart';
import 'package:jeeb_mobile/core/dev_seam/dev_seam_config.dart';
import 'package:jeeb_mobile/core/dev_seam/dev_seam_source.dart';

/// A scripted source that yields a fixed config — lets us drive the merge order
/// without a platform channel.
class _StaticSource implements DevSeamSource {
  const _StaticSource(this.config);
  final DevSeamConfig config;
  @override
  DevSeamConfig read() => config;
}

void main() {
  tearDown(DevSeam.debugReset);

  group('DevSeamConfig.skipOnboarding default', () {
    test('defaults to false on the empty config', () {
      expect(DevSeamConfig.empty.skipOnboarding, isFalse);
      expect(const DevSeamConfig().skipOnboarding, isFalse);
    });

    test('a route-only config does NOT enable skipOnboarding', () {
      // This is the core bypass-closure invariant: pinning a route must not by
      // itself grant the onboarding skip.
      const config = DevSeamConfig(route: '/');
      expect(config.skipOnboarding, isFalse);
    });
  });

  group('DevSeamConfig.fromMap parsing', () {
    test('parses jeeb.skip_onboarding truthy values', () {
      for (final truthy in ['true', '1', 'yes', 'TRUE', 'Yes']) {
        final config = DevSeamConfig.fromMap({'jeeb.skip_onboarding': truthy});
        expect(config.skipOnboarding, isTrue, reason: 'value "$truthy"');
      }
    });

    test('absent / falsey jeeb.skip_onboarding stays false', () {
      expect(
        DevSeamConfig.fromMap({'jeeb.route': '/'}).skipOnboarding,
        isFalse,
      );
      for (final falsey in ['false', '0', 'no', '']) {
        final config = DevSeamConfig.fromMap({'jeeb.skip_onboarding': falsey});
        expect(config.skipOnboarding, isFalse, reason: 'value "$falsey"');
      }
    });

    test('route + skip_onboarding parse together', () {
      final config = DevSeamConfig.fromMap({
        'jeeb.route': '/',
        'jeeb.skip_onboarding': 'true',
      });
      expect(config.route, '/');
      expect(config.skipOnboarding, isTrue);
    });
  });

  group('Android intent-extra whitelist', () {
    test('MainActivity accepts RC4 dev-seam keys from adb extras', () {
      final mainActivity = File(
        'android/app/src/main/kotlin/app/jeeb/mobile/MainActivity.kt',
      ).readAsStringSync();
      final seamKeys = RegExp(
        r'private val seamKeys = listOf\(([\s\S]*?)\)',
      ).firstMatch(mainActivity)?.group(1);

      expect(seamKeys, isNotNull);
      expect(seamKeys, contains('"jeeb.skip_onboarding"'));
      expect(seamKeys, contains('"jeeb.mock_base_url"'));
    });
  });

  group('DevSeamConfig.fromJsonString parsing', () {
    test('reads skipOnboarding from a device-file payload', () {
      final config = DevSeamConfig.fromJsonString(
        '{"jeeb.route":"/","jeeb.skip_onboarding":true}',
      );
      expect(config.route, '/');
      expect(config.skipOnboarding, isTrue);
    });

    test('malformed JSON degrades to empty (skip stays false)', () {
      final config = DevSeamConfig.fromJsonString('{not json');
      expect(config, DevSeamConfig.empty);
      expect(config.skipOnboarding, isFalse);
    });
  });

  group('DevSeamConfig value semantics', () {
    test('skipOnboarding participates in equality and hashCode', () {
      const a = DevSeamConfig(route: '/', skipOnboarding: true);
      const b = DevSeamConfig(route: '/', skipOnboarding: true);
      const c = DevSeamConfig(route: '/');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('skipOnboarding makes an otherwise-empty config non-empty', () {
      const config = DevSeamConfig(skipOnboarding: true);
      expect(config.isEmpty, isFalse);
    });

    test('toString surfaces skipOnboarding for debug logging', () {
      const config = DevSeamConfig(skipOnboarding: true);
      expect(config.toString(), contains('skipOnboarding: true'));
    });
  });

  group('DevSeam.resolve merge (debug-only)', () {
    test(
      'a higher-priority source OR-merges skipOnboarding from a fallback',
      () async {
        assert(kDebugMode, 'merge test must run in debug');
        // Intent sets only the route; device file supplies the skip flag.
        await DevSeam.resolve(
          sources: const [
            _StaticSource(DevSeamConfig(route: '/')),
            _StaticSource(DevSeamConfig(skipOnboarding: true)),
          ],
        );
        expect(DevSeam.current.route, '/');
        expect(DevSeam.current.skipOnboarding, isTrue);
      },
    );

    test('neither source setting the flag leaves it false', () async {
      await DevSeam.resolve(
        sources: const [
          _StaticSource(DevSeamConfig(route: '/')),
          _StaticSource(DevSeamConfig(forcedLocale: 'ar')),
        ],
      );
      expect(DevSeam.current.route, '/');
      expect(DevSeam.current.skipOnboarding, isFalse);
    });
  });
}
