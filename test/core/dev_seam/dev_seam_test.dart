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
      await DevSeam.resolve(sources: const [
        // Highest priority: only sets the locale.
        _FakeSource(DevSeamConfig(forcedLocale: 'ar')),
        // Lower priority: sets a route + chat selector.
        _FakeSource(DevSeamConfig(route: '/settings', chatSelector: 'dm')),
      ]);

      expect(DevSeam.current.forcedLocale, 'ar', reason: 'top source wins');
      expect(DevSeam.current.route, '/settings', reason: 'gap-filled by lower');
      expect(DevSeam.current.chatSelector, 'dm');
    });

    test('a higher source overrides a field set by a lower source', () async {
      await DevSeam.resolve(sources: const [
        _FakeSource(DevSeamConfig(forcedLocale: 'ar')),
        _FakeSource(DevSeamConfig(forcedLocale: 'en')),
      ]);

      expect(DevSeam.current.forcedLocale, 'ar');
    });

    test('holdSplash is OR-merged across sources', () async {
      await DevSeam.resolve(sources: const [
        _FakeSource(DevSeamConfig()),
        _FakeSource(DevSeamConfig(holdSplash: true)),
      ]);

      expect(DevSeam.current.holdSplash, isTrue);
    });

    test('all-empty sources leave the inert empty config', () async {
      await DevSeam.resolve(sources: const [
        _FakeSource(DevSeamConfig.empty),
        _FakeSource(DevSeamConfig.empty),
      ]);

      expect(DevSeam.current, DevSeamConfig.empty);
      expect(DevSeam.current.isEmpty, isTrue);
    });

    test('resolve short-circuits to empty in release builds', () async {
      // Only assert the release branch when actually running release-mode.
      if (kDebugMode) return;
      await DevSeam.resolve(sources: const [
        _FakeSource(DevSeamConfig(route: '/should-be-ignored')),
      ]);
      expect(DevSeam.current, DevSeamConfig.empty);
    });
  });

  group('DevSeam journey seam (W1, 63_W1_TEST_PLAN §4)', () {
    test('journeySeed merges field-wise (primary wins)', () async {
      await DevSeam.resolve(sources: const [
        _FakeSource(DevSeamConfig(journeySeed: JourneySeed.activeDelivery)),
        _FakeSource(DevSeamConfig(journeySeed: JourneySeed.offersReceived)),
      ]);
      expect(DevSeam.current.journeySeed, JourneySeed.activeDelivery);
    });

    test('a journey with a route pin folds it into route when none is set',
        () async {
      await DevSeam.resolve(sources: const [
        _FakeSource(DevSeamConfig(
          sessionSeed: SessionSeed.customerLoggedIn,
          journeySeed: JourneySeed.deliveryMarkedDone,
        )),
      ]);
      expect(DevSeam.current.route,
          '/orders/del-client-001-delivered/receipt');
      expect(DevSeam.current.journeySeed, JourneySeed.deliveryMarkedDone);
    });

    test('active_delivery pins the tracking route', () async {
      await DevSeam.resolve(sources: const [
        _FakeSource(DevSeamConfig(journeySeed: JourneySeed.activeDelivery)),
      ]);
      expect(DevSeam.current.route,
          '/orders/del-client-001-active/tracking');
    });

    test('jeeber_rating_pending pins the jeeber-mode mutual-rate route',
        () async {
      await DevSeam.resolve(sources: const [
        _FakeSource(DevSeamConfig(journeySeed: JourneySeed.jeeberRatingPending)),
      ]);
      expect(DevSeam.current.route,
          '/orders/del-jeeber-002-delivered/mutual-rate?mode=jeeber');
    });

    test('an explicit route wins over a journey route pin', () async {
      await DevSeam.resolve(sources: const [
        _FakeSource(DevSeamConfig(
          route: '/custom',
          journeySeed: JourneySeed.deliveryMarkedDone,
        )),
      ]);
      expect(DevSeam.current.route, '/custom');
    });

    test('a journey with no route pin leaves route empty (lands on shell)',
        () async {
      await DevSeam.resolve(sources: const [
        _FakeSource(DevSeamConfig(
          sessionSeed: SessionSeed.customerLoggedIn,
          journeySeed: JourneySeed.offersReceived,
        )),
      ]);
      expect(DevSeam.current.route, isEmpty);
      expect(DevSeam.current.journeySeed, JourneySeed.offersReceived);
    });

    test('has_saved_addresses leaves route empty', () async {
      await DevSeam.resolve(sources: const [
        _FakeSource(DevSeamConfig(journeySeed: JourneySeed.hasSavedAddresses)),
      ]);
      expect(DevSeam.current.route, isEmpty);
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
