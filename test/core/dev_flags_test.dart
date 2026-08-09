import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/dev_flags.dart';

void main() {
  group('Dev Tool compile gate', () {
    test('defaults off unless explicitly requested', () {
      const requested = bool.fromEnvironment(
        'JEEB_DEVTOOL_ENABLED',
        defaultValue: false,
      );

      expect(kDevToolRequested, requested);
      expect(kDevToolEnabled, kDebugMode && requested);
    });

    test('hard-locks the compiled gate to debug mode', () {
      final source = File('lib/core/dev_flags.dart').readAsStringSync();

      expect(
        source,
        contains(
          'const bool kDevToolEnabled = kDebugMode && kDevToolRequested;',
        ),
        reason: 'a release supplied with the define must remain locked',
      );
    });

    test('the shell guard follows the strict gate, not debug affordances', () {
      if (kDevToolEnabled) {
        expect(() => assertDevToolOnly('test'), returnsNormally);
      } else {
        expect(() => assertDevToolOnly('test'), throwsStateError);
      }
    });
  });

  group('Dev Tool startup selection', () {
    test('selects the tool only when enabled on the exact route', () {
      expect(
        shouldLaunchDevTool(enabled: true, initialRoute: '/devtool'),
        isTrue,
      );
    });

    test('rejects the route when the compile gate is off', () {
      expect(
        shouldLaunchDevTool(enabled: false, initialRoute: '/devtool'),
        isFalse,
      );
    });

    test('rejects product, malformed, and lookalike routes', () {
      for (final route in <String>[
        '/',
        '',
        '/devtool/',
        '/devtool?section=catalog',
        '/DevTool',
      ]) {
        expect(
          shouldLaunchDevTool(enabled: true, initialRoute: route),
          isFalse,
          reason: 'route=$route',
        );
      }
    });
  });
}
