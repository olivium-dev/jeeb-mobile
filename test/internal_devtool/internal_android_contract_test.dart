import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('internal flavor preserves store identity and release signing', () {
    final gradle = _source('android/app/build.gradle');
    expect(gradle, contains('internalRelease {'));
    expect(gradle, contains('applicationId "com.olivium.jeeb"'));
    expect(
      gradle,
      contains('buildConfigField "boolean", "JEEB_INTERNAL_RELEASE", "true"'),
    );
    expect(
      gradle,
      contains('resValue "bool", "jeeb_internal_release", "true"'),
    );
    expect(gradle, contains('signingConfig signingConfigs.release'));
    expect(gradle, contains("contains('internalreleaserelease')"));
  });

  test(
    'dedicated internal Activity is absent from production manifest graph',
    () {
      final mainManifest = _source('android/app/src/main/AndroidManifest.xml');
      final internalManifest = _source(
        'android/app/src/internalRelease/AndroidManifest.xml',
      );
      final debugManifest = _source(
        'android/app/src/debug/AndroidManifest.xml',
      );
      expect(mainManifest, isNot(contains('.DevToolLauncher')));
      expect(internalManifest, contains('android:name=".DevToolLauncher"'));
      expect(
        internalManifest,
        contains('android:taskAffinity="com.olivium.jeeb.internalqa"'),
      );
      expect(internalManifest, isNot(contains('activity-alias')));
      expect(debugManifest, contains('.LegacyDevToolLauncher'));
      expect(debugManifest, isNot(contains('.DevToolLauncher"')));
    },
  );

  test('native and Dart launchers independently fail closed', () {
    final nativeLauncher = _source(
      'android/app/src/internalRelease/kotlin/app/jeeb/mobile/'
      'DevToolLauncher.kt',
    );
    final nativePolicy = _source(
      'android/app/src/main/kotlin/app/jeeb/mobile/'
      'InternalReleasePolicyChannel.kt',
    );
    final dartEntrypoint = _source('lib/main_android_internal.dart');
    expect(nativeLauncher, contains('FlutterFragmentActivity'));
    expect(nativeLauncher, contains('allowsInternalTool'));
    expect(nativeLauncher, contains('dedicatedLauncher = true'));
    expect(nativePolicy, contains('BuildConfig.FLAVOR == INTERNAL_FLAVOR'));
    expect(nativePolicy, contains('R.bool.jeeb_internal_release'));
    expect(dartEntrypoint, contains('InternalReleasePolicy.evaluate'));
    expect(dartEntrypoint, contains("route != '/devtool'"));
    expect(dartEntrypoint, contains('const JeebBootstrap()'));
    expect(dartEntrypoint, contains('const InternalReleaseBlockedApp()'));
  });

  test('store and iOS release inspectors reject internal markers', () {
    final android = _source('tool/inspect_android_release_payload.sh');
    final ios = _source('tool/inspect_unsigned_ios_release.sh');
    for (final marker in _internalMarkers) {
      expect(android, contains(marker));
      expect(ios, contains(marker));
    }
  });

  test('protected build profile and upload lane stay internal-only', () {
    final workflow = _source(
      '.github/workflows/trusted-android-internal-devtool-rc.yml',
    );
    final fastfile = _source('android/fastlane/Fastfile');
    for (final marker in _workflowMarkers) {
      expect(workflow, contains(marker));
    }
    expect(workflow, isNot(contains('upload_to_play_store')));
    expect(workflow, isNot(contains('pilot(')));
    expect(fastfile, contains('lane :internal_devtool'));
    expect(fastfile, contains("track: 'internal'"));
    expect(fastfile, contains("'devtool' => true"));
    expect(fastfile, contains("'super_login' => false"));
    expect(fastfile, isNot(contains('lane :production')));
  });
}

String _source(String path) => File(path).readAsStringSync();

const _internalMarkers = <String>[
  r'main_android_internal\.dart',
  'InternalDevToolApp',
  'internal_devtool_root',
  'Jeeb Internal QA',
  'JEEB_INTERNAL_RELEASE=true',
];

const _workflowMarkers = <String>[
  r'(( 10#${BUILD_NUMBER} >= 26082601 ))',
  'bundle exec fastlane preflight_internal',
  '--flavor internalRelease',
  '--target lib/main_android_internal.dart',
  '--dart-define=APP_FLAVOR=staging',
  '--dart-define=JEEB_INTERNAL_RELEASE=true',
  '--dart-define=JEEB_CLARITY_ENABLED=false',
  '--dart-define=JEEB_CLARITY_PRIVACY_APPROVED=false',
  'devtool:true',
  'super_login:false',
  'store_uploaded:false',
];
