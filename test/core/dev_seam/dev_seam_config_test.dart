import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/dev_seam/dev_seam_config.dart';

void main() {
  group('DevSeamConfig.fromMap', () {
    test('maps intent-extra keys onto fields', () {
      final config = DevSeamConfig.fromMap({
        'jeeb.route': '/settings',
        'jeeb.state': 'broadcasting',
        'jeeb.locale': 'ar',
        'jeeb.hold_splash': 'true',
      });

      expect(config.route, '/settings');
      expect(config.chatSelector, 'broadcasting');
      expect(config.forcedLocale, 'ar');
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

    test('accepts 1/yes as truthy hold_splash, everything else false', () {
      expect(DevSeamConfig.fromMap({'jeeb.hold_splash': '1'}).holdSplash, isTrue);
      expect(
          DevSeamConfig.fromMap({'jeeb.hold_splash': 'YES'}).holdSplash, isTrue);
      expect(
          DevSeamConfig.fromMap({'jeeb.hold_splash': 'no'}).holdSplash, isFalse);
      expect(DevSeamConfig.fromMap({'jeeb.hold_splash': ''}).holdSplash, isFalse);
    });

    test('empty map yields the inert empty config', () {
      final config = DevSeamConfig.fromMap({});
      expect(config, DevSeamConfig.empty);
      expect(config.isEmpty, isTrue);
    });

    test('maps jeeb.seam.journey onto journeySeed (W1)', () {
      final config = DevSeamConfig.fromMap({
        'jeeb.seam.session': 'customer_logged_in',
        'jeeb.seam.journey': 'delivery_marked_done',
      });
      expect(config.sessionSeed, SessionSeed.customerLoggedIn);
      expect(config.journeySeed, JourneySeed.deliveryMarkedDone);
      expect(config.hasJourneySeed, isTrue);
      expect(config.isEmpty, isFalse);
    });

    test('unknown jeeb.seam.journey value → none (no crash)', () {
      final config = DevSeamConfig.fromMap({'jeeb.seam.journey': 'bogus'});
      expect(config.journeySeed, JourneySeed.none);
      expect(config.hasJourneySeed, isFalse);
    });
  });

  group('JourneySeed', () {
    test('every value round-trips through fromWire', () {
      for (final seed in JourneySeed.values) {
        expect(JourneySeed.fromWire(seed.wireValue), seed);
      }
    });

    test('route pins are set for deep-landing journeys, empty otherwise', () {
      expect(JourneySeed.activeDelivery.routePin,
          '/orders/del-client-001-active/tracking');
      expect(JourneySeed.deliveryMarkedDone.routePin,
          '/orders/del-client-001-delivered/receipt');
      expect(JourneySeed.offersReceived.routePin, isEmpty);
      expect(JourneySeed.hasSavedAddresses.routePin, isEmpty);
      expect(JourneySeed.none.routePin, isEmpty);
    });

    test('W3/W4 journey pins match the seam contract (62 §W3-W4)', () {
      // Deep-landing W4 shared journeys.
      expect(JourneySeed.hasNotifications.routePin, '/notifications');
      expect(JourneySeed.disputeOpen.routePin,
          '/disputes/dispute-client-001-open');
      // Shell-landing journeys (flow navigates from the shell).
      expect(JourneySeed.jeeberHasReviews.routePin, isEmpty);
      expect(JourneySeed.walletWithLedger.routePin, isEmpty);
    });

    test('W3/W4 wire values map via fromMap (no crash)', () {
      expect(
          DevSeamConfig.fromMap({'jeeb.seam.journey': 'has_notifications'})
              .journeySeed,
          JourneySeed.hasNotifications);
      expect(
          DevSeamConfig.fromMap({'jeeb.seam.journey': 'dispute_open'})
              .journeySeed,
          JourneySeed.disputeOpen);
      expect(
          DevSeamConfig.fromMap({'jeeb.seam.journey': 'jeeber_has_reviews'})
              .journeySeed,
          JourneySeed.jeeberHasReviews);
      expect(
          DevSeamConfig.fromMap({'jeeb.seam.journey': 'wallet_with_ledger'})
              .journeySeed,
          JourneySeed.walletWithLedger);
    });
  });

  group('DevSeamConfig.fromJsonString', () {
    test('parses a well-formed device-file payload', () {
      final config = DevSeamConfig.fromJsonString(
        '{"jeeb.route":"/","jeeb.locale":"ar","jeeb.hold_splash":true}',
      );

      expect(config.route, '/');
      expect(config.forcedLocale, 'ar');
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
      );
      expect(config.hasRoute, isTrue);
      expect(config.hasChatSelector, isTrue);
      expect(config.hasForcedLocale, isTrue);
    });

    test('value equality and hashCode are field-based', () {
      const a = DevSeamConfig(route: '/', forcedLocale: 'ar');
      const b = DevSeamConfig(route: '/', forcedLocale: 'ar');
      const c = DevSeamConfig(route: '/settings', forcedLocale: 'ar');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });
}
