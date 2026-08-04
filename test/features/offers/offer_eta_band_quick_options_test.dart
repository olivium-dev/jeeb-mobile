// redesign-2026-08 screen 17: the composer draws THREE ETA pills inline, so the
// band has to name which three. `quickOptions` narrows the *default reach*, not
// the band — the picker sheet still offers every legal bid (D14).

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/offers/domain/offer_eta_band.dart';

void main() {
  group('OfferEtaBand.quickOptions', () {
    test('a 60-minute ceiling yields the board\'s [20, 40, 60]', () {
      final band = OfferEtaBand.fromRange(minMinutes: 5, maxMinutes: 60);

      expect(band.quickOptions, [20, 40, 60]);
    });

    test('the 5..120 fallback band yields [40, 80, 120]', () {
      final band = OfferEtaBand.defaultBand();

      expect(band.quickOptions, [40, 80, 120]);
    });

    test('a band of three or fewer options is returned verbatim', () {
      final band = OfferEtaBand.fromRange(minMinutes: 10, maxMinutes: 20);

      expect(band.options, [10, 15, 20]);
      expect(band.quickOptions, band.options);
    });

    test('a single-option band survives (degrade, do not crash)', () {
      final band = OfferEtaBand.fromRange(minMinutes: 30, maxMinutes: 30);

      expect(band.quickOptions, [30]);
    });

    test('every quick option is a real, selectable option and the ceiling is '
        'always last', () {
      for (final ceiling in [45, 60, 90, 120, 200]) {
        final band = OfferEtaBand.fromRange(minMinutes: 5, maxMinutes: ceiling);
        final quick = band.quickOptions;

        expect(quick.last, band.options.last, reason: 'ceiling last ($ceiling)');
        for (final minutes in quick) {
          expect(band.contains(minutes), isTrue,
              reason: '$minutes is offered but not in the band ($ceiling)');
        }
        expect(quick.length, lessThanOrEqualTo(3));
        expect(
          List<int>.from(quick)..sort(),
          quick,
          reason: 'quick options must stay ascending ($ceiling)',
        );
      }
    });
  });
}
