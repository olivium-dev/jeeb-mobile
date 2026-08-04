// JEBV4-218 (E23) / Q-061 pilot fidelity guard.

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
    const banned = <String, String>{
      'package:geolocator': 'device geolocator plugin',
      'features/background_gps': 'background_gps feature',
      'BackgroundGps': 'background GPS cubit/state',
      'geolocation-service': 'geolocation-service dependency',
      'GeolocationService': 'geolocation-service client',
    };

    // Strip `//`-style line + doc comments so the guard scans CODE, not prose:
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
