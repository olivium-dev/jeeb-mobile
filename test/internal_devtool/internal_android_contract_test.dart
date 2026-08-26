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
    final buildWorkflow = _source(
      '.github/workflows/trusted-android-internal-devtool-rc.yml',
    );
    final distributionWorkflow = _source(
      '.github/workflows/distribute-android-internal-devtool.yml',
    );
    final fastfile = _source('android/fastlane/Fastfile');
    for (final marker in _workflowMarkers) {
      expect(buildWorkflow, contains(marker));
    }
    expect(buildWorkflow, isNot(contains('upload_to_play_store')));
    expect(buildWorkflow, isNot(contains('pilot(')));
    expect(fastfile, contains('lane :internal_devtool'));
    expect(fastfile, contains("track: 'internal'"));
    expect(
      fastfile,
      contains('require_devtool ? %w[internal]'),
      reason: 'restricted code must never be inventoried into Production',
    );
    expect(fastfile, contains('validate_android_internal_devtool_artifact.sh'));
    expect(fastfile, isNot(contains('lane :production')));
    for (final marker in _distributionWorkflowMarkers) {
      expect(distributionWorkflow, contains(marker));
    }
    expect(
      distributionWorkflow,
      isNot(contains('fastlane android internal\n')),
    );
    expect(distributionWorkflow, isNot(contains('track: production')));
  });

  test(
    'only the protected internal distribution workflow invokes the lane',
    () {
      final invokers = Directory('.github/workflows')
          .listSync()
          .whereType<File>()
          .where(
            (file) => file.readAsStringSync().contains(
              'fastlane android internal_devtool',
            ),
          )
          .map((file) => file.path)
          .toList();
      expect(invokers, <String>[
        '.github/workflows/distribute-android-internal-devtool.yml',
      ]);
    },
  );

  test('artifact validator rejects mismatched bytes and metadata', () {
    final result = Process.runSync('bash', <String>[
      'tool/test_validate_android_internal_devtool_artifact.sh',
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, contains('artifact negative controls passed'));
  });

  test('candidate metadata and strict signer helpers fail closed', () {
    final helper = _source('tool/android_internal_candidate_integrity.sh');
    for (final marker in <String>[
      'select-aab',
      'MERGED_MANIFESTS',
      '.version == 3',
      'jarsigner -verify -strict -verbose -certs',
      '-storetype PKCS12',
      '-storepass:env ANDROID_STORE_PASSWORD',
      r'$0 == "jar verified."',
      'exactly one SHA-1 and SHA-256 fingerprint',
    ]) {
      expect(helper, contains(marker));
    }
    expect(helper, isNot(contains('jarsigner -verify -verbose')));
    expect(helper, isNot(contains('|| true')));

    final result = Process.runSync('bash', <String>[
      'tool/test_android_internal_candidate_integrity.sh',
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, contains('strict signer controls passed'));
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
  'metadata_sha256',
  'metadata_kind:"gradle-merged-manifest-v3"',
  'signer_sha1',
  'signer_sha256',
  'android_internal_candidate_integrity.sh',
  'build/app/intermediates/merged_manifests/internalReleaseRelease',
  'awk \'\$0 == "base/manifest/AndroidManifest.xml" {print}\'',
  r'[[ "${manifest_entry}" == base/manifest/AndroidManifest.xml ]]',
  r'unzip -p "${aab}" "${manifest_entry}"',
  r'grep -aFq "${MAPS_API_KEY}" "${tmp_dir}/manifest.pb"',
  'source_run_id',
  'source_run_attempt',
  'source_workflow_ref',
  'store_uploaded:false',
];

const _distributionWorkflowMarkers = <String>[
  'environment: mobile-internal-distribution',
  '.path == ".github/workflows/trusted-android-internal-devtool-rc.yml"',
  'artifact_archive_sha256',
  'EXPECTED_AAB_SHA',
  'EXPECTED_METADATA_SHA',
  'EXPECTED_PROVENANCE_SHA',
  'bundle exec fastlane android internal_devtool',
  'destination:"google-play-internal"',
  'devtool:true',
  'super_login:false',
  'clarity_enabled:false',
];
