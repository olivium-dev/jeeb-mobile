import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';

import 'package:jeeb_mobile/features/location/data/geocoding_reverse_geocoder.dart';

void main() {
  group('GeocodingReverseGeocoder', () {
    test('formats the first placemark as street, area, locality', () async {
      final geocoder = GeocodingReverseGeocoder(
        placemarkLookup: (_, _) async => const <Placemark>[
          Placemark(
            street: '  Rue Monot 42 ',
            subLocality: 'Achrafieh',
            locality: 'Beirut',
          ),
        ],
      );

      final result = await geocoder.reverseGeocode(
        latitude: 33.8869,
        longitude: 35.5131,
      );

      expect(result, 'Rue Monot 42, Achrafieh, Beirut');
    });

    test('returns null instead of propagating a lookup error', () async {
      final geocoder = GeocodingReverseGeocoder(
        placemarkLookup: (_, _) async => throw StateError('channel failed'),
      );

      final result = await geocoder.reverseGeocode(
        latitude: 33.8869,
        longitude: 35.5131,
      );

      expect(result, isNull);
    });

    test('returns null when the lookup exceeds its timeout', () {
      fakeAsync((async) {
        final neverCompletes = Completer<List<Placemark>>();
        final geocoder = GeocodingReverseGeocoder(
          placemarkLookup: (_, _) => neverCompletes.future,
          timeout: const Duration(seconds: 5),
        );
        var completed = false;
        String? result = 'not completed';

        geocoder.reverseGeocode(latitude: 33.8869, longitude: 35.5131).then((
          value,
        ) {
          completed = true;
          result = value;
        });
        async.flushMicrotasks();
        expect(completed, isFalse);

        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        expect(completed, isTrue);
        expect(result, isNull);
      });
    });

    test('returns null when every address field is empty', () async {
      final geocoder = GeocodingReverseGeocoder(
        placemarkLookup: (_, _) async => const <Placemark>[
          Placemark(street: ' ', subLocality: '', locality: null),
        ],
      );

      final result = await geocoder.reverseGeocode(
        latitude: 33.8869,
        longitude: 35.5131,
      );

      expect(result, isNull);
    });
  });
}
