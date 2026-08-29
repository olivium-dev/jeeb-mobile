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

  test('internal package exposes normal and Dev Tool launcher activities', () {
    final mainManifest = _source('android/app/src/main/AndroidManifest.xml');
    final internalManifest = _source(
      'android/app/src/internalRelease/AndroidManifest.xml',
    );
    final debugManifest = _source('android/app/src/debug/AndroidManifest.xml');
    expect(mainManifest, isNot(contains('.DevToolLauncher')));
    expect(internalManifest, contains('android:name=".DevToolLauncher"'));
    for (final activity in <String>[
      _activityBlock(mainManifest, '.MainActivity'),
      _activityBlock(internalManifest, '.DevToolLauncher'),
    ]) {
      expect(activity, contains('android:exported="true"'));
      expect(activity, contains('android.intent.action.MAIN'));
      expect(activity, contains('android.intent.category.LAUNCHER'));
    }
    expect(
      internalManifest,
      contains('android:taskAffinity="com.olivium.jeeb.internalqa"'),
    );
    expect(internalManifest, isNot(contains('activity-alias')));
    expect(debugManifest, contains('.LegacyDevToolLauncher'));
    expect(debugManifest, isNot(contains('.DevToolLauncher"')));
  });

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
    final iosDistributionWorkflow = _source(
      '.github/workflows/distribute-mobile-internal.yml',
    );
    final fastfile = _source('android/fastlane/Fastfile');
    for (final marker in _workflowMarkers) {
      expect(buildWorkflow, contains(marker));
    }
    for (final binding in _provenanceVariableBindings) {
      expect(
        buildWorkflow,
        contains(binding),
        reason: 'provenance must bind jq variables instead of writing null',
      );
    }
    expect(
      buildWorkflow,
      isNot(contains('ANDROID_CANDIDATE_DECRYPT_KEY_B64')),
      reason: 'the lower-trust build environment must never receive the key',
    );
    final retainStep = buildWorkflow.substring(
      buildWorkflow.indexOf('Retain exact ciphertext-only candidate'),
    );
    expect(
      retainStep,
      contains(r'${{ steps.candidate.outputs.candidate_path }}'),
    );
    expect(retainStep, isNot(contains('artifact_path')));
    expect(retainStep, isNot(contains('metadata_path')));
    expect(retainStep, isNot(contains('mapping_path')));
    expect(retainStep, isNot(contains('provenance_path')));
    expect(retainStep, isNot(contains('.aab')));
    expect(buildWorkflow, isNot(contains('upload_to_play_store')));
    expect(buildWorkflow, isNot(contains('pilot(')));
    expect(fastfile, contains('lane :internal_devtool'));
    expect(fastfile, contains("track: 'internal'"));
    expect(
      fastfile,
      contains('require_devtool ? %w[internal]'),
      reason: 'restricted code must never be inventoried into Production',
    );
    final validatorPath = RegExp(
      r"'bash', '([^']*validate_android_internal_devtool_artifact\.sh)'",
    ).firstMatch(fastfile)?.group(1);
    expect(validatorPath, isNotNull);
    expect(
      File('android/fastlane/$validatorPath').existsSync(),
      isTrue,
      reason: 'the configured validator must resolve from android/fastlane',
    );
    expect(fastfile, isNot(contains('lane :production')));
    for (final marker in _distributionWorkflowMarkers) {
      expect(distributionWorkflow, contains(marker));
    }
    expect(distributionWorkflow, isNot(contains('required_reviewers')));
    expect(distributionWorkflow, isNot(contains('prevent_self_review')));
    for (final binding in _distributionReceiptVariableBindings) {
      expect(
        distributionWorkflow,
        contains(binding),
        reason: 'distribution receipt must bind jq variables',
      );
    }
    expect(
      distributionWorkflow,
      isNot(contains('fastlane android internal\n')),
    );
    expect(distributionWorkflow, isNot(contains('track: production')));
    expect(distributionWorkflow, isNot(contains('actions/download-artifact')));
    expect(distributionWorkflow, isNot(contains('unzip ')));
    expect(
      RegExp(
        'secrets\\.ANDROID_CANDIDATE_DECRYPT_KEY_B64',
      ).allMatches(distributionWorkflow).length,
      2,
      reason: 'only the two protected decrypt-and-verify jobs receive the key',
    );
    expect(distributionWorkflow, isNot(contains('set -x')));
    expect(distributionWorkflow, isNot(contains(r'echo "${ANDROID_CANDIDATE')));
    expect(
      iosDistributionWorkflow,
      isNot(contains('android')),
      reason: 'the generic retained-RC lane must be incapable of Play upload',
    );
  });

  test(
    'only the protected Dev Tool workflow can upload Android internally',
    () {
      final invokers = Directory('.github/workflows')
          .listSync()
          .whereType<File>()
          .where(
            (file) =>
                file.readAsStringSync().contains('fastlane android internal'),
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

  test('encrypted candidate custody is authenticated and fail closed', () {
    final custody = _source('tool/android_internal_candidate_custody.sh');
    for (final marker in <String>[
      'id-smime-ct-authEnvelopedData',
      'rsaesOaep',
      'aes-256-gcm',
      'rsa_padding_mode:oaep',
      'rsa_oaep_md:sha256',
      'rsa_mgf1_md:sha256',
    ]) {
      expect(custody, contains(marker));
    }
    expect(custody, isNot(contains('set -x')));

    final result = Process.runSync('bash', <String>[
      'tool/test_android_internal_candidate_custody.sh',
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, contains('encrypted-custody controls passed'));
  });
}

String _source(String path) => File(path).readAsStringSync();

String _activityBlock(String manifest, String activityName) {
  final nameOffset = manifest.indexOf('android:name="$activityName"');
  expect(nameOffset, isNonNegative, reason: '$activityName is absent');
  final start = manifest.lastIndexOf('<activity', nameOffset);
  final end = manifest.indexOf('</activity>', nameOffset);
  expect(start, isNonNegative, reason: '$activityName has no activity start');
  expect(end, isNonNegative, reason: '$activityName has no activity end');
  return manifest.substring(start, end + '</activity>'.length);
}

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
  'base/assets/flutter_assets/lib/l10n/app_en.arb',
  'expected exactly one English ARB asset',
  r'"${tmp_dir}/libapp.so" "${tmp_dir}/app_en.arb"',
  r'grep -aFq "${MAPS_API_KEY}" "${tmp_dir}/manifest.pb"',
  'source_run_id',
  'source_run_attempt',
  'source_workflow_ref',
  'store_uploaded:false',
  'android_internal_candidate_custody.py pack-inner',
  'android_internal_candidate_custody.sh encrypt',
  'android-internal-candidate-recipient.pem',
  'candidate.cms',
  'Retain exact ciphertext-only candidate',
];

const _provenanceVariableBindings = <String>[
  r'reviewed_sha:$reviewed_sha',
  r'dependency_sha:$dependency_sha',
  r'build_name:$build_name',
  r'build_number:$build_number',
  r'artifact_sha256:$artifact_sha256',
  r'metadata_sha256:$metadata_sha256',
  r'mapping_sha256:$mapping_sha256',
  r'signer_sha1:$signer_sha1',
  r'signer_sha256:$signer_sha256',
  r'source_run_id:$source_run_id',
  r'source_run_attempt:$source_run_attempt',
  r'source_head_sha:$source_head_sha',
  r'source_workflow_ref:$source_workflow_ref',
  r'source_repository:$source_repository',
  r'source_event:$source_event',
  r'source_ref:$source_ref',
  r'gateway_origin:$gateway_origin',
  r'realtime_socket:$realtime_socket',
];

const _distributionWorkflowMarkers = <String>[
  'environment: mobile-internal-distribution',
  '.path == ".github/workflows/trusted-android-internal-devtool-rc.yml"',
  'artifact_archive_sha256',
  'candidate_cms_sha256',
  'artifact_id',
  'ANDROID_CANDIDATE_DECRYPT_KEY_B64',
  'android_internal_candidate_custody.py extract-artifact',
  'validate_encrypted_android_internal_candidate.sh',
  'REST re-download, decrypt privately, and reverify exact candidate',
  'Erase private plaintext candidate',
  'EXPECTED_AAB_SHA',
  'EXPECTED_METADATA_SHA',
  'EXPECTED_PROVENANCE_SHA',
  'bundle exec fastlane android internal_devtool',
  'destination:"google-play-internal"',
  'devtool:true',
  'super_login:false',
  'clarity_enabled:false',
];

const _distributionReceiptVariableBindings = <String>[
  r'artifact_sha256:$artifact_sha256',
  r'source_run_id:$source_run_id',
  r'source_run_attempt:$source_run_attempt',
  r'reviewed_sha:$reviewed_sha',
  r'version_name:$version_name',
  r'version_code:$version_code',
];
