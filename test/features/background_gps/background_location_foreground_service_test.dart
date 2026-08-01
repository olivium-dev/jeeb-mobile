// P1, 2026-08-01 — the OS half of "the courier stopped reporting position".
//
// Keeping `BackgroundGpsCubit` alive across screens fixes the Dart half. It is
// not enough on its own: a plain `Geolocator.getPositionStream` is owned by the
// activity, so the moment the app leaves the foreground Android's
// background-location throttling (API 26+) cuts delivery from one fix per 10 m
// to a couple per HOUR. The cubit stays in `phase:"tracking"` throughout — the
// pipeline looks perfectly healthy on the `bg_gps_phase` breadcrumb while the
// customer's map quietly stops moving. That invisibility is why this half has
// to be asserted rather than assumed.
//
// geolocator's supported remedy is `AndroidSettings.foregroundNotificationConfig`:
// supplying it runs the plugin's own `GeolocatorLocationService`
// (declared `android:foregroundServiceType="location"` in
// geolocator_android-5.0.3's manifest) in the foreground, which exempts the
// stream from throttling.
//
// These are real assertions against the real settings object the production
// gateway hands to geolocator — no mock, no stub. `defaultSettings` is pure
// Dart, so it is exercised directly rather than through a platform channel.

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
      // the type itself is load-bearing — this is the assertion that fails if
      // anyone "simplifies" the gateway back to a single const settings object.
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
      // their location is being shared for as long as it is being shared.
      expect(config!.setOngoing, isTrue);
      expect(config.notificationTitle, isNotEmpty);
      expect(config.notificationText, isNotEmpty);

      // Without a wake lock the device sleeps and the OS dumps the whole
      // backlog on the next wake — the customer's marker jumps in bursts
      // instead of gliding.
      expect(config.enableWakeLock, isTrue);
    });

    test('the 10 m distance filter is preserved on both platforms', () {
      // A stationary courier legitimately uploads nothing. Keep this explicit
      // so an empty upload log is never misread as a dead pipeline.
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
      // `always` authorization; there is no service object to configure, and
      // handing geolocator_apple an AndroidSettings would be noise.
      final settings =
          GeolocatorGeocaptureGateway.defaultSettings(TargetPlatform.iOS);
      expect(settings, isNot(isA<geo.AndroidSettings>()));
    });

    test('the production constructor adopts the platform default', () {
      // Proves the wiring, not just the helper: the gateway the DI container
      // builds is the one carrying the foreground config.
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
