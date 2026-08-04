import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const resRoot = 'android/app/src/main/res';

  String read(String relative) {
    final file = File('$resRoot/$relative');
    expect(file.existsSync(), isTrue, reason: 'missing native splash resource: $relative');
    return file.readAsStringSync();
  }

  test('brand colors are defined for the native splash', () {
    final colors = read('values/colors.xml');
    expect(colors, contains('name="jeeb_navy"'));
    expect(colors.toUpperCase(), contains('#FF0B1351'),
        reason: 'jeeb_navy must equal the brand navy used by the Flutter splash');
  });

  test('branded splash wordmark + icon vector drawables exist', () {
    final logo = read('drawable/jeeb_splash_logo.xml');
    expect(logo, contains('<vector'));
    expect(logo, contains('@color/jeeb_white'),
        reason: 'wordmark must paint white glyphs that read on navy');
    expect(logo, contains('@color/jeeb_orange'));

    final icon = read('drawable/jeeb_splash_icon.xml');
    expect(icon, contains('<vector'));
    expect(icon, contains('@color/jeeb_white'));
    expect(icon, contains('@color/jeeb_orange'));
  });

  test('pre-12 launch_background is navy with the centred wordmark, not white',
      () {
    final launch = read('drawable/launch_background.xml');
    expect(launch, contains('@color/jeeb_navy'),
        reason: 'cold-start window must be brand navy, not @android:color/white');
    // Inspect only the active <item> drawable refs, not the documentary comment
    final drawableRefs = RegExp(r'android:drawable="([^"]+)"')
        .allMatches(launch)
        .map((m) => m.group(1))
        .toList();
    expect(drawableRefs, isNot(contains('@android:color/white')),
        reason: 'the flat white window was the navy-square-on-white bug surface');
    expect(launch, contains('@drawable/jeeb_splash_logo'),
        reason: 'the wordmark must be drawn on the pre-12 splash window');
  });

  test('Android 12+ SplashScreen uses navy background + the Jeeb icon, not ic_launcher',
      () {
    for (final variant in const ['values-v31', 'values-night-v31']) {
      final styles = read('$variant/styles.xml');
      expect(
        styles,
        contains('android:windowSplashScreenBackground">@color/jeeb_navy'),
        reason: '$variant: splash background must be brand navy',
      );
      expect(
        styles,
        contains('android:windowSplashScreenAnimatedIcon">@drawable/jeeb_splash_icon'),
        reason: '$variant: splash icon must be the Jeeb wordmark, not the navy '
            'ic_launcher square the platform otherwise defaults to',
      );
    }
  });
}
