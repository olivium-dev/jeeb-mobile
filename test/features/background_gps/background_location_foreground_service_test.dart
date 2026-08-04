// P1, 2026-08-01 — the OS half of "the courier stopped reporting position".

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' as geo;

import 'package:jeeb_mobile/features/background_gps/data/geolocator_geocapture_gateway.dart';

void main() {
  group('P1 jeeber GPS keeps streaming while the app is backgrounded', () {
    test('Android settings start a foreground service', () {
      final settings =
          GeolocatorGeocaptureGateway.defaultSettings(TargetPlatform.android);

      // A bare LocationSettings cannot carry a foreground service at all, so
      expect(settings, isA<geo.AndroidSettings>());

      final config =
          (settings as geo.AndroidSettings).foregroundNotificationConfig;
      expect(
        config,
        isNotNull,
        reason: 'Without this the stream is throttled the moment the jeeber '
            'leaves the app and live tracking dies silently.',
      );

      // Persistent + non-dismissible: the jeeber must be able to see that
      expect(config!.setOngoing, isTrue);
      expect(config.notificationTitle, isNotEmpty);
      expect(config.notificationText, isNotEmpty);

      // Without a wake lock the device sleeps and the OS dumps the whole
      expect(config.enableWakeLock, isTrue);
    });

    test('the 10 m distance filter is preserved on both platforms', () {
      // A stationary courier legitimately uploads nothing. Keep this explicit
      for (final platform in <TargetPlatform>[
        TargetPlatform.android,
        TargetPlatform.iOS,
      ]) {
        final settings = GeolocatorGeocaptureGateway.defaultSettings(platform);
        expect(settings.distanceFilter, 10, reason: 'platform: $platform');
        expect(settings.accuracy, geo.LocationAccuracy.high);
      }
    });

    test('non-Android platforms keep the plain settings', () {
      // iOS gets continuous background delivery from UIBackgroundModes +
      final settings =
          GeolocatorGeocaptureGateway.defaultSettings(TargetPlatform.iOS);
      expect(settings, isNot(isA<geo.AndroidSettings>()));
    });

    test('the production constructor adopts the platform default', () {
      // Proves the wiring, not just the helper: the gateway the DI container
      final gateway =
          GeolocatorGeocaptureGateway(platform: TargetPlatform.android);
      expect(gateway.locationSettings, isA<geo.AndroidSettings>());
      expect(
        (gateway.locationSettings as geo.AndroidSettings)
            .foregroundNotificationConfig,
        isNotNull,
      );
    });
  });
}
