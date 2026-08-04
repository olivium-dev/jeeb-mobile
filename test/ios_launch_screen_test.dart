// The iOS cold-start window. No widget test can reach it: the storyboard is
// painted by UIKit BEFORE Flutter's first frame, so a white background here is
// a full-screen white flash on every launch (M6 L-iOS).
//
// Android's counterpart lives in `android_splash_resources_test.dart`.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/jeeb_midnight_palette.dart';

const String _storyboardPath = 'ios/Runner/Base.lproj/LaunchScreen.storyboard';

/// The `<color key="backgroundColor" …>` of the launch view controller's view,
/// as an 8-bit RGB triple. Storyboard channels are 0..1 doubles.
({int r, int g, int b, double a}) _backgroundColor(String xml) {
  final match = RegExp(
    r'<color key="backgroundColor"([^/]*?)/>',
  ).firstMatch(xml);
  expect(match, isNotNull,
      reason: 'launch view declares no backgroundColor at all');
  final String attrs = match!.group(1)!;

  double channel(String name) {
    final m = RegExp('$name="([0-9.]+)"').firstMatch(attrs);
    expect(m, isNotNull, reason: 'backgroundColor has no $name channel');
    return double.parse(m!.group(1)!);
  }

  return (
    r: (channel('red') * 255).round(),
    g: (channel('green') * 255).round(),
    b: (channel('blue') * 255).round(),
    a: channel('alpha'),
  );
}

void main() {
  late String storyboard;

  setUpAll(() {
    final file = File(_storyboardPath);
    expect(file.existsSync(), isTrue,
        reason: 'missing native launch storyboard: $_storyboardPath');
    storyboard = file.readAsStringSync();
  });

  test('the cold-start window is MIDNIGHT page navy, not white', () {
    final bg = _backgroundColor(storyboard);

    expect(bg.r, (JeebMidnight.page.r * 255).round());
    expect(bg.g, (JeebMidnight.page.g * 255).round());
    expect(bg.b, (JeebMidnight.page.b * 255).round());
    expect(bg.a, 1.0, reason: 'a translucent window falls through to white');

    // Discrimination: this is the exact value that shipped, and it must fail.
    expect(
      <int>[bg.r, bg.g, bg.b],
      isNot(<int>[255, 255, 255]),
      reason: 'solid white here is the pre-Flutter launch flash',
    );
  });

  test('the storyboard still points at UILaunchStoryboardName', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('<key>UILaunchStoryboardName</key>'),
        reason: 'without this key iOS falls back to a blank white window and '
            'the storyboard fix above is dead code');
    expect(plist, contains('<string>LaunchScreen</string>'));
  });
}
