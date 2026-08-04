import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offer_ranking.dart';

import '../../support/offers_fixtures.dart';

void main() {
  group('rankByBestValue', () {
    test('returns short lists untouched', () {
      expect(rankByBestValue(const []), isEmpty);
      final one = [buildOffer(id: 'solo')];
      expect(rankByBestValue(one).map((o) => o.id).toList(), ['solo']);
    });

    test('is price order when rating and ETA tie', () {
      final ranked = rankByBestValue([
        buildOffer(id: 'a', fee: 30),
        buildOffer(id: 'b', fee: 10),
        buildOffer(id: 'c', fee: 20),
      ]);

      expect(ranked.map((o) => o.id).toList(), ['b', 'c', 'a']);
    });

    test(
      'a slightly pricier bid wins when it is both better rated and faster',
      () {
        final ranked = rankByBestValue([
          buildOffer(
            id: 'cheap-slow-unloved',
            fee: 8,
            rating: 3.9,
            ratingCount: 40,
            etaMinutes: 60,
          ),
          buildOffer(
            id: 'balanced',
            fee: 10,
            rating: 4.9,
            ratingCount: 120,
            etaMinutes: 25,
          ),
        ]);

        expect(ranked.first.id, 'balanced');
      },
    );

    test('ties break newest-first, so the order cannot churn between pushes', () {
      final offers = [
        buildOffer(
          id: 'older',
          fee: 10,
          submittedAt: kBaseTime.subtract(const Duration(minutes: 2)),
        ),
        buildOffer(
          id: 'newer',
          fee: 10,
          submittedAt: kBaseTime.subtract(const Duration(seconds: 5)),
        ),
      ];

      expect(rankByBestValue(offers).map((o) => o.id).toList(), [
        'newer',
        'older',
      ]);
      // Idempotent: re-ranking an already-ranked list is a no-op.
      expect(
        rankByBestValue(rankByBestValue(offers)).map((o) => o.id).toList(),
        ['newer', 'older'],
      );
    });

    test(
      'an unrated Jeeber is scored NEUTRAL, never as a 0.0-star Jeeber',
      () {
        // Same fee and ETA. If `rating: 0.0 / count: 0` were taken at face
        // value the unrated bid would rank last; it must land mid-field, so
        // being new is not a penalty and not a promotion.
        final ranked = rankByBestValue([
          buildOffer(id: 'top', rating: 5.0, ratingCount: 200),
          buildOffer(id: 'new', rating: 0.0, ratingCount: 0),
          buildOffer(id: 'weak', rating: 2.0, ratingCount: 200),
        ]);

        expect(ranked.map((o) => o.id).toList(), ['top', 'new', 'weak']);
      },
    );
  });

  group('bestValueOfferId', () {
    test('is null for an empty or single-offer list (no "best of one")', () {
      expect(bestValueOfferId(const []), isNull);
      expect(bestValueOfferId([buildOffer(id: 'solo')]), isNull);
    });

    test('is the head of the ranked list', () {
      final offers = [
        buildOffer(id: 'a', fee: 30),
        buildOffer(id: 'b', fee: 10),
      ];

      expect(bestValueOfferId(offers), 'b');
      expect(bestValueOfferId(offers), rankByBestValue(offers).first.id);
    });
  });

  group('fastestOfferId', () {
    test('is null when the minimum ETA is shared', () {
      expect(
        fastestOfferId([
          buildOffer(id: 'a', etaMinutes: 20),
          buildOffer(id: 'b', etaMinutes: 20),
        ]),
        isNull,
      );
    });

    test('is null for a single-offer list', () {
      expect(fastestOfferId([buildOffer(id: 'solo', etaMinutes: 5)]), isNull);
    });

    test('is null when the fastest bid already holds the best-value badge', () {
      final offers = [
        buildOffer(id: 'wins-everything', fee: 5, etaMinutes: 10),
        buildOffer(id: 'other', fee: 40, etaMinutes: 90),
      ];

      expect(bestValueOfferId(offers), 'wins-everything');
      expect(fastestOfferId(offers), isNull, reason: 'one badge per card');
    });

    test('is the unique quickest bid when that is not the best value', () {
      final offers = [
        buildOffer(
          id: 'cheap',
          fee: 5,
          etaMinutes: 60,
          rating: 4.9,
          ratingCount: 100,
        ),
        buildOffer(
          id: 'quick',
          fee: 45,
          etaMinutes: 10,
          rating: 4.0,
          ratingCount: 100,
        ),
        buildOffer(
          id: 'middling',
          fee: 20,
          etaMinutes: 40,
          rating: 4.5,
          ratingCount: 100,
        ),
      ];

      expect(bestValueOfferId(offers), 'cheap');
      expect(fastestOfferId(offers), 'quick');
    });
  });
}
