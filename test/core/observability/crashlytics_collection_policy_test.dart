import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/observability/crashlytics_collection_policy.dart';

void main() {
  group('CrashlyticsCollectionPolicy', () {
    test(
      'explicit flavor wins, then native Flutter flavor, then production',
      () {
        expect(
          CrashlyticsCollectionPolicy.resolveFlavor(
            configuredFlavor: 'staging',
            nativeFlavor: 'dev',
          ),
          'staging',
        );
        expect(
          CrashlyticsCollectionPolicy.resolveFlavor(
            configuredFlavor: '',
            nativeFlavor: 'dev',
          ),
          'dev',
        );
        expect(
          CrashlyticsCollectionPolicy.resolveFlavor(
            configuredFlavor: '',
            nativeFlavor: null,
          ),
          'production',
        );
      },
    );

    for (final flavor in <String>['dev', 'staging']) {
      test('$flavor debug capture is off unless explicitly requested', () {
        expect(
          CrashlyticsCollectionPolicy.resolve(
            buildMode: CrashlyticsBuildMode.debug,
            flavor: flavor,
            debugCaptureRequested: false,
          ),
          isFalse,
        );
        expect(
          CrashlyticsCollectionPolicy.resolve(
            buildMode: CrashlyticsBuildMode.debug,
            flavor: flavor,
            debugCaptureRequested: true,
          ),
          isTrue,
        );
      });

      test('$flavor profile and release capture are enabled', () {
        for (final mode in <CrashlyticsBuildMode>[
          CrashlyticsBuildMode.profile,
          CrashlyticsBuildMode.release,
        ]) {
          expect(
            CrashlyticsCollectionPolicy.resolve(
              buildMode: mode,
              flavor: flavor,
              debugCaptureRequested: false,
            ),
            isTrue,
          );
        }
      });
    }

    test('production and unknown flavors retain their native behavior', () {
      for (final flavor in <String>['production', '', 'other']) {
        expect(
          CrashlyticsCollectionPolicy.resolve(
            buildMode: CrashlyticsBuildMode.release,
            flavor: flavor,
            debugCaptureRequested: true,
          ),
          isNull,
        );
      }
    });

    test('test probe requires both its build gate and enabled collection', () {
      expect(
        CrashlyticsCollectionPolicy.testProbeAvailableFor(
          requested: true,
          collectionOverride: true,
        ),
        isTrue,
      );
      for (final override in <bool?>[false, null]) {
        expect(
          CrashlyticsCollectionPolicy.testProbeAvailableFor(
            requested: true,
            collectionOverride: override,
          ),
          isFalse,
        );
      }
      expect(
        CrashlyticsCollectionPolicy.testProbeAvailableFor(
          requested: false,
          collectionOverride: true,
        ),
        isFalse,
      );
    });
  });
}
