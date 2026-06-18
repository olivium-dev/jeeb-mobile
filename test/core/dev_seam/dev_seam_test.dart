import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/dev_seam/dev_seam.dart';
import 'package:jeeb_mobile/core/dev_seam/dev_seam_config.dart';
import 'package:jeeb_mobile/core/dev_seam/dev_seam_source.dart';

/// In-memory source for deterministic resolution tests (no platform channel).
class _FakeSource implements DevSeamSource {
  const _FakeSource(this.config);
  final DevSeamConfig config;

  @override
  DevSeamConfig read() => config;
}

void main() {
  tearDown(DevSeam.debugReset);

  group('DevSeam.resolve (debug)', () {
    test('first source with a field wins; lower sources fill gaps', () async {
      await DevSeam.resolve(
        sources: const [
          // Highest priority: only sets the locale.
          _FakeSource(DevSeamConfig(forcedLocale: 'ar')),
          // Lower priority: sets a route + chat selector + mock endpoint.
          _FakeSource(
            DevSeamConfig(
              route: '/settings',
              chatSelector: 'dm',
              mockBaseUrl: 'http://10.0.2.2:3055',
            ),
          ),
        ],
      );

      expect(DevSeam.current.forcedLocale, 'ar', reason: 'top source wins');
      expect(DevSeam.current.route, '/settings', reason: 'gap-filled by lower');
      expect(DevSeam.current.chatSelector, 'dm');
      expect(DevSeam.current.mockBaseUrl, 'http://10.0.2.2:3055');
    });

    test('a higher source overrides a field set by a lower source', () async {
      await DevSeam.resolve(
        sources: const [
          _FakeSource(
            DevSeamConfig(
              forcedLocale: 'ar',
              mockBaseUrl: 'http://192.168.1.42:3055',
            ),
          ),
          _FakeSource(
            DevSeamConfig(
              forcedLocale: 'en',
              mockBaseUrl: 'http://10.0.2.2:3055',
            ),
          ),
        ],
      );

      expect(DevSeam.current.forcedLocale, 'ar');
      expect(DevSeam.current.mockBaseUrl, 'http://192.168.1.42:3055');
    });

    test('holdSplash is OR-merged across sources', () async {
      await DevSeam.resolve(
        sources: const [
          _FakeSource(DevSeamConfig()),
          _FakeSource(DevSeamConfig(holdSplash: true)),
        ],
      );

      expect(DevSeam.current.holdSplash, isTrue);
    });

    test('all-empty sources leave the inert empty config', () async {
      await DevSeam.resolve(
        sources: const [
          _FakeSource(DevSeamConfig.empty),
          _FakeSource(DevSeamConfig.empty),
        ],
      );

      expect(DevSeam.current, DevSeamConfig.empty);
      expect(DevSeam.current.isEmpty, isTrue);
    });

    test('resolve short-circuits to empty in release builds', () async {
      // Only assert the release branch when actually running release-mode.
      if (kDebugMode) return;
      await DevSeam.resolve(
        sources: const [
          _FakeSource(DevSeamConfig(route: '/should-be-ignored')),
        ],
      );
      expect(DevSeam.current, DevSeamConfig.empty);
    });
  });

  group('DevSeam test helpers', () {
    test('debugOverride sets current; debugReset clears it', () {
      DevSeam.debugOverride(const DevSeamConfig(route: '/chat'));
      expect(DevSeam.current.route, '/chat');
      DevSeam.debugReset();
      expect(DevSeam.current, DevSeamConfig.empty);
    });
  });
}
