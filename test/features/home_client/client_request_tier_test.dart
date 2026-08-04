// The client-home tier lexicon is five tiers wide (redesign-2026-08 screen 04,
// §5 #7): ⚡ Flash · 🚀 Express · 🟦 Standard · 🤝 On-the-Way · 🌿 Eco. Before
// the redesign, `onTheWay` and `eco` fell through to `unknown` and rendered no
// badge at all, so two of the five product tiers were invisible on the card.
//
// These pin the parse table — including the three spellings the gateway has
// been seen using for On-the-Way — and the render-nothing fallback that keeps
// an unseen server tier from breaking a card.

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_tier_chip.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';

void main() {
  group('ClientRequestTier.parse', () {
    test('the three original tiers still parse', () {
      expect(ClientRequestTier.parse('flash'), ClientRequestTier.flash);
      expect(ClientRequestTier.parse('express'), ClientRequestTier.express);
      expect(ClientRequestTier.parse('standard'), ClientRequestTier.standard);
    });

    test('on-the-way parses from all three server spellings', () {
      expect(ClientRequestTier.parse('ontheway'), ClientRequestTier.onTheWay);
      expect(ClientRequestTier.parse('on-the-way'), ClientRequestTier.onTheWay);
      expect(ClientRequestTier.parse('on_the_way'), ClientRequestTier.onTheWay);
    });

    test('eco parses', () {
      expect(ClientRequestTier.parse('eco'), ClientRequestTier.eco);
    });

    test('null and an unseen tier degrade to unknown, never a throw', () {
      expect(ClientRequestTier.parse(null), ClientRequestTier.unknown);
      expect(ClientRequestTier.parse(''), ClientRequestTier.unknown);
      expect(
        ClientRequestTier.parse('hyperloop'),
        ClientRequestTier.unknown,
      );
    });
  });

  // The kit owns the ⚡🚀🟦🤝🌿 lexicon; this feature only maps onto it. If the
  // enum names ever drift apart the chip would silently lose its emoji, so the
  // mapping is pinned here rather than discovered in a screenshot.
  group('ClientRequestTier maps onto the kit JeebTier by enum name', () {
    test('every real tier resolves to its kit twin', () {
      expect(JeebTier.fromId(ClientRequestTier.flash.name), JeebTier.flash);
      expect(JeebTier.fromId(ClientRequestTier.express.name), JeebTier.express);
      expect(
        JeebTier.fromId(ClientRequestTier.standard.name),
        JeebTier.standard,
      );
      expect(
        JeebTier.fromId(ClientRequestTier.onTheWay.name),
        JeebTier.onTheWay,
      );
      expect(JeebTier.fromId(ClientRequestTier.eco.name), JeebTier.eco);
    });

    test('unknown maps to the kit unknown, which draws no emoji', () {
      expect(JeebTier.fromId(ClientRequestTier.unknown.name), JeebTier.unknown);
      expect(JeebTier.unknown.emoji, isEmpty);
    });
  });
}
