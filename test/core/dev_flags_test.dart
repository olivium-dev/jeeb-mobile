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

      const staging = bool.fromEnvironment(
        'JEEB_STAGING_DEVTOOL',
        defaultValue: false,
      );

      expect(kDevToolRequested, requested);
      expect(kStagingDevToolRequested, staging);
      expect(kDevToolEnabled, (kDebugMode || staging) && requested);
    });

    test('hard-locks the compiled gate to debug OR the staging artifact', () {
      // Owner directive 2026-08-27: the staging build must carry the Dev Tool,
      // so the gate is no longer debug-only. What must NOT weaken is the rest:
      // the request define is still mandatory, and a plain release build
      // satisfies neither branch.
      final source = File('lib/core/dev_flags.dart').readAsStringSync();

      expect(
        source,
        contains(
          'const bool kDevToolEnabled =\n'
          '    (kDebugMode || kStagingDevToolRequested) && kDevToolRequested;',
        ),
        reason:
            'the gate shape is load-bearing: `kDevToolRequested` must stay '
            'a mandatory conjunct, so a stray staging define alone can never '
            'unlock the tool',
      );
    });

    test('the staging unlock cannot fire on a store build', () {
      // The Dart pair is supplied only by the protected internal builders.
      // iOS additionally needs native `JEEB_DEV`; Android independently needs
      // its internal flavor/resource/launcher policy. Ordinary store builds
      // satisfy neither platform's complete gate.
      final iosBuilder = File(
        'tool/build_signed_ios_internal_candidate.sh',
      ).readAsStringSync();
      final androidBuilder = File(
        '.github/workflows/trusted-android-internal-devtool-rc.yml',
      ).readAsStringSync();

      expect(iosBuilder, contains('--dart-define=JEEB_STAGING_DEVTOOL=true'));
      expect(
        androidBuilder,
        contains('--dart-define=JEEB_STAGING_DEVTOOL=true'),
      );
      expect(
        androidBuilder,
        contains('--dart-define=JEEB_DEVTOOL_ENABLED=true'),
      );
      expect(
        iosBuilder,
        contains('-configuration Release-staging'),
        reason:
            'the staging builder must archive the configuration that '
            'defines JEEB_DEV, never plain Release',
      );

      final scanner = File(
        'tool/inspect_unsigned_ios_release.sh',
      ).readAsStringSync();

      expect(
        scanner,
        contains(r'RELEASE_PROFILE="${JEEB_IOS_RELEASE_PROFILE:-production}"'),
        reason:
            'the release scanner must default to the STRICT profile, so an '
            'unset or misspelled variable inspects as a store build',
      );
      expect(
        scanner,
        contains(r'if [[ "${RELEASE_PROFILE}" == production ]]; then'),
        reason:
            'developer-surface markers must still hard-fail a store-bound '
            'artifact',
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
