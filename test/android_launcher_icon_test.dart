// The launcher icon shipped as a FLAT NAVY SQUARE: there was no adaptive icon
// at all, so every API 26+ launcher masked the plain mipmap and the home screen
// showed a blank blue tile with no logo on it. These pin the fix.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const resRoot = 'android/app/src/main/res';

  String read(String relative) {
    final file = File('$resRoot/$relative');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'missing launcher icon resource: $relative',
    );
    return file.readAsStringSync();
  }

  test('the adaptive icon exists and is built from the brand layers', () {
    final icon = read('mipmap-anydpi-v26/ic_launcher.xml');
    expect(
      icon,
      contains('<adaptive-icon'),
      reason: 'without this file API 26+ falls back to the flat mipmap square',
    );
    expect(icon, contains('<background android:drawable="@color/jeeb_navy"'));
    expect(
      icon,
      contains('<foreground android:drawable="@drawable/ic_launcher_foreground"'),
      reason: 'the foreground is what actually draws the Jeeb wordmark',
    );
    expect(icon, contains('<monochrome'));
  });

  test('the foreground draws the wordmark inside the icon safe zone', () {
    final foreground = read('drawable/ic_launcher_foreground.xml');
    expect(foreground, contains('<vector'));
    expect(foreground, contains('@color/jeeb_white'));
    expect(foreground, contains('@color/jeeb_orange'));
    expect(
      foreground,
      contains('M148.629 59.8411'),
      reason: 'the launcher wordmark must keep the orange b shoulder bridge',
    );

    final scale = double.parse(
      RegExp(r'android:scaleX="([^"]+)"').firstMatch(foreground)!.group(1)!,
    );
    final translateX = double.parse(
      RegExp(r'android:translateX="([^"]+)"').firstMatch(foreground)!.group(1)!,
    );
    final renderedWidth = 182 * scale;
    final renderedHeight = 73.2418 * scale;
    final renderedDiagonal = math.sqrt(
      renderedWidth * renderedWidth + renderedHeight * renderedHeight,
    );
    expect(
      renderedWidth,
      lessThanOrEqualTo(66.1),
      reason: 'a wider wordmark gets clipped by round launcher masks',
    );
    expect(renderedDiagonal, lessThanOrEqualTo(72));
    expect(translateX, closeTo((108 - renderedWidth) / 2, 0.1));
  });

  test('the themed-icon layer is a single-colour silhouette', () {
    final monochrome = read('drawable/ic_launcher_monochrome.xml');
    expect(monochrome, contains('<vector'));
    expect(
      monochrome,
      isNot(contains('@color/jeeb_orange')),
      reason: 'Android 13 re-tints this layer, so two brand colours would '
          'collapse into one flat blob',
    );
    expect(monochrome, contains('M148.629 59.8411'));
  });

  test('every legacy mipmap is the logo, not a flat fill', () {
    const densities = <String, int>{
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    };

    densities.forEach((density, expectedSize) {
      final file = File('$resRoot/mipmap-$density/ic_launcher.png');
      expect(file.existsSync(), isTrue, reason: 'missing mipmap-$density icon');
      final bytes = file.readAsBytesSync();

      // PNG IHDR: width and height are big-endian uint32 at offsets 16 and 20.
      final header = ByteData.sublistView(Uint8List.fromList(bytes));
      expect(header.getUint32(16), expectedSize, reason: '$density width');
      expect(header.getUint32(20), expectedSize, reason: '$density height');

      // The flat navy square this replaced compressed to 593 bytes at xxxhdpi;
      // any real artwork is far larger, so a floor catches a regression to it.
      expect(
        bytes.length,
        greaterThan(1500),
        reason: 'mipmap-$density looks like a flat fill, not the Jeeb logo',
      );
    });
  });
}
