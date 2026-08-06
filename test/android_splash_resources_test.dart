import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

void main() {
  const resRoot = 'android/app/src/main/res';

  String read(String relative) {
    final file = File('$resRoot/$relative');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'missing native splash resource: $relative',
    );
    return file.readAsStringSync();
  }

  test('brand colors are defined for the native splash', () {
    final colors = read('values/colors.xml');
    expect(colors, contains('name="jeeb_navy"'));
    expect(
      colors.toUpperCase(),
      contains('#FF0B1351'),
      reason: 'jeeb_navy must equal the brand navy used by the Flutter splash',
    );
  });

  test('branded splash wordmark + icon vector drawables exist', () {
    final logo = read('drawable/jeeb_splash_logo.xml');
    expect(logo, contains('<vector'));
    expect(
      logo,
      contains('@color/jeeb_white'),
      reason: 'wordmark must paint white glyphs that read on navy',
    );
    expect(logo, contains('@color/jeeb_orange'));
    expect(
      logo,
      contains('M148.629 59.8411'),
      reason: 'native wordmark must retain the orange b shoulder bridge',
    );

    final icon = read('drawable/jeeb_splash_icon.xml');
    expect(icon, contains('<vector'));
    expect(icon, contains('@color/jeeb_white'));
    expect(icon, contains('@color/jeeb_orange'));
    expect(icon, contains('M148.629 59.8411'));

    final scale = double.parse(
      RegExp(r'android:scaleX="([^"]+)"').firstMatch(icon)!.group(1)!,
    );
    final translateX = double.parse(
      RegExp(r'android:translateX="([^"]+)"').firstMatch(icon)!.group(1)!,
    );
    final renderedWidth = 182 * scale;
    final renderedHeight = 73.2418 * scale;
    final renderedDiagonal = math.sqrt(
      renderedWidth * renderedWidth + renderedHeight * renderedHeight,
    );
    expect(
      renderedWidth,
      lessThanOrEqualTo(66.1),
      reason: 'the wide wordmark must fit inside the Android 12 icon safe zone',
    );
    expect(
      renderedDiagonal,
      lessThanOrEqualTo(72),
      reason: 'the entire wordmark rectangle must fit inside the safe circle',
    );
    expect(translateX, closeTo((108 - renderedWidth) / 2, 0.1));
  });

  test(
    'pre-12 launch_background is navy with the centred wordmark, not white',
    () {
      for (final variant in const [
        'drawable/launch_background.xml',
        'drawable-v21/launch_background.xml',
      ]) {
        final launch = read(variant);
        expect(
          launch,
          contains('@color/jeeb_navy'),
          reason: '$variant must use the brand navy, not white',
        );
        final drawableRefs = RegExp(
          r'android:drawable="([^"]+)"',
        ).allMatches(launch).map((m) => m.group(1)).toList();
        expect(
          drawableRefs,
          isNot(contains('@android:color/white')),
          reason: '$variant must not restore the white launch window',
        );
        expect(
          launch,
          contains('@drawable/jeeb_splash_logo'),
          reason: '$variant must draw the centred wordmark',
        );
      }
    },
  );

  test(
    'Android 12+ SplashScreen uses navy background + the Jeeb icon, not ic_launcher',
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
          contains(
            'android:windowSplashScreenAnimatedIcon">@drawable/jeeb_splash_icon',
          ),
          reason:
              '$variant: splash icon must be the Jeeb wordmark, not the navy '
              'ic_launcher square the platform otherwise defaults to',
        );
      }
    },
  );
}
