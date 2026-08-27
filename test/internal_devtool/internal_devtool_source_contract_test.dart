import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // NOTE: scope is `lib/main_android_internal.dart`'s own bytes plus the files
  // under `lib/internal_devtool/`. It does NOT walk the transitive graph, so
  // it cannot see that the internal-release BUILD graph reaches
  // `lib/devtool/devtool_shell.dart` through `lib/app/app.dart` (behind the
  // `kShakeToDevToolEnabled` compile-time const). That crossing is pinned by
  // `test/release/devtool_import_closure_test.dart`, and the binary is
  // guarded by `tool/inspect_android_internal_release_payload.sh`.
  test(
    'the internal tool source tree names no legacy developer-tool capability',
    () {
      final entrypoint = File(
        'lib/main_android_internal.dart',
      ).readAsStringSync();
      final sources = Directory('lib/internal_devtool')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.readAsStringSync())
          .join('\n');

      expect(
        entrypoint,
        contains("'internal_devtool/internal_devtool_app.dart'"),
      );
      expect(entrypoint, isNot(contains("'devtool/")));
      expect(sources, isNot(contains("'../devtool/")));
      for (final prohibited in _prohibitedCapabilities) {
        expect(sources.toLowerCase(), isNot(contains(prohibited)));
      }
    },
  );

  test('internal tool contains no raw Material replacement primitives', () {
    final sources = Directory('lib/internal_devtool')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');
    for (final pattern in _rawMaterialPatterns) {
      expect(sources, isNot(contains(pattern)), reason: pattern);
    }
  });
}

const _prohibitedCapabilities = <String>[
  'full_roster',
  'scenario_users',
  'location_simulation',
  'serverurlpage',
  'catalog_screen',
  'devgatewayclient',
  'superloginservice',
  'otp_service',
  'kyc_gateway',
  'delivery_status_gateway',
];

const _rawMaterialPatterns = <String>[
  'ElevatedButton(',
  'FilledButton(',
  'OutlinedButton(',
  'TextField(',
  'TextFormField(',
  'CircularProgressIndicator(',
  'AlertDialog(',
  'showDialog<',
  'ScaffoldMessenger.of',
  'Colors.',
  'Color(0x',
];
