import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'iOS Dev Tool launcher carries the flavor, gate, route, and safe inputs',
    () {
      final script = File('tool/run_ios_devtool.sh').readAsStringSync();

      expect(script, contains(r'${JEEB_IOS_LOCALE:-en_US.UTF-8}'));
      expect(script, contains('export LC_ALL='));
      expect(script, contains(r'${JEEB_IOS_DEVICE:-iPhone 15}'));
      expect(
        script,
        contains(r'${JEEB_IOS_BASE_URL:-http://192.168.2.39:10090}'),
      );
      expect(script, contains('--flavor dev'));
      expect(script, contains('--debug'));
      expect(script, contains('--dart-define=JEEB_DEVTOOL_ENABLED=true'));
      expect(
        script,
        contains(r'--dart-define=JEEB_MOCK_BASE_URL="${base_url}"'),
      );
      expect(script, contains('--route=/devtool'));
      expect(script, isNot(contains('--dart-define=USE_MOCK_GATEWAY=')));
      expect(script, isNot(contains('JEEB_SUPERADMIN_PASSCODE')));
    },
  );
}
