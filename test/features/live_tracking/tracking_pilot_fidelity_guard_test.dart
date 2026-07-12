// JEBV4-218 (E23) / Q-061 pilot fidelity guard.
//
// The pilot customer tracking surface polls at a 5-second cadence and sources
// position from the FOREGROUND jeeber GPS feed ONLY. Background GPS and the
// geolocation-service are DEFERRED post-pilot (Q-061) — so the customer
// `lib/features/live_tracking/` tree must NEVER wire the device `geolocator`
// plugin, the jeeber-side `background_gps` feature, or the geolocation-service.
//
// This is a source-grep guard (no platform view needed) that fails the build
// the moment any of those dependencies leaks into the tracking surface.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JEBV4-218 — tracking surface stays pilot-fidelity (Q-061)', () {
    final trackingDir = Directory('lib/features/live_tracking');

    List<File> trackingSources() => trackingDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    test('the live_tracking source tree exists and is non-empty', () {
      expect(trackingDir.existsSync(), isTrue);
      expect(trackingSources(), isNotEmpty);
    });

    // Banned dependency tokens: no background GPS, no geolocator device-GPS
    // plugin, no geolocation-service. (The 5s poll + foreground jeeber GPS feed
    // is the ONLY position source for the pilot.)
    const banned = <String, String>{
      'package:geolocator': 'device geolocator plugin',
      'features/background_gps': 'background_gps feature',
      'BackgroundGps': 'background GPS cubit/state',
      'geolocation-service': 'geolocation-service dependency',
      'GeolocationService': 'geolocation-service client',
    };

    // Strip `//`-style line + doc comments so the guard scans CODE, not prose:
    // a comment may legitimately name a deferred dependency (e.g. explaining
    // WHY it is absent) without that dependency actually being wired.
    String stripComments(String source) => source
        .split('\n')
        .map((line) {
          final idx = line.indexOf('//');
          return idx == -1 ? line : line.substring(0, idx);
        })
        .join('\n');

    test('no background-GPS / geolocator / geolocation-service is wired', () {
      final offenders = <String>[];
      for (final file in trackingSources()) {
        final text = stripComments(file.readAsStringSync());
        banned.forEach((token, label) {
          if (text.contains(token)) {
            offenders.add('${file.path}: references $label ("$token")');
          }
        });
      }
      expect(
        offenders,
        isEmpty,
        reason: 'Q-061 pilot fidelity violated — the customer tracking surface '
            'must not depend on background GPS or the geolocation-service:\n'
            '${offenders.join('\n')}',
      );
    });
  });
}
