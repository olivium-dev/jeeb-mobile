import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _source(String path) => File(path).readAsStringSync();

void main() {
  // Guards the P1 where Apple Sign-In silently never worked because this key
  // was absent from both entitlements files for their entire git history.
  // CODE_SIGN_ENTITLEMENTS wiring in project.pbxproj was not the problem.
  group('Apple Sign-In entitlement', () {
    test('development entitlements declare the Default provider', () {
      final entitlements = _source('ios/Runner/Runner.entitlements');

      expect(
        entitlements,
        contains(
          '<key>com.apple.developer.applesignin</key>\n'
          '\t<array>\n'
          '\t\t<string>Default</string>\n'
          '\t</array>',
        ),
      );
    });

    test('release entitlements declare the Default provider', () {
      final entitlements = _source('ios/Runner/Runner.Release.entitlements');

      expect(
        entitlements,
        contains(
          '<key>com.apple.developer.applesignin</key>\n'
          '\t<array>\n'
          '\t\t<string>Default</string>\n'
          '\t</array>',
        ),
      );
    });
  });
}
